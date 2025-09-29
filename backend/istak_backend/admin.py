from django.contrib import admin
from django.contrib.auth.admin import UserAdmin
from django.contrib.admin import SimpleListFilter
from .models import CustomUser, Item, Borrower, Transaction, RegistrationRequest

# Custom filter for Borrower.status
class BorrowerStatusFilter(SimpleListFilter):
    title = 'borrower status'
    parameter_name = 'status'

    def lookups(self, request, model_admin):
        return (
            ('active', 'Active'),
            ('inactive', 'Inactive'),
        )

    def queryset(self, request, queryset):
        value = self.value()
        if value in ['active', 'inactive']:
            return queryset.filter(status=value)
        return queryset

@admin.register(CustomUser)
class CustomUserAdmin(UserAdmin):
    model = CustomUser
    list_display = ('username', 'email', 'role', 'is_staff', 'is_active')
    list_filter = ('role', 'is_staff', 'is_active')
    fieldsets = (
        (None, {'fields': ('username', 'email', 'password', 'role')}),
        ('Manager Assignment', {'fields': ('manager',), 'classes': ('collapse',)}),
        ('Permissions', {'fields': ('is_staff', 'is_active', 'groups', 'user_permissions')}),
    )
    add_fieldsets = (
        (None, {
            'classes': ('wide',),
            'fields': ('username', 'email', 'password1', 'password2',
                       'role', 'manager', 'is_staff', 'is_active')}
        ),
    )
    search_fields = ('username', 'email')
    ordering = ('username',)
    autocomplete_fields = ['manager']

@admin.register(Item)
class ItemAdmin(admin.ModelAdmin):
    list_display = ('item_name', 'get_status_display', 'condition', 'manager_username')
    list_filter = ('condition', 'manager')
    search_fields = ('item_name',)
    fields = ('item_name', 'condition', 'user', 'manager', 'image')
    raw_id_fields = ('user', 'manager')
    autocomplete_fields = ['user', 'manager']

    def get_status_display(self, obj):
        """Display computed status based on transactions."""
        if obj.transactions.filter(status='borrowed').exists():
            return 'Borrowed'
        return 'Available'
    get_status_display.short_description = 'Status'

    def manager_username(self, obj):
        """Safely display manager username."""
        if obj.manager:
            return obj.manager.username or "No Username"
        return "No Manager"
    manager_username.short_description = "Manager"
    manager_username.admin_order_field = 'manager__username'

@admin.register(Borrower)
class BorrowerAdmin(admin.ModelAdmin):
    list_display = ('name', 'school_id', 'get_status_display')
    list_filter = ('status', BorrowerStatusFilter)
    search_fields = ('name', 'school_id')
    fields = ('name', 'school_id', 'status', 'image')

    def get_status_display(self, obj):
        """Display Borrower.status."""
        return obj.status.capitalize()
    get_status_display.short_description = "Status"

@admin.register(Transaction)
class TransactionAdmin(admin.ModelAdmin):
    list_display = ('borrow_date', 'return_date', 'status', 'manager', 'mobile_user', 'get_items', 'borrower')
    list_filter = ('status', 'borrow_date', 'return_date', 'manager', 'mobile_user')
    search_fields = ('borrower__name', 'items__item_name')
    raw_id_fields = ('manager', 'mobile_user', 'borrower')
    autocomplete_fields = ['manager', 'mobile_user', 'borrower']

    def get_items(self, obj):
        """Display comma-separated list of item names."""
        return ', '.join([item.item_name for item in obj.items.all()])
    get_items.short_description = 'Items'

@admin.register(RegistrationRequest)
class RegistrationRequestAdmin(admin.ModelAdmin):
    list_display = ['username', 'email', 'status', 'requested_manager']
    list_filter = ['status']
    search_fields = ['username', 'email']
    raw_id_fields = ['requested_manager']
    autocomplete_fields = ['requested_manager']