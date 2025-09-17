import uuid
from django.db import models
from django.contrib.auth.models import AbstractUser
from django.core.exceptions import ValidationError

class CustomUser(AbstractUser):
    ROLE_CHOICES = [
        ('user_mobile', 'Mobile App User'),
        ('user_web', 'Manager User'),
    ]
    role = models.CharField(max_length=20, choices=ROLE_CHOICES, default='user_mobile')
    manager = models.ForeignKey(
        'self',
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name='mobile_users',
        limit_choices_to={'role': 'user_web'}
    )
    fcm_token = models.CharField(max_length=255, null=True, blank=True)

    def clean(self):
        if self.role == 'user_mobile' and not self.manager:
            raise ValidationError("Mobile users must have a manager assigned.")
        if self.role == 'user_web' and self.manager is not None:    
            raise ValidationError("Managers cannot have a manager assigned.")

    def __str__(self):
        username = self.username if self.username else "Unknown User"
        role = self.role if self.role else "Unknown Role"
        return f"{username} ({role})"

class Item(models.Model):
    item_name = models.CharField(max_length=50)
    status = models.CharField(max_length=20)
    condition = models.CharField(max_length=20, null=True, blank=True)
    user = models.ForeignKey(
        CustomUser,
        limit_choices_to={'role': 'user_mobile'},
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name='items'
    )
    manager = models.ForeignKey(
        CustomUser,
        limit_choices_to={'role': 'user_web'},
        null=False,
        blank=False,
        on_delete=models.PROTECT,
        related_name='managed_items'
    )
    current_transaction = models.ForeignKey(
        'BorrowTransaction',
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name='item_current'
    )
    last_borrowed = models.DateTimeField(null=True, blank=True)
    image = models.ImageField(upload_to='item_images/', null=True, blank=True)
    def __str__(self):  
        return self.item_name
    
class Borrower(models.Model):
    name = models.CharField(max_length=255)
    school_id = models.CharField(max_length=10, null=True, blank=True)
    is_active = models.BooleanField(
        ("active status"),
        null=True,
        blank=True,
        default=None,
        help_text=("Set to True if active, False if inactive, or None if pending.")
    )
    borrow_transaction = models.ForeignKey(
        'BorrowTransaction',
        on_delete=models.CASCADE,
        related_name='borrowers',
        null=True,
        blank=True
    )

    def __str__(self):
        return f"{self.name} (School ID: {self.school_id})"

class BorrowTransaction(models.Model):
    borrow_date = models.DateField(auto_now_add=True)
    return_date = models.DateField(null=True, blank=True)
    manager = models.ForeignKey(
        CustomUser,
        limit_choices_to={'role': 'user_web'},
        on_delete=models.PROTECT,
        related_name='transactions_managed'
    )
    mobile_user = models.ForeignKey(
        CustomUser,
        limit_choices_to={'role': 'user_mobile'},
        on_delete=models.PROTECT,
        related_name='transactions_made'
    )
    item = models.ForeignKey(
        Item,
        on_delete=models.CASCADE,
        related_name='transactions'
    )
    borrower = models.ForeignKey(
        Borrower,
        on_delete=models.CASCADE,
        related_name='borrow_transactions',
        null=True,  # Allow null borrowers
        blank=True
    )

    def __str__(self):
        borrower_name = self.borrower.name if self.borrower else "Unknown Borrower"
        return f"Transaction for {borrower_name} on {self.borrow_date}"
    
    
class RegistrationRequest(models.Model):
    username = models.CharField(max_length=150, unique=True)
    email = models.EmailField()
    password = models.CharField(max_length=128)
    requested_manager = models.ForeignKey(
        CustomUser,
        limit_choices_to={'role': 'user_web'},
        on_delete=models.CASCADE,
        related_name='registration_requests'
    )
    is_approved = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Request for {self.username} to {self.requested_manager}"


