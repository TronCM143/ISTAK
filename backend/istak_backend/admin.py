from django.contrib import admin
from django.contrib.auth.admin import UserAdmin
from django.contrib.admin import SimpleListFilter
from .models import CustomUser, Item, Borrower, BorrowTransaction

# Custom filter for is_active
class IsActiveFilter(SimpleListFilter):
    title = 'active status'  # Display name in admin
    parameter_name = 'is_active'  # URL parameter name

    def lookups(self, request, model_admin):
        # Define the filter options
        return (
            ('1', 'Yes'),
            ('0', 'No'),
            ('None', 'Pending'),
        )

    def queryset(self, request, queryset):
        # Apply the filter based on the selected value
        value = self.value()
        if value == '1':
            return queryset.filter(is_active=True)
        elif value == '0':
            return queryset.filter(is_active=False)
        elif value == 'None':
            return queryset.filter(is_active__isnull=True)
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
            'fields': ('username', 'email', 'password1', 'password2', 'role', 'manager', 'is_staff', 'is_active')}
        ),
    )
    search_fields = ('username', 'email')
    ordering = ('username',)
    autocomplete_fields = ['manager']

@admin.register(Item)
class ItemAdmin(admin.ModelAdmin):
    list_display = ('item_name', 'status', 'condition', 'manager_username')
    list_filter = ('status', 'condition', 'manager')
    search_fields = ('item_name',)
    fields = ('item_name', 'status', 'condition', 'user', 'manager', 'current_transaction', 'last_borrowed', 'image')
    raw_id_fields = ('user', 'manager', 'current_transaction')
    autocomplete_fields = ['user', 'manager', 'current_transaction']

    def manager_username(self, obj):
        """Safely display manager username without triggering __str__ errors."""
        if obj.manager:
            return obj.manager.username or "No Username"
        return "No Manager"
    manager_username.short_description = "Manager"
    manager_username.admin_order_field = 'manager__username'

@admin.register(Borrower)
class BorrowerAdmin(admin.ModelAdmin):
    list_display = ('name', 'school_id', 'get_is_active_display', 'borrow_transaction_id')
    list_filter = ('is_active', IsActiveFilter)  # Use the custom filter alongside the field
    search_fields = ('name', 'school_id')
    fields = ('name', 'school_id', 'is_active', 'borrow_transaction')
    autocomplete_fields = ['borrow_transaction']

    def get_is_active_display(self, obj):
        """Custom display for is_active to handle None."""
        if obj.is_active is True:
            return "Yes"
        elif obj.is_active is False:
            return "No"
        return "Pending"
    get_is_active_display.short_description = "Active"

    def borrow_transaction_id(self, obj):
        """Safely display borrow_transaction ID."""
        return obj.borrow_transaction.id if obj.borrow_transaction else "None"
    borrow_transaction_id.short_description = "Transaction ID"

@admin.register(BorrowTransaction)
class BorrowTransactionAdmin(admin.ModelAdmin):
    list_display = ('borrow_date', 'return_date', 'manager', 'mobile_user', 'item', 'borrower')
    list_filter = ('borrow_date', 'return_date', 'manager', 'mobile_user')
    search_fields = ('borrower__name', 'item__item_name')
    raw_id_fields = ('manager', 'mobile_user', 'item', 'borrower')
    autocomplete_fields = ['manager', 'mobile_user', 'item', 'borrower']