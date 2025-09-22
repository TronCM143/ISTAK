import uuid
from django.db import models
from django.contrib.auth.models import AbstractUser
from django.core.exceptions import ValidationError
from django.contrib.auth.hashers import make_password

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
        limit_choices_to={'role': 'user_web'},
        db_index=True
    )
    fcm_token = models.CharField(max_length=255, null=True, blank=True, db_index=True)

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
    condition = models.CharField(max_length=20, null=True, blank=True)
    user = models.ForeignKey(
        CustomUser,
        limit_choices_to={'role': 'user_mobile'},
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name='items',
        db_index=True
    )
    manager = models.ForeignKey(
        CustomUser,
        limit_choices_to={'role': 'user_web'},
        null=False,
        blank=False,
        on_delete=models.PROTECT,
        related_name='managed_items',
        db_index=True
    )
    current_transaction = models.ForeignKey(
        'Transaction',
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name='item_current',
        db_index=True
    )
    image = models.ImageField(upload_to='item_images/', null=True, blank=True)

    class Meta:
        unique_together = ('item_name', 'manager')

    def __str__(self):
        return self.item_name

class Borrower(models.Model):
    STATUS_CHOICES = [
        ('pending', 'Pending'),
        ('active', 'Active'),
        ('inactive', 'Inactive'),
    ]
    name = models.CharField(max_length=255)
    school_id = models.CharField(max_length=10, null=True, blank=True, unique=True)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')

    def __str__(self):
        return f"{self.name} (School ID: {self.school_id})"

class Transaction(models.Model):
    STATUS_CHOICES = [
        ('borrowed', 'Borrowed'),
        ('returned', 'Returned'),
        ('overdue', 'Overdue'),
    ]
    borrow_date = models.DateField(auto_now_add=True)
    return_date = models.DateField(null=True, blank=True)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='borrowed', db_index=True)
    manager = models.ForeignKey(CustomUser, limit_choices_to={'role': 'user_web'}, on_delete=models.PROTECT, related_name='transactions_managed')
    mobile_user = models.ForeignKey(CustomUser, limit_choices_to={'role': 'user_mobile'}, on_delete=models.PROTECT, related_name='transactions_made')
    item = models.ForeignKey(Item, on_delete=models.CASCADE, related_name='transactions')
    borrower = models.ForeignKey(Borrower, on_delete=models.CASCADE, related_name='transactions', null=True, blank=True)

    class Meta:
        indexes = [
            models.Index(fields=['status', 'manager']),
        ]
        constraints = [
            models.UniqueConstraint(fields=['item'], condition=models.Q(status='borrowed'), name='unique_active_borrow_per_item')
        ]

    def clean(self):
        if self.return_date and self.return_date < self.borrow_date:
            raise ValidationError("Return date cannot be before borrow date.")

    def __str__(self):
        borrower_name = self.borrower.name if self.borrower else "Unknown Borrower"
        return f"Transaction for {borrower_name} on {self.borrow_date}"


class RegistrationRequest(models.Model):
    STATUS_CHOICES = [
        ('pending', 'Pending'),
        ('approved', 'Approved'),
        ('rejected', 'Rejected'),
    ]
    username = models.CharField(max_length=150, unique=True)
    email = models.EmailField()
    password = models.CharField(max_length=128)
    requested_manager = models.ForeignKey(
        CustomUser,
        limit_choices_to={'role': 'user_web'},
        on_delete=models.CASCADE,
        related_name='registration_requests',
        db_index=True
    )
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    created_at = models.DateTimeField(auto_now_add=True)

    def save(self, *args, **kwargs):
        if self.password and not self.password.startswith('pbkdf2_'):
            self.password = make_password(self.password)
        super().save(*args, **kwargs)

    def __str__(self):
        return f"Request for {self.username} to {self.requested_manager}"