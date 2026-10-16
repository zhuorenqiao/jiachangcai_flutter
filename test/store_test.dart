import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jiachangcai_flutter/data/app_store.dart';
import 'package:jiachangcai_flutter/models/models.dart';

void main() {
  final seedJson = File('assets/menu.json').readAsStringSync();
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppStore store;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = AppStore(await SharedPreferences.getInstance());
    await store.initialize(seedJson: seedJson);
    await store.login();
  });
  test('seed menu is complete and does not duplicate after restart', () async {
    expect(store.categories.length, 5);
    expect(store.dishes.length, 16);
    final restored = AppStore(await SharedPreferences.getInstance());
    await restored.initialize();
    expect(restored.dishes.length, 16);
    expect(restored.userId, store.userId);
  });
  test('integer money avoids floating point errors and validates prices', () {
    expect(parsePrice('0.10') + parsePrice('0.20'), 30);
    expect(parsePrice('38'), 3800);
    expect(parsePrice('3.5'), 350);
    for (final value in ['', '-1', 'NaN', '1.001', 'Infinity']) {
      expect(() => parsePrice(value), throwsFormatException);
    }
  });
  test(
    'checkout snapshots current prices, preserves remark, empties cart',
    () async {
      await store.setQuantity('d101', 2);
      await store.setRemark('少盐');
      final original = store.dish('d101')!;
      await store.saveDish(
        Dish(
          id: original.id,
          categoryId: original.categoryId,
          name: original.name,
          price: 3900,
        ),
      );
      final order = await store.checkout();
      expect(order.total, 7800);
      expect(order.remark, '少盐');
      expect(store.cartCount, 0);
      await store.saveDish(
        Dish(
          id: original.id,
          categoryId: original.categoryId,
          name: '新菜名',
          price: 100,
        ),
      );
      expect(store.orders.first.items.first.name, '红烧肉');
      expect(store.orders.first.total, 7800);
      final restored = AppStore(await SharedPreferences.getInstance());
      await restored.initialize();
      expect(restored.orders.first.total, 7800);
    },
  );
  test('off shelf and deleted items are excluded, never submitted', () async {
    await store.setQuantity('d101', 1);
    await store.setQuantity('d102', 2);
    await store.saveDish(store.dish('d101')!.copyWith(available: false));
    await store.removeDish('d102');
    expect(store.cartCount, 0);
    expect(store.cartTotal, 0);
    expect(store.invalidCount, 2);
    expect(store.checkout(), throwsStateError);
    expect(() => store.setQuantity('d101', 1), throwsStateError);
  });
  test(
    'terminal orders cannot transition; reorder filters deleted dishes',
    () async {
      await store.setQuantity('d101', 1);
      await store.setQuantity('d102', 2);
      final order = await store.checkout();
      await store.updateOrderStatus(order.id, OrderStatus.completed);
      expect(
        () => store.updateOrderStatus(order.id, OrderStatus.cancelled),
        throwsStateError,
      );
      await store.removeDish('d101');
      expect(await store.reorder(store.orders.first), 1);
      expect(store.cartCount, 2);
      expect(store.cartTotal, 6400);
    },
  );
  test(
    'cart, remark and orders are isolated per identity and survive logout',
    () async {
      await store.setQuantity('d101', 1);
      await store.checkout();
      await store.setQuantity('d102', 2);
      await store.setRemark('不要辣');
      await store.logout();
      await store.login(id: 'second');
      expect(store.cartCount, 0);
      expect(store.orders, isEmpty);
      expect(store.remark, '');
      await store.login();
      expect(store.cartCount, 2);
      expect(store.orders.length, 1);
      expect(store.remark, '不要辣');
    },
  );
  test('category safety, duplicates, and dish validation', () async {
    expect(() => store.removeCategory('c1'), throwsStateError);
    await store.saveCategory('新分类');
    final cat = store.categories.last;
    expect(() => store.saveCategory('新分类'), throwsArgumentError);
    await store.saveCategory('新分类名称', id: cat.id);
    await store.removeCategory(cat.id);
    expect(store.categories.length, 5);
    expect(
      () => store.saveDish(
        const Dish(id: 'x', categoryId: 'missing', name: '测试', price: 100),
      ),
      throwsArgumentError,
    );
    expect(
      () => store.saveDish(
        const Dish(id: 'x', categoryId: 'c1', name: '测试', price: -1),
      ),
      throwsArgumentError,
    );
    expect(() => store.setQuantity('d101', 1000), throwsArgumentError);
  });
  test('queued writes preserve latest cart and remark after restart', () async {
    await Future.wait([
      store.setQuantity('d101', 1),
      store.setQuantity('d101', 2),
      store.setRemark('少油'),
    ]);
    final restored = AppStore(await SharedPreferences.getInstance());
    await restored.initialize();
    expect(restored.quantity('d101'), 2);
    expect(restored.remark, '少油');
  });
  test('cancel order and preserve terminal status after reload', () async {
    await store.setQuantity('d401', 1);
    final order = await store.checkout();
    await store.updateOrderStatus(order.id, OrderStatus.cancelled);
    final restored = AppStore(await SharedPreferences.getInstance());
    await restored.initialize();
    expect(restored.orders.single.status, OrderStatus.cancelled);
  });
  test(
    'corrupt storage is reported and never overwritten with seeds',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppStore.storageKey, 'broken');
      expect(AppStore(prefs).initialize(), throwsFormatException);
      expect(prefs.getString(AppStore.storageKey), 'broken');
    },
  );
}
