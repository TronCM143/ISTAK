from django.contrib import admin
from django.urls import include, path
from rest_framework.routers import DefaultRouter
from django.conf.urls.static import static
from istak_backend import settings
from . import views
from rest_framework_simplejwt.views import TokenObtainPairView, TokenRefreshView

router = DefaultRouter()
router.register(r'requests', views.RegistrationRequestViewSet, basename='requests')

urlpatterns = [
    path('admin/', admin.site.urls),

    # Authentication
    path('api/register_mobile/', views.register_mobile, name='register_mobile'),
    path('api/login_manager/', views.login_manager, name='login_manager'),
    path('api/login_mobile/', views.login_mobile, name='login_mobile'),
    path('api/register_manager/', views.register_manager, name='register_manager'),
    path('api/approve_registration/', views.approve_registration, name='approve_registration'),

    # JWT Auth
    path('api/token/', TokenObtainPairView.as_view(), name='token_obtain_pair'),
    path('api/token/refresh/', TokenRefreshView.as_view(), name='token_refresh'),

    # Items
    path('api/items/', views.ItemListCreateAPIView.as_view(), name='item-list-create'),
    path('api/items/<int:pk>/', views.ItemRetrieveUpdateDestroyAPIView.as_view(), name='item-detail'),

    # Managers
    path('api/managers/', views.manager_list, name='manager-list'),
    path('api/borrow_process/', views.borrow_process, name='borrow-process'),
    # Registration Requests
    path('api/', include(router.urls)),
    path('api/user/', views.UserAPIView.as_view(), name='user-detail'),
    path('api/transactions/', views.TransactionListAPIView.as_view(), name='transaction-list'),
    path('api/transactions/<int:id>/', views.TransactionDetailAPIView.as_view(), name='transaction-detail'),
    path('api/borrow/', views.borrow_process, name='borrow_process'),  # Duplicate with borrow_process, consider removing
    path('api/update_fcm_token/', views.update_fcm_token, name='update_fcm_token'),
    # Move top_borrowed_items under /api/
    path('api/top-borrowed-items/', views.top_borrowed_items, name='top_borrowed_items'),
] + static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)