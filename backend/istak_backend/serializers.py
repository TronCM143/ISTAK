from uuid import UUID
from rest_framework import serializers
from .models import Transaction, Item, CustomUser, RegistrationRequest, Borrower

class ItemSerializer(serializers.ModelSerializer):
    image = serializers.ImageField(allow_null=True, required=False)
    last_transaction_return_date = serializers.SerializerMethodField()

    class Meta:
        model = Item
        fields = ['id', 'item_name', 'condition', 'image', 'last_transaction_return_date']
        extra_kwargs = {'manager': {'read_only': True}}

    def get_last_transaction_return_date(self, obj):
        last_transaction = obj.transactions.filter(status='returned').order_by('-return_date').first()
        return last_transaction.return_date if last_transaction else None

class RegistrationRequestSerializer(serializers.ModelSerializer):
    class Meta:
        model = RegistrationRequest
        fields = ['id', 'username', 'email', 'status']

from rest_framework import serializers
from istak_backend.models import Borrower, Transaction

class BorrowerSerializer(serializers.ModelSerializer):
    borrowed_items = serializers.SerializerMethodField()
    transaction_count = serializers.SerializerMethodField()

    class Meta:
        model = Borrower
        fields = ['id', 'name', 'school_id', 'status', 'image', 'borrowed_items', 'transaction_count']

    def get_borrowed_items(self, obj):
        transactions = Transaction.objects.filter(
            borrower=obj,
            status='borrowed',
            mobile_user=self.context['request'].user
        ).prefetch_related('items')
        return [t.items.first().item_name for t in transactions if t.items.exists()]

    def get_transaction_count(self, obj):
        return Transaction.objects.filter(
            borrower=obj,
            mobile_user=self.context['request'].user
        ).count()

class TransactionSerializer(serializers.ModelSerializer):
    items = ItemSerializer(many=True, read_only=True)
    school_id = serializers.CharField(source='borrower.school_id', read_only=True)
    borrower_name = serializers.CharField(source='borrower.name', read_only=True)

    class Meta:
        model = Transaction
        fields = ['id', 'borrow_date', 'return_date', 'status', 'items', 'school_id', 'borrower_name']

class TopBorrowedItemsSerializer(serializers.ModelSerializer):
    borrow_count = serializers.IntegerField()
    image = serializers.SerializerMethodField()

    class Meta:
        model = Item
        fields = ['id', 'item_name', 'borrow_count', 'image']

    def get_image(self, obj):
        request = self.context.get('request')
        if obj.image and hasattr(obj.image, 'url'):
            return request.build_absolute_uri(obj.image.url) if request else obj.image.url
        return None


class CreateBorrowingSerializer(serializers.Serializer):
    school_id = serializers.CharField(max_length=10)
    name = serializers.CharField(max_length=255)
    status = serializers.ChoiceField(choices=['active', 'inactive'], default='active')
    image = serializers.ImageField(required=False, allow_null=True)
    return_date = serializers.DateField()
    item_ids = serializers.ListField(
        child=serializers.CharField(),  # Accept any string
        allow_empty=False
    )

    def validate_item_ids(self, value):
        invalid_ids = []
        for item_id in value:
            if not item_id or not isinstance(item_id, str):
                invalid_ids.append(item_id)
            elif not Item.objects.filter(id=item_id).exists():
                invalid_ids.append(item_id)
        if invalid_ids:
            raise serializers.ValidationError(f"Invalid or non-existent item IDs: {invalid_ids}")
        return value

    def validate(self, data):
        if 'image' in self.context['request'].FILES:
            data['image'] = self.context['request'].FILES['image']
        return data

class ReportSerializer(serializers.Serializer):
    id = serializers.CharField()
    borrowerName = serializers.CharField()
    itemStatus = serializers.CharField()
    itemName = serializers.CharField()
    returnedDate = serializers.CharField(allow_null=True)
    condition = serializers.CharField()