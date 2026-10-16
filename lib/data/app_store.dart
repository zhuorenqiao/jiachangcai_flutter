import 'dart:convert';

import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

/// Owns the local-mode domain. All money is represented in integer cents.
class AppStore extends ChangeNotifier {
  static const storageKey = 'jcc.flutter.v1';
  final SharedPreferences preferences;
  final List<Category> _categories = [];
  final List<Dish> _dishes = [];
  final List<FoodOrder> _orders = [];
  final Map<String, Map<String, int>> _carts = {};
  final Map<String, String> _remarks = {};
  String? _userId;
  Future<void> _writeQueue = Future.value();
  AppStore(this.preferences);
  String? get userId => _userId;
  String get userName => '本机用户';
  List<Category> get categories => List.unmodifiable(
    [..._categories]..sort((a, b) => a.sort.compareTo(b.sort)),
  );
  List<Dish> get dishes =>
      List.unmodifiable([..._dishes]..sort((a, b) => a.sort.compareTo(b.sort)));
  List<Dish> get availableDishes => dishes.where((d) => d.available).toList();
  List<FoodOrder> get orders =>
      List.unmodifiable(_orders.where((o) => o.ownerId == _userId));
  String get remark => _remarks[_userId] ?? '';
  Map<String, int> get _cart => _carts[_userId] ?? {};
  int quantity(String id) => _cart[id] ?? 0;
  Dish? dish(String id) {
    for (final d in _dishes) {
      if (d.id == id) return d;
    }
    return null;
  }

  List<OrderItem> get cartItems =>
      _cart.entries.where((e) => dish(e.key)?.available ?? false).map((e) {
        final d = dish(e.key)!;
        return OrderItem(
          id: d.id,
          name: d.name,
          price: d.price,
          image: d.image,
          quantity: e.value,
        );
      }).toList();
  int get cartCount => cartItems.fold(0, (s, x) => s + x.quantity);
  int get cartTotal => cartItems.fold(0, (s, x) => s + x.subtotal);
  int get invalidCount => _cart.length - cartItems.length;

  Future<void> initialize({String? seedJson}) async {
    final saved = preferences.getString(storageKey);
    if (saved == null) {
      final seed = decodeObject(
        seedJson ?? await rootBundle.loadString('assets/menu.json'),
      );
      _categories.addAll(
        (seed['categories'] as List).map(
          (j) => Category.fromJson(Map<String, dynamic>.from(j)),
        ),
      );
      _dishes.addAll(
        (seed['dishes'] as List).map(
          (j) => Dish.fromSeed(Map<String, dynamic>.from(j)),
        ),
      );
      await _save();
    } else {
      final j = decodeObject(saved);
      if (j['schema'] != 1) throw const FormatException('无法读取此版本的本地数据');
      _userId = j['userId'] as String?;
      _categories.addAll(
        (j['categories'] as List).map(
          (x) => Category.fromJson(Map<String, dynamic>.from(x)),
        ),
      );
      _dishes.addAll(
        (j['dishes'] as List).map(
          (x) => Dish.fromJson(Map<String, dynamic>.from(x)),
        ),
      );
      _orders.addAll(
        (j['orders'] as List).map(
          (x) => FoodOrder.fromJson(Map<String, dynamic>.from(x)),
        ),
      );
      (j['carts'] as Map).forEach(
        (k, v) => _carts[k as String] = Map<String, int>.from(v),
      );
      _remarks.addAll(Map<String, String>.from(j['remarks'] as Map));
    }
    notifyListeners();
  }

  String newId(String prefix) =>
      '$prefix${DateTime.now().microsecondsSinceEpoch}';
  Future<void> _save() {
    final snapshot = jsonEncode({
      'schema': 1,
      'userId': _userId,
      'categories': _categories.map((x) => x.toJson()).toList(),
      'dishes': _dishes.map((x) => x.toJson()).toList(),
      'orders': _orders.map((x) => x.toJson()).toList(),
      'carts': _carts,
      'remarks': _remarks,
    });
    final next = _writeQueue.catchError((Object _) {}).then((_) async {
      if (!await preferences.setString(storageKey, snapshot)) {
        throw StateError('本地保存失败，请检查设备存储空间');
      }
    });
    _writeQueue = next;
    notifyListeners();
    return next;
  }

