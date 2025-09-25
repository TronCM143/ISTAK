import logging
import json
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
from rest_framework.views import APIView
from django.contrib import messages
from io import BytesIO
from PIL import Image
from rembg import remove
from django.core.files.base import ContentFile
from datetime import date
from django.db.models import Count
from sympy import Q
from .firebase import send_push_notification
from .models import Transaction, Item, CustomUser, RegistrationRequest, Borrower
from .serializers import TransactionSerializer, ItemSerializer, RegistrationRequestSerializer, TopBorrowedItemsSerializer

logger = logging.getLogger(__name__)

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
        elif self.request.user.manager:
            return Item.objects.filter(manager=self.request.user.manager)
        return Item.objects.none()

    def perform_update(self, serializer):
        instance = serializer.instance
        image_file = self.request.FILES.get('image')

        if image_file:
            try:
                input_img = Image.open(image_file).convert("RGBA")
                output_img = remove(input_img)
                temp_buffer = BytesIO()
                output_img.save(temp_buffer, format="PNG")
                temp_buffer.seek(0)
                new_image = ContentFile(
                    temp_buffer.read(),
                    name=f"{image_file.name.rsplit('.', 1)[0]}.png"
                )
                serializer.save(image=new_image)
                logger.info(f"Background removed for item {instance.id}")
                print(f"✅ Background removed successfully for item {instance.id}")
            except Exception as e:
                logger.error(f"Error removing background for item {instance.id}: {str(e)}")
                print(f"❌ Error removing background for item {instance.id}: {str(e)}")
                raise
        else:
            serializer.save()

    def destroy(self, request, *args, **kwargs):
        instance = self.get_object()
        if instance.current_transaction:
            return Response({"error": "Cannot delete item with an active transaction"}, status=status.HTTP_400_BAD_REQUEST)
        self.perform_destroy(instance)
        return Response(status=204)

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
            if instance.status == 'approved':
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
            instance.status = 'approved'
            instance.save()
        elif status_value == 'rejected':
            if instance.status == 'approved':
                return Response(
                    {"error": "Cannot reject an already approved request."},
                    status=status.HTTP_400_BAD_REQUEST
                )
            instance.delete()
            return Response(status=status.HTTP_204_NO_CONTENT)

        serializer = self.get_serializer(instance)
        return Response(serializer.data)

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
            borrower_name = data.get('borrower_name')
            school_id = data.get('school_id')
            return_date = data.get('return_date')
            
            if not all([borrower_name, school_id, return_date]):
                return Response({"error": "borrower_name, school_id, and return_date are required"}, status=status.HTTP_400_BAD_REQUEST)
            
            try:
                return_date = date.fromisoformat(return_date)
            except ValueError:
                return Response({"error": "Invalid return_date format, use YYYY-MM-DD"}, status=status.HTTP_400_BAD_REQUEST)
            
            if return_date < date.today():
                return Response({"error": "Return date cannot be in the past"}, status=status.HTTP_400_BAD_REQUEST)
            
            borrower, created = Borrower.objects.get_or_create(
                name=borrower_name,
                school_id=school_id,
                defaults={'status': 'pending'}
            )
            
            transaction = Transaction.objects.create(
                return_date=return_date,
                status='borrowed',
                manager=request.user.manager,
                mobile_user=request.user,
                item=item,
                borrower=borrower
            )
            
            item.current_transaction = transaction
            item.save()
            
            return Response({
                "status": "success",
                "message": f"Item {item.item_name} borrowed successfully",
                "transaction_id": transaction.id,
                "borrower": {
                    "id": borrower.id,
                    "name": borrower.name,
                    "school_id": borrower.school_id,
                    "status": borrower.status
                }
            }, status=status.HTTP_201_CREATED)
        
        else:
            condition = data.get('condition')
            valid_conditions = ["Good", "Fair", "Damaged", "Broken"]
            
            if not condition:
                return Response({"error": "condition is required for return"}, status=status.HTTP_400_BAD_REQUEST)
            if condition not in valid_conditions:
                return Response({"error": f"condition must be one of {valid_conditions}"}, status=status.HTTP_400_BAD_REQUEST)
            
            if item.current_transaction:
                transaction = item.current_transaction
                transaction.status = 'returned'
                transaction.return_date = date.today()
                transaction.save()
                
                item.condition = condition
                item.current_transaction = None
                item.save()
                
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
            else:
                return Response({"error": "No active transaction for this item"}, status=status.HTTP_400_BAD_REQUEST)
    
    except json.JSONDecodeError:
        return Response({"error": "Invalid JSON"}, status=status.HTTP_400_BAD_REQUEST)
    except Exception as e:
        return Response({"error": str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

class UserAPIView(APIView):
    permission_classes = [IsAuthenticated]
    authentication_classes = [JWTAuthentication]

    def get(self, request):
        manager_id = request.user.manager_id if hasattr(request.user, 'manager_id') else None
        return Response({
            "role": request.user.role,
            "username": request.user.username,
            "manager_id": manager_id,
        })

class TransactionListAPIView(generics.ListAPIView):
    serializer_class = TransactionSerializer
    permission_classes = [IsAuthenticated]
    authentication_classes = [JWTAuthentication]

    def get_queryset(self):
        user = self.request.user
        if user.role == 'user_web':
            return Transaction.objects.filter(manager=user)
        elif user.role == 'user_mobile':
            return Transaction.objects.filter(mobile_user=user)
        return Transaction.objects.none()

@api_view(['POST'])
@authentication_classes([JWTAuthentication])
@permission_classes([IsAuthenticated])
def update_fcm_token(request):
    try:
        data = json.loads(request.body)
        fcm_token = data.get('fcm_token')
        
        if not fcm_token:
            return Response({"error": "fcm_token is required"}, status=status.HTTP_400_BAD_REQUEST)
        
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

@api_view(['GET'])
@permission_classes([IsAuthenticated])
@authentication_classes([JWTAuthentication])
def top_borrowed_items(request):
    top_items = Item.objects.annotate(
        borrow_count=Count('transactions')
    ).order_by('-borrow_count')[:5]
    serializer = TopBorrowedItemsSerializer(top_items, many=True, context={'request': request})
    return Response(serializer.data)



from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from django.utils import timezone
from datetime import timedelta, datetime
from django.db.models import Count
from .models import Transaction
from .serializers import TransactionSerializer

class AnalyticsTransactionsView(APIView):
    def get(self, request):
        try:
            # Get all transactions
            transactions = Transaction.objects.all()

            # Calculate date ranges
            today = timezone.now().date()
            three_months_ago = today - timedelta(days=90)

            # Weekly aggregation
            weekly_data = {}
            for t in transactions:
                borrow_date = t.borrow_date
                # Get Monday of the week
                day = borrow_date.weekday()
                week_start = borrow_date - timedelta(days=day)
                week_key = week_start.strftime('%Y-%m-%d')

                if week_key not in weekly_data:
                    weekly_data[week_key] = {'count': 0, 'items': {}}
                weekly_data[week_key]['count'] += 1
                item_name = t.item.item_name
                weekly_data[week_key]['items'][item_name] = weekly_data[week_key]['items'].get(item_name, 0) + 1

            weekly_result = [
                {
                    'week_start': week_key,
                    'count': data['count'],
                    'top_items': [
                        {'item': item, 'count': count}
                        for item, count in sorted(
                            data['items'].items(), key=lambda x: x[1], reverse=True
                        )[:5]
                    ]
                }
                for week_key, data in sorted(weekly_data.items())
                if datetime.strptime(week_key, '%Y-%m-%d').date() >= three_months_ago
            ]

            # Monthly aggregation
            monthly_data = {}
            for t in transactions:
                month_key = t.borrow_date.strftime('%Y-%m')
                if month_key not in monthly_data:
                    monthly_data[month_key] = {'count': 0, 'items': {}}
                monthly_data[month_key]['count'] += 1
                item_name = t.item.item_name
                monthly_data[month_key]['items'][item_name] = monthly_data[month_key]['items'].get(item_name, 0) + 1

            monthly_result = [
                {
                    'month': month_key,
                    'count': data['count'],
                    'top_items': [
                        {'item': item, 'count': count}
                        for item, count in sorted(
                            data['items'].items(), key=lambda x: x[1], reverse=True
                        )[:5]
                    ]
                }
                for month_key, data in sorted(monthly_data.items())
                if datetime.strptime(month_key, '%Y-%m').date() >= three_months_ago.replace(day=1)
            ]

            # Three months aggregation (by month within the last 90 days)
            three_months_result = [
                {
                    'month': month_key,
                    'count': data['count'],
                    'top_items': [
                        {'item': item, 'count': count}
                        for item, count in sorted(
                            data['items'].items(), key=lambda x: x[1], reverse=True
                        )[:5]
                    ]
                }
                for month_key, data in sorted(monthly_data.items())
                if datetime.strptime(month_key, '%Y-%m').date() >= three_months_ago.replace(day=1)
            ]

            return Response({
                'weekly': weekly_result,
                'monthly': monthly_result,
                'three_months': three_months_result
            }, status=status.HTTP_200_OK)

        except Exception as e:
            return Response(
                {'error': str(e)},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )
            
            
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from .models import Transaction
from django.utils import timezone
from datetime import datetime, timedelta
from dateutil.relativedelta import relativedelta
from rest_framework.permissions import AllowAny
class MonthlyTransactionsView(APIView):
    authentication_classes = []
    permission_classes = [AllowAny] 
    def get(self, request):
        try:
            # Calculate the date range: last 6 months from today
            today = timezone.now().date()
            start_date = today - relativedelta(months=6)
            transactions = Transaction.objects.filter(borrow_date__gte=start_date)

            # Initialize monthly data
            monthly_data = {}
            current_date = start_date
            while current_date <= today:
                month_key = current_date.strftime('%Y-%m')
                monthly_data[month_key] = {'borrowed': 0, 'returned': 0}
                current_date += relativedelta(months=1)

            # Aggregate transactions
            for t in transactions:
                month_key = t.borrow_date.strftime('%Y-%m')
                if month_key in monthly_data:
                    if t.status.lower() == 'borrowed':
                        monthly_data[month_key]['borrowed'] += 1
                    elif t.status.lower() == 'returned':
                        monthly_data[month_key]['returned'] += 1

            # Format response
            monthly_result = [
                {
                    'month': datetime.strptime(month_key, '%Y-%m').strftime('%B'),  # e.g., "April"
                    'borrowed': data['borrowed'],
                    'returned': data['returned']
                }
                for month_key, data in sorted(monthly_data.items())
            ]

            return Response(monthly_result, status=status.HTTP_200_OK)

        except Exception as e:
            return Response(
                {'error': str(e)},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )
            
            
            

@api_view(['POST'])
@authentication_classes([JWTAuthentication])
@permission_classes([IsAuthenticated])
def update_overdue_transactions(request):
    try:
        today = date.today()
        # Find borrowed transactions with past due return dates
        overdue_transactions = Transaction.objects.filter(
            status='borrowed',
            return_date__lt=today
        )
        count = overdue_transactions.count()
        overdue_transactions.update(status='overdue')
        return Response({
            "status": "success",
            "message": f"Updated {count} transactions to overdue status"
        }, status=status.HTTP_200_OK)
    except Exception as e:
        return Response({"error": str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
    
    
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from .models import Item, Transaction

class ItemStatusCountView(APIView):
    def get(self, request):
        try:
            # Count items based on current_transaction status
            total_items = Item.objects.count()
            borrowed_items = Item.objects.filter(
                current_transaction__status='borrowed'
            ).count()
            available_items = total_items - borrowed_items

            return Response({
                'available': available_items,
                'borrowed': borrowed_items
            }, status=status.HTTP_200_OK)
        except Exception as e:
            return Response(
                {'error': str(e)},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

            
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from .models import Borrower
from .serializers import BorrowerSerializer

class BorrowerListView(APIView):
    def get(self, request):
        try:
            if request.user.role != 'user_mobile':
                return Response(
                    {'error': 'Only mobile users can access this endpoint'},
                    status=status.HTTP_403_FORBIDDEN
                )
            borrowers = Borrower.objects.filter(
                transactions__mobile_user=request.user
            ).distinct()
            print(f"User: {request.user}, Role: {request.user.role}, Borrowers found: {borrowers.count()}")  # Debug
            serializer = BorrowerSerializer(borrowers, many=True, context={'request': request})
            return Response(serializer.data, status=status.HTTP_200_OK)
        except Exception as e:
            print(f"Error: {str(e)}")  # Debug
            return Response(
                {'error': str(e)},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )
            
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from .models import Transaction, Borrower
from .serializers import TransactionSerializer

class BorrowerTransactionsView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, borrower_id):
        try:
            transactions = Transaction.objects.filter(
                borrower_id=borrower_id,
                mobile_user=request.user
            ).select_related('item', 'borrower')
            serializer = TransactionSerializer(transactions, many=True, context={'request': request})
            return Response(serializer.data)
        except Borrower.DoesNotExist:
            return Response({"error": "Borrower not found"}, status=404)
        
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from django.contrib.auth import get_user_model
from .models import Item, Borrower, Transaction
from .serializers import ReportSerializer
from django.db.models import Q
from datetime import datetime

User = get_user_model()

class DamagedLostItemsReportView(APIView):
    def post(self, request):
        try:
            # Get filters from request body
            data = request.data
            search = data.get('search', '')
            status_filter = data.get('status', '')
            date_from = data.get('dateFrom')
            date_to = data.get('dateTo')

            # Get the authenticated user
            user = request.user
            if not user.is_authenticated:
                return Response({"error": "Authentication required"}, status=status.HTTP_401_UNAUTHORIZED)

            # Filter transactions based on user role
            if user.role == 'user_web':
                queryset = Transaction.objects.filter(manager=user)
            elif user.role == 'user_mobile':
                queryset = Transaction.objects.filter(mobile_user=user)
            else:
                return Response({"error": "Invalid user role"}, status=status.HTTP_403_FORBIDDEN)

            # Apply filters
            if search:
                queryset = queryset.filter(
                    Q(borrower__name__icontains=search) |
                    Q(item__item_name__icontains=search)
                )

            if status_filter and status_filter != 'all':
                queryset = queryset.filter(status=status_filter.lower())

            if date_from:
                try:
                    date_from = datetime.strptime(date_from, '%Y-%m-%d').date()
                    queryset = queryset.filter(return_date__gte=date_from)
                except ValueError:
                    return Response({"error": "Invalid dateFrom format"}, status=status.HTTP_400_BAD_REQUEST)

            if date_to:
                try:
                    date_to = datetime.strptime(date_to, '%Y-%m-%d').date()
                    queryset = queryset.filter(return_date__lte=date_to)
                except ValueError:
                    return Response({"error": "Invalid dateTo format"}, status=status.HTTP_400_BAD_REQUEST)

            # Prepare report data
            reports = []
            for transaction in queryset:
                report = {
                    "id": str(transaction.id),
                    "borrowerName": transaction.borrower.name,
                    "itemStatus": transaction.status.capitalize(),
                    "itemName": transaction.item.item_name,
                    "returnedDate": transaction.return_date.strftime('%Y-%m-%d') if transaction.return_date else None,
                    "condition": transaction.item.condition
                }
                reports.append(report)

            # Serialize data
            serializer = ReportSerializer(reports, many=True)
            return Response(serializer.data, status=status.HTTP_200_OK)

        except Exception as e:
            return Response({"error": str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)