from django.contrib import admin
from django.contrib.auth.admin import UserAdmin
from django.contrib.admin import SimpleListFilter
from .models import CustomUser, Item, Borrower, Transaction


# Custom filter for Borrower.status
class BorrowerStatusFilter(SimpleListFilter):
    title = 'borrower status'  # Display name in admin
    parameter_name = 'status'  # URL parameter name

    def lookups(self, request, model_admin):
        # Define the filter options
        return (
            ('pending', 'Pending'),
            ('active', 'Active'),
            ('inactive', 'Inactive'),
        )

    def queryset(self, request, queryset):
        # Apply the filter based on the selected value
        value = self.value()
        if value in ['pending', 'active', 'inactive']:
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
    fields = ('item_name', 'condition', 'user', 'manager', 'current_transaction', 'image')
    raw_id_fields = ('user', 'manager', 'current_transaction')
    autocomplete_fields = ['user', 'manager', 'current_transaction']

    def get_status_display(self, obj):
        """Display computed status based on current_transaction."""
        if obj.current_transaction:
            return obj.current_transaction.status  # borrowed / returned / overdue
        return 'available'
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
    fields = ('name', 'school_id', 'status')
    # removed autocomplete_fields (not valid for reverse relations)

    def get_status_display(self, obj):
        """Display Borrower.status."""
        return obj.status.capitalize()
    get_status_display.short_description = "Status"

    # def borrow_transactions_id(self, obj):
    #     """Display related transaction IDs."""
    #     transaction_ids = obj.borrow_transactions.values_list('id', flat=True)
    #     return ", ".join(str(id) for id in transaction_ids) if transaction_ids else "None"
    # borrow_transactions_id.short_description = "Transaction IDs"


@admin.register(Transaction)
class TransactionAdmin(admin.ModelAdmin):
    list_display = ('borrow_date', 'return_date', 'status',
                    'manager', 'mobile_user', 'item', 'borrower')
    list_filter = ('status', 'borrow_date', 'return_date', 'manager', 'mobile_user')
    search_fields = ('borrower__name', 'item__item_name')
    raw_id_fields = ('manager', 'mobile_user', 'item', 'borrower')
    autocomplete_fields = ['manager', 'mobile_user', 'item', 'borrower']