  void _requireUser() {
    if (_userId == null) throw StateError('请先登录');
  }

  /// Device-local identity only; this does not represent WeChat authorization.
  Future<void> login({String id = 'local_device'}) {
    _userId = id;
    return _save();
  }

  Future<void> logout() {
    _userId = null;
    return _save();
  }

  Future<void> setQuantity(String id, int value) {
    _requireUser();
    final d = dish(id);
    if (value > 0 && (d == null || !d.available)) throw StateError('菜品已下架或删除');
    if (value > 999) throw ArgumentError('每道菜最多可选 999 份');
    final cart = _carts.putIfAbsent(_userId!, () => {});
    if (value <= 0) {
      cart.remove(id);
    } else {
      cart[id] = value;
    }
    return _save();
  }

  Future<void> clearCart() {
    _requireUser();
    _carts[_userId!] = {};
    return _save();
  }

  Future<void> setRemark(String value) {
    _requireUser();
    _remarks[_userId!] = value.length <= 100 ? value : value.substring(0, 100);
    return _save();
  }

  Future<FoodOrder> checkout() async {
    _requireUser();
    final items = cartItems;
    if (items.isEmpty) throw StateError('购物车是空的，请先选择菜品');
    final order = FoodOrder(
      id: newId('o'),
      ownerId: _userId!,
      createdAt: DateTime.now(),
      items: items,
      remark: remark.trim(),
    );
    _orders.insert(0, order);
    _carts[_userId!] = {};
    _remarks[_userId!] = '';
    await _save();
    return order;
  }

  Future<void> updateOrderStatus(String id, OrderStatus status) {
    _requireUser();
    final index = _orders.indexWhere((o) => o.id == id && o.ownerId == _userId);
    if (index < 0) throw StateError('订单不存在');
    if (_orders[index].status != OrderStatus.pending ||
        status == OrderStatus.pending) {
      throw StateError('该订单状态无法变更');
    }
    _orders[index] = _orders[index].withStatus(status);
    return _save();
  }

  Future<int> reorder(FoodOrder order) async {
    _requireUser();
    if (order.ownerId != _userId) throw StateError('无法访问此订单');
    final cart = _carts.putIfAbsent(_userId!, () => {});
    int skipped = 0;
    for (final item in order.items) {
      if (!(dish(item.id)?.available ?? false)) {
        skipped++;
        continue;
      }
      cart[item.id] = ((cart[item.id] ?? 0) + item.quantity).clamp(1, 999);
    }
    await _save();
    return skipped;
  }

  Future<void> saveDish(Dish d) {
    if (d.name.trim().isEmpty || d.name.length > 20) {
      throw ArgumentError('请输入 1–20 字的菜品名称');
    }
    if (d.price < 0) throw ArgumentError('价格不能为负数');
    if (!_categories.any((c) => c.id == d.categoryId)) {
      throw ArgumentError('请选择有效分类');
    }
    final index = _dishes.indexWhere((x) => x.id == d.id);
    if (index < 0) {
      _dishes.add(d);
    } else {
      _dishes[index] = d;
    }
    return _save();
  }

  Future<void> removeDish(String id) {
    _dishes.removeWhere((d) => d.id == id);
    return _save();
  }

  Future<void> saveCategory(String name, {String? id}) {
    final text = name.trim();
    if (text.isEmpty || text.length > 20) {
      throw ArgumentError('请输入 1–20 字的分类名称');
    }
    if (_categories.any((c) => c.name == text && c.id != id)) {
      throw ArgumentError('分类名称已存在');
    }
    final index = _categories.indexWhere((c) => c.id == id);
    if (id != null && index < 0) throw StateError('分类不存在');
    final category = Category(
      id: id ?? newId('c'),
      name: text,
      sort: index < 0
          ? (_categories.fold<int>(0, (v, c) => c.sort > v ? c.sort : v) + 1)
          : _categories[index].sort,
    );
    if (index < 0) {
      _categories.add(category);
    } else {
      _categories[index] = category;
    }
    return _save();
  }

  Future<void> removeCategory(String id) {
    if (_dishes.any((d) => d.categoryId == id)) {
      throw StateError('该分类下还有菜品，请先处理后再删除');
    }
    _categories.removeWhere((c) => c.id == id);
    return _save();
  }
}
