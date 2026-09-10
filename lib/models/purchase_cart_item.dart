class PurchaseCartItem {
  final String featureId;
  final String title;
  final double price;

  const PurchaseCartItem({
    required this.featureId,
    required this.title,
    required this.price,
  });

  Map<String, dynamic> toMap() {
    return {'featureId': featureId, 'title': title, 'price': price};
  }

  factory PurchaseCartItem.fromMap(Map<String, dynamic> map) {
    return PurchaseCartItem(
      featureId: map['featureId'] ?? '',
      title: map['title'] ?? '',
      price: (map['price'] ?? 0.0).toDouble(),
    );
  }
}
