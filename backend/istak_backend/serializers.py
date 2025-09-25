from rest_framework import serializers
from .models import Transaction, Item, CustomUser, RegistrationRequest, Borrower

class ItemSerializer(serializers.ModelSerializer):
    image = serializers.ImageField(allow_null=True, required=False)
    last_transaction_return_date = serializers.SerializerMethodField()

    class Meta:
        model = Item
        fields = ['id', 'item_name', 'condition', 'current_transaction', 'image', 'last_transaction_return_date']
        extra_kwargs = {'manager': {'read_only': True}}

    def get_last_transaction_return_date(self, obj):
        last_transaction = obj.transactions.filter(status='returned').order_by('-return_date').first()
        return last_transaction.return_date if last_transaction else None

class RegistrationRequestSerializer(serializers.ModelSerializer):
    class Meta:
        model = RegistrationRequest
        fields = ['id', 'username', 'email', 'status']

class BorrowerSerializer(serializers.ModelSerializer):
    borrowed_items = serializers.SerializerMethodField()
    transaction_count = serializers.SerializerMethodField()

    class Meta:
        model = Borrower
        fields = ['id', 'name', 'school_id', 'status', 'borrowed_items', 'transaction_count']

    def get_borrowed_items(self, obj):
        transactions = Transaction.objects.filter(
            borrower=obj,
            status='borrowed',
            mobile_user=self.context['request'].user
        ).select_related('item')
        return [transaction.item.item_name for transaction in transactions]

    def get_transaction_count(self, obj):
        return Transaction.objects.filter(
            borrower=obj,
            mobile_user=self.context['request'].user
        ).count()

class TransactionSerializer(serializers.ModelSerializer):
    item = serializers.StringRelatedField(read_only=True)
    school_id = serializers.CharField(source='borrower.school_id', read_only=True)
    borrower_name = serializers.CharField(source='borrower.name', read_only=True)
    condition_before = serializers.CharField(required=False, allow_null=True)
    condition_after = serializers.CharField(required=False, allow_null=True)

    class Meta:
        model = Transaction
        fields = ['id', 'borrow_date', 'return_date', 'status', 'item', 'school_id', 'borrower_name', 'condition_before', 'condition_after']

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
    

class ReportSerializer(serializers.Serializer):
    id = serializers.CharField()
    borrowerName = serializers.CharField()
    itemStatus = serializers.CharField()
    itemName = serializers.CharField()
    returnedDate = serializers.CharField(allow_null=True)
    condition = serializers.CharField()