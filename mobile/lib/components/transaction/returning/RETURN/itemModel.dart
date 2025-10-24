class ReturnItem {
  final String itemId;
  final String itemName;
  String condition;

  ReturnItem({
    required this.itemId,
    required this.itemName,
    required this.condition,
  });

  factory ReturnItem.fromJson(Map<String, dynamic> json) {
    return ReturnItem(
      itemId: json['itemId']?.toString() ?? json['id']?.toString() ?? '',
      itemName: json['itemName'] ?? json['name'] ?? json['item_name'] ?? '',
      condition: json['condition'] ?? 'Good',
    );
  }

  Map<String, dynamic> toJson() {
    return {'itemId': itemId, 'itemName': itemName, 'condition': condition};
  }
}
