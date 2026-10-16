import 'dart:convert';

String money(int cents) => (cents / 100).toStringAsFixed(2);
int parsePrice(String text) {
  if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(text.trim())) {
    throw const FormatException('请输入正确的价格，最多两位小数');
  }
  final parts = text.trim().split('.');
  return int.parse(parts.first) * 100 +
      (parts.length == 1 ? 0 : int.parse(parts[1].padRight(2, '0')));
}

class Category {
  final String id, name;
  final int sort;
  const Category({required this.id, required this.name, this.sort = 0});
  factory Category.fromJson(Map<String, dynamic> j) => Category(
    id: j['id'] as String,
    name: j['name'] as String,
    sort: (j['sort'] as num?)?.toInt() ?? 0,
  );
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'sort': sort};
  String get icon => switch (name) {
    '荤菜热炒' => 'cat-meat',
    '素菜时蔬' => 'cat-veg',
    '汤羹炖品' => 'cat-soup',
    '饮品甜点' => 'cat-drink',
    _ => 'cat-staple',
  };
}

class Dish {
  final String id, categoryId, name, description, image;
  final int price, sales, sort;
  final bool featured, available;
  const Dish({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.price,
    this.description = '',
    this.image = '',
    this.sales = 0,
    this.sort = 0,
    this.featured = false,
    this.available = true,
  });
  factory Dish.fromJson(Map<String, dynamic> j) => Dish(
    id: j['id'] as String,
    categoryId: j['categoryId'] as String,
    name: j['name'] as String,
    price: j['price'] as int,
    description: j['description'] as String? ?? '',
    image: j['image'] as String? ?? '',
    sales: j['sales'] as int? ?? 0,
    sort: j['sort'] as int? ?? 0,
    featured: j['featured'] as bool? ?? false,
    available: j['available'] as bool? ?? true,
  );
  factory Dish.fromSeed(Map<String, dynamic> j) => Dish(
    id: j['id'] as String,
    categoryId: j['cat'] as String,
    name: j['name'] as String,
    price: ((j['price'] as num) * 100).round(),
    description: j['desc'] as String,
    image: 'assets/seed/dishes/${j['img']}.jpg',
    sales: j['sales'] as int,
    featured: j['featured'] as bool,
    sort: j['sort'] as int,
  );
  Dish copyWith({bool? available}) => Dish(
    id: id,
    categoryId: categoryId,
    name: name,
    price: price,
    description: description,
    image: image,
    sales: sales,
    sort: sort,
    featured: featured,
    available: available ?? this.available,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'categoryId': categoryId,
    'name': name,
    'price': price,
    'description': description,
    'image': image,
    'sales': sales,
    'sort': sort,
    'featured': featured,
    'available': available,
  };
}

class OrderItem {
  final String id, name, image;
  final int price, quantity;
  const OrderItem({
    required this.id,
    required this.name,
    required this.price,
    required this.quantity,
    this.image = '',
  });
  factory OrderItem.fromJson(Map<String, dynamic> j) => OrderItem(
    id: j['id'] as String,
    name: j['name'] as String,
    price: j['price'] as int,
    quantity: j['quantity'] as int,
    image: j['image'] as String? ?? '',
  );
  int get subtotal => price * quantity;
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'image': image,
    'price': price,
    'quantity': quantity,
  };
}

enum OrderStatus {
  pending('待完成'),
  completed('已完成'),
  cancelled('已取消');

  final String label;
  const OrderStatus(this.label);
}

class FoodOrder {
  final String id, ownerId, remark;
  final DateTime createdAt;
  final List<OrderItem> items;
  final OrderStatus status;
  FoodOrder({
    required this.id,
    required this.ownerId,
    required this.createdAt,
    required List<OrderItem> items,
    this.remark = '',
    this.status = OrderStatus.pending,
  }) : items = List.unmodifiable(items);
  int get total => items.fold(0, (s, x) => s + x.subtotal);
  int get count => items.fold(0, (s, x) => s + x.quantity);
  String get number =>
      '${createdAt.year}${createdAt.month.toString().padLeft(2, '0')}'
      '${createdAt.day.toString().padLeft(2, '0')}${id.substring(id.length - 6)}';
  FoodOrder withStatus(OrderStatus value) => FoodOrder(
    id: id,
    ownerId: ownerId,
    createdAt: createdAt,
    items: items,
    remark: remark,
    status: value,
  );
  factory FoodOrder.fromJson(Map<String, dynamic> j) => FoodOrder(
    id: j['id'] as String,
    ownerId: j['ownerId'] as String,
    createdAt: DateTime.parse(j['createdAt'] as String),
    items: (j['items'] as List)
        .map((x) => OrderItem.fromJson(Map<String, dynamic>.from(x)))
        .toList(),
    remark: j['remark'] as String? ?? '',
    status: OrderStatus.values.byName(j['status'] as String),
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'ownerId': ownerId,
    'createdAt': createdAt.toIso8601String(),
    'items': items.map((x) => x.toJson()).toList(),
    'remark': remark,
    'status': status.name,
  };
}

Map<String, dynamic> decodeObject(String text) =>
    Map<String, dynamic>.from(jsonDecode(text) as Map);
