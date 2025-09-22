from rest_framework import serializers
from .models import Transaction, Item, CustomUser, RegistrationRequest, Borrower

class ItemSerializer(serializers.ModelSerializer):
    image = serializers.ImageField(allow_null=True, required=False)
    
    class Meta:
        model = Item
        fields = '__all__'
        extra_kwargs = {'manager': {'read_only': True}}

class RegistrationRequestSerializer(serializers.ModelSerializer):
    class Meta:
        model = RegistrationRequest
        fields = ['id', 'username', 'email', 'status']

class BorrowerSerializer(serializers.ModelSerializer):
    class Meta:
        model = Borrower
        fields = ['id', 'name', 'school_id', 'status']

class TransactionSerializer(serializers.ModelSerializer):
    item = serializers.StringRelatedField(read_only=True)
    school_id = serializers.CharField(source='borrower.school_id', read_only=True)

    class Meta:
        model = Transaction
        fields = ['id', 'borrow_date', 'return_date', 'status', 'item', 'school_id']

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