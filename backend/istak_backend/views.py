from django.utils import timezone
from django.contrib.auth import get_user_model, authenticate, login
from django.contrib.auth.hashers import make_password
from django.shortcuts import render, redirect
from django.views.decorators.csrf import csrf_exempt
from django.http import JsonResponse
from rest_framework import generics, permissions, status, viewsets
from rest_framework.decorators import api_view, permission_classes, authentication_classes
from rest_framework.permissions import IsAuthenticated, AllowAny
from rest_framework.response import Response
from rest_framework_simplejwt.authentication import JWTAuthentication
from rest_framework_simplejwt.tokens import RefreshToken
from django.contrib import messages
import json
from .models import BorrowTransaction, Item, CustomUser, RegistrationRequest
from .serializers import BorrowTransactionSerializer, ItemSerializer, RegistrationRequestSerializer
from datetime import date

@csrf_exempt
def register_manager(request):
    if request.method != "POST":
        return JsonResponse({"error": "Invalid method"}, status=405)
    try:
        data = json.loads(request.body)
        username = data.get("username")
        email = data.get("email")
        password = data.get("password")
        if not username or not email or not password:
            return JsonResponse({"error": "Missing fields"}, status=400)
        user = CustomUser.objects.create_user(
            username=username,
            email=email,
            password=password,
            role="user_web"
        )
        return JsonResponse({"status": "success"}, status=201)
    except Exception as e:
        return JsonResponse({"error": str(e)}, status=500)

@csrf_exempt
def login_mobile(request):
    if request.method == "POST":
        try:
            data = json.loads(request.body.decode("utf-8"))
            username = data.get("username")
            password = data.get("password")
            user = authenticate(username=username, password=password)
            if user is not None:
                refresh = RefreshToken.for_user(user)
                return JsonResponse({
                    "success": True,
                    "message": "Login successful",
                    "access": str(refresh.access_token),
                    "refresh": str(refresh),
                    "user": {
                        "id": user.id,
                        "username": user.username,
                        "email": user.email,
                    }
                }, status=200)
            else:
                return JsonResponse({
                    "success": False,
                    "error": "Invalid username or password"
                }, status=401)
        except Exception as e:
            return JsonResponse({
                "success": False,
                "error": f"Invalid request: {str(e)}"
            }, status=400)
    return JsonResponse({"error": "Invalid request method"}, status=405)

@csrf_exempt
def login_manager(request):
    if request.method != "POST":
        return JsonResponse({"error": "Invalid method"}, status=405)
    try:
        data = json.loads(request.body)
    except json.JSONDecodeError:
        return JsonResponse({"error": "Invalid JSON"}, status=400)
    username = data.get("username")
    password = data.get("password")
    if not username or not password:
        return JsonResponse({"error": "Missing credentials"}, status=400)
    user = authenticate(username=username, password=password)
    if user and user.role == "user_web":
        refresh = RefreshToken.for_user(user)
        return JsonResponse({
            "status": "success",
            "access": str(refresh.access_token),
            "refresh": str(refresh),
            "user": {
                "id": user.id,
                "username": user.username,
                "role": user.role
            }
        })
    return JsonResponse({"error": "Invalid credentials"}, status=400)

User = get_user_model()

@csrf_exempt
def register_mobile(request):
    if request.method != "POST":
        return JsonResponse({"error": "Only POST allowed"}, status=405)
    try:
        data = json.loads(request.body)
        username = data.get("username")
        password = data.get("password")
        email = data.get("email")
        manager_id = data.get("manager_id")
        if not username or not password or not email or not manager_id:
            return JsonResponse({"error": "All fields are required, including manager_id"}, status=400)
        if User.objects.filter(username=username).exists():
            return JsonResponse({"error": "Username already exists"}, status=400)
        manager = User.objects.filter(id=manager_id, role='user_web').first()
        if not manager:
            return JsonResponse({"error": "Invalid manager ID"}, status=400)
        RegistrationRequest.objects.create(
            username=username,
            email=email,
            password=make_password(password),
            requested_manager=manager
        )
        return JsonResponse({"status": "success", "message": "Registration pending approval"}, status=201)
    except json.JSONDecodeError:
        return JsonResponse({"error": "Invalid JSON"}, status=400)

