class ProductItem {
  final String id;
  final String name;
  final String description;
  final int price;
  final int pointsAmount;
  
  ProductItem({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.pointsAmount,
  });
  
  String get priceText => price > 0 ? '${price}원' : '무료';
}