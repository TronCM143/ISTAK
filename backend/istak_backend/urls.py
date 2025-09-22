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
    path('api/register_mobile/', views.register_mobile, name='register_mobile'),
    path('api/login_manager/', views.login_manager, name='login_manager'),
    path('api/login_mobile/', views.login_mobile, name='login_mobile'),
    path('api/register_manager/', views.register_manager, name='register_manager'),
    path('api/approve_registration/', views.approve_registration, name='approve_registration'),
    path('api/token/', TokenObtainPairView.as_view(), name='token_obtain_pair'),
    path('api/token/refresh/', TokenRefreshView.as_view(), name='token_refresh'),
    path('api/items/', views.ItemListCreateAPIView.as_view(), name='item-list-create'),
    path('api/items/<int:pk>/', views.ItemRetrieveUpdateDestroyAPIView.as_view(), name='item-detail'),
    path('api/managers/', views.manager_list, name='manager-list'),
    path('api/borrow_process/', views.borrow_process, name='borrow-process'),
    path('api/user/', views.UserAPIView.as_view(), name='user-detail'),
    path('api/transactions/', views.TransactionListAPIView.as_view(), name='transaction-list'),
    path('api/update_fcm_token/', views.update_fcm_token, name='update_fcm_token'),
    path('api/top-borrowed-items/', views.top_borrowed_items, name='top_borrowed_items'),
    path('api/analytics/transactions/', views.AnalyticsTransactionsView.as_view(), name='analytics-transactions'),
    path('api/analytics/monthly-transactions/', views.MonthlyTransactionsView.as_view(), name='monthly-transactions'),
] + static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)   