def manager_login(request):
    if request.method == "POST":
        username = request.POST.get("username")
        password = request.POST.get("password")
        user = authenticate(request, username=username, password=password)
        if user and user.role == "user_web":
            login(request, user)
            return redirect("home")
        else:
            messages.error(request, "Invalid credentials or not a manager.")
    return render(request, "login.html")

def home(request):
    if request.user.is_authenticated:
        return render(request, "home.html", {"username": request.user.username})
    else:
        return redirect("manager_login")

@api_view(['GET'])
@permission_classes([AllowAny])
def manager_list(request):
    managers = CustomUser.objects.filter(role='user_web')
    return Response([{"id": m.id, "username": m.username} for m in managers])

@api_view(['GET', 'POST'])
@authentication_classes([JWTAuthentication])
@permission_classes([IsAuthenticated])
def item_list(request):
    if request.method == 'GET':
        item_id = request.query_params.get('id')
        if item_id:
            try:
                item_id = str(item_id).strip()
                item_id_int = int(item_id)
                if request.user.role == 'user_web':
                    items = Item.objects.filter(id=item_id_int, manager=request.user)
                else:
                    if request.user.manager:
                        items = Item.objects.filter(id=item_id_int, manager=request.user.manager)
                    else:
                        items = Item.objects.none()
                if not items.exists():
                    return Response({"error": "Item not found"}, status=status.HTTP_404_NOT_FOUND)
                serializer = ItemSerializer(items.first())
                return Response(serializer.data)
            except (ValueError, TypeError):
                return Response({"error": "Invalid item ID"}, status=status.HTTP_400_BAD_REQUEST)
        else:
            if request.user.role == 'user_web':
                items = Item.objects.filter(manager=request.user)
            else:
                if request.user.manager:
                    items = Item.objects.filter(manager=request.user.manager)
                else:
                    items = Item.objects.none()
            serializer = ItemSerializer(items, many=True)
            return Response(serializer.data)
    elif request.method == 'POST':
        serializer = ItemSerializer(data=request.data, context={'request': request})
        if serializer.is_valid():
            serializer.save(manager=request.user if request.user.role == 'user_web' else request.user.manager)
            return Response(serializer.data, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
    return Response({'error': 'Method not allowed'}, status=status.HTTP_405_METHOD_NOT_ALLOWED)
class ItemListCreateAPIView(generics.ListCreateAPIView):
    serializer_class = ItemSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        if self.request.user.role == 'user_web':
            return Item.objects.filter(manager=self.request.user)
        else:
            if self.request.user.manager:
                return Item.objects.filter(manager=self.request.user.manager)
            return Item.objects.none()

    def perform_create(self, serializer):
        if self.request.user.role == 'user_web':
            serializer.save(manager=self.request.user)
        else:
            serializer.save(manager=self.request.user.manager)

class ItemRetrieveUpdateDestroyAPIView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = ItemSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        if self.request.user.role == 'user_web':
            return Item.objects.filter(manager=self.request.user)
        else:
            if self.request.user.manager:
                return Item.objects.filter(manager=self.request.user.manager)
            return Item.objects.none()

@api_view(['POST'])
@authentication_classes([JWTAuthentication])
@permission_classes([IsAuthenticated])
def approve_registration(request):
    if request.user.role != 'user_web':
        return Response({"error": "Only managers can approve registrations"}, status=status.HTTP_403_FORBIDDEN)
    try:
        data = json.loads(request.body)
        request_id = data.get("request_id")
        is_approved = data.get("is_approved")
        if not request_id or is_approved is None:
            return Response({"error": "request_id and is_approved are required"}, status=400)
        reg_request = RegistrationRequest.objects.filter(
            id=request_id,
            requested_manager=request.user
        ).first()
        if not reg_request:
            return Response({"error": "Invalid or unauthorized request ID"}, status=400)
        if is_approved:
            user = CustomUser.objects.create_user(
                username=reg_request.username,
                email=reg_request.email,
                password=None,
                role='user_mobile',
                manager=request.user
            )
            user.password = reg_request.password
            user.save()
            reg_request.delete()
            return Response({"status": "success", "user_id": user.id}, status=200)
        else:
            reg_request.delete()
            return Response({"status": "success", "message": "Request denied"}, status=200)
    except json.JSONDecodeError:
        return Response({"error": "Invalid JSON"}, status=400)
    except Exception as e:
        return Response({"error": str(e)}, status=500)

class RegistrationRequestViewSet(viewsets.ModelViewSet):
    serializer_class = RegistrationRequestSerializer
    permission_classes = [IsAuthenticated]
    authentication_classes = [JWTAuthentication]

    def get_queryset(self):
        if self.request.user.role == 'user_web':
            return RegistrationRequest.objects.filter(requested_manager=self.request.user)
        return RegistrationRequest.objects.none()

    def list(self, request, *args, **kwargs):
        queryset = self.get_queryset()
        serializer = self.get_serializer(queryset, many=True)
        return Response(serializer.data)

    def update(self, request, *args, **kwargs):
        instance = self.get_object()
        status_value = request.data.get('status')
        if status_value not in ['approved', 'rejected']:
            return Response(
                {"error": "Invalid status. Use 'approved' or 'rejected'."},
                status=status.HTTP_400_BAD_REQUEST
            )

        if status_value == 'approved':
            if instance.is_approved:
                return Response(
                    {"error": "Request is already approved."},
                    status=status.HTTP_400_BAD_REQUEST
                )
            user = CustomUser.objects.create_user(
                username=instance.username,
                email=instance.email,
                password=None,
                role='user_mobile',
                manager=instance.requested_manager
            )
            user.password = instance.password
            user.save()
            instance.is_approved = True
            instance.save()
        elif status_value == 'rejected':
            if instance.is_approved:
                return Response(
                    {"error": "Cannot reject an already approved request."},
                    status=status.HTTP_400_BAD_REQUEST
                )
            instance.delete()
            return Response(status=status.HTTP_204_NO_CONTENT)

        serializer = self.get_serializer(instance)
        return Response(serializer.data)

from .firebase import send_push_notification

@api_view(['POST'])
@authentication_classes([JWTAuthentication])
@permission_classes([IsAuthenticated])
def borrow_process(request):
    if request.user.role != 'user_mobile':
        return Response({"error": "Only mobile users can process borrow requests"}, status=status.HTTP_403_FORBIDDEN)
    
    try:
        data = json.loads(request.body)
        item_id = data.get('item_id')
        
        if not item_id:
            return Response({"error": "item_id is required"}, status=status.HTTP_400_BAD_REQUEST)
        
        try:
            item_id = int(item_id)
            item = Item.objects.filter(id=item_id, manager=request.user.manager).first()
            if not item:
                return Response({"error": "Item not found or not managed by your manager"}, status=status.HTTP_404_NOT_FOUND)
        except (ValueError, TypeError):
            return Response({"error": "Invalid item ID"}, status=status.HTTP_400_BAD_REQUEST)
        
        if item.current_transaction is None:
            borrower_name = data.get('borrowerName')
            school_id = data.get('schoolId')
            return_date = data.get('return_date')
            
            if not all([borrower_name, school_id, return_date]):
                return Response({"error": "borrowerName, schoolId, and return_date are required"}, status=status.HTTP_400_BAD_REQUEST)
            
            try:
                return_date = date.fromisoformat(return_date)
            except ValueError:
                return Response({"error": "Invalid return_date format, use YYYY-MM-DD"}, status=status.HTTP_400_BAD_REQUEST)
            
            transaction = BorrowTransaction.objects.create(
                return_date=return_date,
                borrowerName=borrower_name,
                schoolId=school_id,
                manager=request.user.manager,
                mobile_user=request.user,
                item=item
            )
            
            item.current_transaction = transaction
            item.status = "borrowed"
            item.last_borrowed = timezone.now()
            item.save()
            
            return Response({
                "status": "success",
                "message": f"Item {item.item_name} borrowed successfully",
                "transaction_id": transaction.id
            }, status=status.HTTP_201_CREATED)
        
        else:
            condition = data.get('condition')
            valid_conditions = ["Good", "Fair", "Damaged", "Broken"]
            
            if not condition:
                return Response({"error": "condition is required"}, status=status.HTTP_400_BAD_REQUEST)
            if condition not in valid_conditions:
                return Response({"error": f"condition must be one of {valid_conditions}"}, status=status.HTTP_400_BAD_REQUEST)
            
            # Store transaction ID before setting current_transaction to None
            transaction_id = item.current_transaction.id if item.current_transaction else None
            item.condition = condition  
            item.status = "available"
            item.last_borrowed = timezone.now()
            item.current_transaction = None
            item.save()
            
            if transaction_id:
                BorrowTransaction.objects.filter(id=transaction_id).delete()
            
            if request.user.fcm_token:
                    result = send_push_notification(
                        request.user.fcm_token,
                        "Return Successful",
                        f"You returned {item.item_name} in {condition} condition"
                    )
                    if result is None:
                        print(f"Failed to send notification to {request.user.fcm_token}")
                        
            return Response({
                "status": "success",
                "message": f"Item {item.item_name} returned successfully",
                "condition": condition
            }, status=status.HTTP_200_OK)
    
    except json.JSONDecodeError:
        return Response({"error": "Invalid JSON"}, status=status.HTTP_400_BAD_REQUEST)
    except Exception as e:
        return Response({"error": str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

from rest_framework.views import APIView

class UserAPIView(APIView):
    permission_classes = [IsAuthenticated]
    authentication_classes = [JWTAuthentication]

    def get(self, request):
        return Response({
            "role": request.user.role,
            "username": request.user.username,
        })

class TransactionListAPIView(generics.ListAPIView):
    serializer_class = BorrowTransactionSerializer
    permission_classes = [IsAuthenticated]
    authentication_classes = [JWTAuthentication]

    def get_queryset(self):
        user = self.request.user
        if user.role == 'user_web':
            return BorrowTransaction.objects.filter(manager=user)
        elif user.role == 'user_mobile':
            return BorrowTransaction.objects.filter(mobile_user=user)
        return BorrowTransaction.objects.none()

class TransactionDetailAPIView(generics.RetrieveDestroyAPIView):
    serializer_class = BorrowTransactionSerializer
    permission_classes = [IsAuthenticated]
    authentication_classes = [JWTAuthentication]
    queryset = BorrowTransaction.objects.all()
    lookup_field = 'id'

    def get_queryset(self):
        user = self.request.user
        if user.role == 'user_web':
            return BorrowTransaction.objects.filter(manager=user)
        return BorrowTransaction.objects.none()

    def destroy(self, request, *args, **kwargs):
        if request.user.role != 'user_web':
            return Response(
                {"error": "Only web users (managers) can delete transactions"},
                status=status.HTTP_403_FORBIDDEN
            )

        instance = self.get_object()
        item = instance.item

        if item.current_transaction == instance:
            item.current_transaction = None
            item.status = "available"
            item.last_borrowed = timezone.now()
            item.save()

        self.perform_destroy(instance)

        return Response(
            {
                "status": "success",
                "message": f"Transaction {instance.id} deleted successfully"
            },
            status=status.HTTP_200_OK
        )
        
@api_view(['POST'])
@authentication_classes([JWTAuthentication])
@permission_classes([IsAuthenticated])
def update_fcm_token(request):
    try:
        data = json.loads(request.body)
        fcm_token = data.get('fcm_token')
        
        if not fcm_token:
            return Response({"error": "fcm_token is required"}, status=status.HTTP_400_BAD_REQUEST)
        
        # Update the user's FCM token
        request.user.fcm_token = fcm_token
        request.user.save()
        
        return Response({
            "status": "success",
            "message": "FCM token updated successfully"
        }, status=status.HTTP_200_OK)
    
    except json.JSONDecodeError:
        return Response({"error": "Invalid JSON"}, status=status.HTTP_400_BAD_REQUEST)
    except Exception as e:
        return Response({"error": str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)