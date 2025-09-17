from rest_framework import serializers
from .models import BorrowTransaction, Item, CustomUser, RegistrationRequest, Borrower

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

class BorrowerSerializer(serializers.ModelSerializer):
    class Meta:
        model = Borrower
        fields = ['id', 'name', 'school_id', 'is_active']

class BorrowTransactionSerializer(serializers.ModelSerializer):
    borrower = BorrowerSerializer()
    item = ItemSerializer()

    class Meta:
        model = BorrowTransaction
        fields = ['id', 'borrow_date', 'return_date', 'manager', 'mobile_user', 'item', 'borrower']

    def create(self, validated_data):
        borrower_data = validated_data.pop('borrower')
        borrower, created = Borrower.objects.get_or_create(**borrower_data)
        validated_data['borrower'] = borrower
        return super().create(validated_data)

    def update(self, instance, validated_data):
        borrower_data = validated_data.pop('borrower')
        borrower, created = Borrower.objects.update_or_create(
            id=instance.borrower.id,
            defaults=borrower_data
        )
        validated_data['borrower'] = borrower
        return super().update(instance, validated_data)

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