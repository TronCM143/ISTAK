from rest_framework import serializers
from .models import BorrowTransaction, Item, CustomUser, RegistrationRequest

class ItemSerializer(serializers.ModelSerializer):
    image = serializers.ImageField(allow_null=True, required=False)
    class Meta:
        model = Item
        fields = '__all__'
        extra_kwargs = {'manager': {'read_only': True}}

class RegistrationRequestSerializer(serializers.ModelSerializer):
    status = serializers.SerializerMethodField()

    class Meta:
        model = RegistrationRequest
        fields = ['id', 'username', 'email', 'status']

    def get_status(self, obj):
        return 'approved' if obj.is_approved else 'pending'
    
    
class BorrowTransactionSerializer(serializers.ModelSerializer):
    item_name = serializers.CharField(source='item.item_name', read_only=True)
    borrowerName = serializers.CharField(read_only=True)
    
    class Meta:
        model = BorrowTransaction
        fields = ['id', 'borrowerName', 'item_name', 'borrow_date', 'return_date']