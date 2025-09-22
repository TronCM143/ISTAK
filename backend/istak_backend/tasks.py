from celery import shared_task
from django.utils import timezone
from datetime import timedelta
from istak_backend.models import Transaction
from istak_backend.firebase import send_push_notification

@shared_task
def notify_due_items():
    today = timezone.now().date()

    # Get transactions that are due today
    due_transactions = Transaction.objects.filter(
        return_date=today,
        item__current_transaction__isnull=False
    )

    for tx in due_transactions:
        if tx.mobile_user.fcm_token:
            send_push_notification(
                tx.mobile_user.fcm_token,
                "Item Due Today",
                f"School ID: {tx.schoolId} must return '{tx.item.item_name}' today."
            )

    # Get overdue transactions (past return_date)
    overdue_transactions = Transaction.objects.filter(
        return_date__lt=today,
        item__current_transaction__isnull=False
    )

    for tx in overdue_transactions:
        days_overdue = (today - tx.return_date).days
        if tx.mobile_user.fcm_token:
            send_push_notification(
                tx.mobile_user.fcm_token,
                "Overdue Item",
                f"School ID: {tx.schoolId} hasn’t returned '{tx.item.item_name}' "
                f"for {days_overdue} day(s) now."
            )
