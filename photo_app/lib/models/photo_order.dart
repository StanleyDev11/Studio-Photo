enum OrderStatus { pending, processing, completed, cancelled }
enum OrderType { detail, batch }

class OrderItem {
  final String imageUrl;
  final String size;
  final int quantity;
  final double price;

  OrderItem({
    required this.imageUrl,
    required this.size,
    required this.quantity,
    required this.price,
  });
}

class PhotoOrder {
  final String id;
  final DateTime date;
  final OrderStatus status;
  final double totalPrice;
  final String paymentMethod;
  final List<OrderItem> items;
  final OrderType type;

  PhotoOrder({
    required this.id,
    required this.date,
    required this.status,
    required this.totalPrice,
    required this.paymentMethod,
    required this.items,
    required this.type,
  });
}
