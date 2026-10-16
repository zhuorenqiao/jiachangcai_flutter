import 'dart:convert';
import 'dart:io';

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jiachangcai_flutter/data/app_store.dart';
import 'package:jiachangcai_flutter/main.dart';
import 'package:jiachangcai_flutter/screens/dish_screen.dart';
import 'package:jiachangcai_flutter/screens/shell.dart';
import 'package:jiachangcai_flutter/widgets/common.dart';

void main() {
  final seedJson = File('assets/menu.json').readAsStringSync();
  testWidgets('phone: login, buy, submit, complete and reorder', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final store = AppStore(await SharedPreferences.getInstance());
    await store.initialize(seedJson: seedJson);
    await tester.pumpWidget(RestaurantApp(store: store));
    await tester.pumpAndSettle();
    await tester.tap(find.text('本机登录，开始点餐'));
    await tester.pumpAndSettle();
    expect(find.text('家常菜餐厅'), findsOneWidget);
    await tester.tap(find.text('去看看'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('立即购买'));
    await tester.pumpAndSettle();
    expect(store.cartCount, 1);
    await tester.tap(find.text('提交订单'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(store.orders.length, 1);
    await tester.tap(find.textContaining('订单 ${store.orders.first.number}'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('确认完成'));
    await tester.tap(find.text('确认完成'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('再来一单'));
    await tester.tap(find.text('再来一单'));
    await tester.pumpAndSettle();
    expect(store.cartCount, 1);
    expect(find.text('提交订单'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('narrow phone: menu categories, quantity, profile and editor', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final store = AppStore(await SharedPreferences.getInstance());
    await store.initialize(seedJson: seedJson);
    await store.login();
    await tester.pumpWidget(RestaurantApp(store: store));
    await tester.pumpAndSettle();
    await tester.tap(find.text('全部菜品'));
    await tester.pumpAndSettle();
    final stepper = find.byType(QuantityStepper).first;
    await tester.tap(
      find.descendant(of: stepper, matching: find.byIcon(Icons.add)),
    );
    await tester.pumpAndSettle();
    expect(store.cartCount, 1);
    await tester.tap(find.text('饮品甜点').first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('我的').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('菜品管理'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('编辑红烧肉'));
    await tester.pumpAndSettle();
    expect(find.text('编辑菜品'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
  testWidgets('tablet layout retains all navigation destinations', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final store = AppStore(await SharedPreferences.getInstance());
    await store.initialize(seedJson: seedJson);
    await store.login();
    await tester.pumpWidget(RestaurantApp(store: store));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationDestination), findsNWidgets(5));
    expect(find.byType(HomeTab), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  // WeChat-style tab paging: the pages live in a horizontal PageView and the
  // bottom bar follows whichever page the user swipes to.
  Future<void> pumpShell(WidgetTester tester, AppStore store) async {
    await tester.pumpWidget(RestaurantApp(store: store));
    await tester.pumpAndSettle();
  }

  double pagerPage(WidgetTester tester) =>
      tester.widget<PageView>(find.byType(PageView)).controller!.page!;

  int selectedTab(WidgetTester tester) =>
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex;

  Finder navLabel(String label) => find.descendant(
    of: find.byType(NavigationBar),
    matching: find.text(label),
  );

  Future<void> swipe(WidgetTester tester, Offset offset, {PointerDeviceKind kind = PointerDeviceKind.touch}) async {
    await tester.drag(find.byType(PageView), offset, kind: kind);
    await tester.pumpAndSettle();
  }

  testWidgets('shell: swiping switches tabs and the bottom bar follows', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final store = AppStore(await SharedPreferences.getInstance());
    await store.initialize(seedJson: seedJson);
    await store.login();
    await pumpShell(tester, store);
    expect(find.byType(HomeTab), findsOneWidget);
    expect(selectedTab(tester), 0);

    // Swipe left: home -> menu.
    await swipe(tester, const Offset(-400, 0));
    expect(find.byType(MenuTab), findsOneWidget);
    expect(selectedTab(tester), 1);
    expect(pagerPage(tester), 1.0);

    // Swipe left again: menu -> cart.
    await swipe(tester, const Offset(-400, 0));
    expect(find.byType(CartTab), findsOneWidget);
    expect(selectedTab(tester), 2);
    expect(pagerPage(tester), 2.0);

    // Swipe right: cart -> menu, back the way we came.
    await swipe(tester, const Offset(400, 0));
    expect(find.byType(MenuTab), findsOneWidget);
    expect(selectedTab(tester), 1);
    expect(pagerPage(tester), 1.0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shell: a mouse drag also swipes on web and desktop', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final store = AppStore(await SharedPreferences.getInstance());
    await store.initialize(seedJson: seedJson);
    await store.login();
    await pumpShell(tester, store);

    await swipe(tester, const Offset(-400, 0), kind: PointerDeviceKind.mouse);
    expect(find.byType(MenuTab), findsOneWidget);
    expect(selectedTab(tester), 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shell: tapping a destination moves the pager to that page', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final store = AppStore(await SharedPreferences.getInstance());
    await store.initialize(seedJson: seedJson);
    await store.login();
    await pumpShell(tester, store);

    await tester.tap(navLabel('我的'));
    await tester.pumpAndSettle();
    expect(find.byType(ProfileTab), findsOneWidget);
    expect(selectedTab(tester), 4);
    expect(pagerPage(tester), 4.0);

    // Jumping backwards over several pages works too.
    await tester.tap(navLabel('首页'));
    await tester.pumpAndSettle();
    expect(find.byType(HomeTab), findsOneWidget);
    expect(selectedTab(tester), 0);
    expect(pagerPage(tester), 0.0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shell: in-page navigation keeps the pager on its own page', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final store = AppStore(await SharedPreferences.getInstance());
    await store.initialize(seedJson: seedJson);
    await store.login();
    await pumpShell(tester, store);

    // A home category tile opens the menu tab, and the menu's category list
    // scrolls to the tapped category while the pager stays on the menu page.
    // Read the Scrollable's own state: Scrollable.of() on that element resolves
    // to the enclosing pager, which would measure the wrong thing.
    final last = store.categories.last.name;
    ScrollableState dishList() => tester.state<ScrollableState>(
      find
          .descendant(of: find.byType(MenuTab), matching: find.byType(Scrollable))
          .last,
    );

    await tester.tap(find.text(last));
    await tester.pumpAndSettle();
    expect(find.byType(MenuTab), findsOneWidget);
    expect(selectedTab(tester), 1);
    expect(pagerPage(tester), 1.0);
    expect(
      dishList().position.pixels,
      greaterThan(0.0),
      reason: 'the menu should have scrolled to the tapped category',
    );

    // Coming back and tapping the same category again works too.
    await tester.tap(navLabel('首页'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(last));
    await tester.pumpAndSettle();
    expect(find.byType(MenuTab), findsOneWidget);
    expect(pagerPage(tester), 1.0);
    expect(dishList().position.pixels, greaterThan(0.0));
    expect(tester.takeException(), isNull);
  });

  // Swiping away while the menu is still animating its category jump tears the
  // page down mid-flight; that must not throw.
  testWidgets('shell: swiping away during the category jump is safe', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final store = AppStore(await SharedPreferences.getInstance());
    await store.initialize(seedJson: seedJson);
    await store.login();
    await pumpShell(tester, store);

    // Open the menu and tap a far category so its scroll animation is running.
    await tester.tap(navLabel('点餐'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(store.categories[1].name).first);
    await tester.pump(const Duration(milliseconds: 80));

    // Swipe to another page before the 300ms jump finishes.
    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    await tester.pumpAndSettle();
    expect(find.byType(MenuTab), findsNothing);
    expect(tester.takeException(), isNull);

    // And the tab is still usable when we come back.
    await tester.drag(find.byType(PageView), const Offset(400, 0));
    await tester.pumpAndSettle();
    expect(find.byType(MenuTab), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // A swipe can interrupt the animation started by tapping a destination. The
  // bottom-bar highlight must then follow the page the pager actually settled
  // on, instead of staying on the abandoned destination.
  testWidgets('shell: a swipe during a tap animation keeps the bar in sync', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final store = AppStore(await SharedPreferences.getInstance());
    await store.initialize(seedJson: seedJson);
    await store.login();
    await pumpShell(tester, store);

    // Tap the last tab, then drag back to the first page before it arrives.
    await tester.tap(navLabel('我的'));
    await tester.pump(const Duration(milliseconds: 60));
    await tester.drag(find.byType(PageView), const Offset(400, 0));
    await tester.pumpAndSettle();
    expect(pagerPage(tester).round(), selectedTab(tester));
    expect(find.byType(HomeTab), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Two quick taps must also settle consistently.
    await tester.tap(navLabel('我的'));
    await tester.pump(const Duration(milliseconds: 40));
    await tester.tap(navLabel('购物车'));
    await tester.pumpAndSettle();
    expect(pagerPage(tester).round(), selectedTab(tester));
    expect(find.byType(CartTab), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // Guards the bundled asset set itself. The tests above inject seedJson from
  // disk, so they cannot catch an asset that pubspec declares but the build
  // never emits (which breaks `assets/menu.json` at runtime on Web).
  testWidgets('bundled assets load through rootBundle', (tester) async {
    await tester.runAsync(() async {
      final raw = await rootBundle.loadString('assets/menu.json');
      final parsed = jsonDecode(raw) as Map<String, dynamic>;
      expect(parsed['categories'], isA<List<dynamic>>());
      expect((parsed['dishes'] as List<dynamic>), hasLength(16));
      expect(raw, seedJson);
      // Key UI icons and the CJK font must be bundled too.
      for (final asset in <String>[
        'assets/icons/tab-home.png',
        'assets/icons/dish-placeholder.png',
        'assets/fonts/NotoSansCJKsc-Regular.otf',
      ]) {
        expect((await rootBundle.load(asset)).lengthInBytes, greaterThan(0), reason: asset);
      }
      // Every dish image referenced by the seed data must be bundled.
      for (final dish in parsed['dishes'] as List<dynamic>) {
        final img = (dish as Map<String, dynamic>)['img'] as String;
        await rootBundle.load('assets/seed/dishes/$img.jpg');
      }
    });
  });
  // The fly-to-cart ball: tapping add on the menu spawns an overlay ball that
  // arcs to the cart icon, which pulses on landing.
  testWidgets('adding a dish launches the fly-to-cart ball', (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final store = AppStore(await SharedPreferences.getInstance());
    await store.initialize(seedJson: seedJson);
    await store.login();
    await tester.pumpWidget(RestaurantApp(store: store));
    await tester.pumpAndSettle();
    await tester.tap(find.text('全部菜品'));
    await tester.pumpAndSettle();
    final stepper = find.byType(QuantityStepper).first;
    await tester.tap(
      find.descendant(of: stepper, matching: find.byIcon(Icons.add)),
    );
    // Advance to mid-flight instead of settling so the ball is still visible.
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byKey(flyBallKey), findsOneWidget,
        reason: 'a fly ball should be mid-flight in the overlay');
    // Let the flight finish: the entry must remove itself without errors.
    await tester.pumpAndSettle();
    expect(find.byKey(flyBallKey), findsNothing);
    expect(tester.takeException(), isNull);
    expect(store.cartCount, 1);
    // A second add (1 -> 2) must NOT fly a ball.
    await tester.tap(
      find.descendant(of: stepper, matching: find.byIcon(Icons.add)),
    );
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byKey(flyBallKey), findsNothing,
        reason: 'only the first add should fly a ball');
    await tester.pumpAndSettle();
    expect(store.cartCount, 2);
  });
  // The detail page adds from inside the price card, under the 月售 line, and
  // hands that slot to the shared stepper while a quantity is in the cart.
  testWidgets('detail add flies a ball only on the first add', (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final store = AppStore(await SharedPreferences.getInstance());
    await store.initialize(seedJson: seedJson);
    await store.login();
    await tester.pumpWidget(RestaurantApp(store: store));
    await tester.pumpAndSettle();
    // Enter through the home page's "去看看" so the dish is guaranteed to be a
    // featured one, which is what renders the 招牌推荐 tag.
    await tester.tap(find.text('去看看'));
    await tester.pumpAndSettle();
    final detail = find.byType(DishScreen);
    final add = find.descendant(of: detail, matching: find.text('加入购物车'));
    final stepper = find.descendant(
      of: detail,
      matching: find.byType(QuantityStepper),
    );
    expect(add, findsOneWidget);
    expect(stepper, findsNothing);
    // It really lives under the 月售 line, sharing its right edge — not down
    // in the bottom bar any more. Measure the button itself, not its label,
    // which is inset by the button's own padding.
    final addButton = find.ancestor(of: add, matching: find.byType(FilledButton));
    final sales = find.descendant(
      of: detail,
      matching: find.textContaining('月售'),
    );
    final rightEdge = tester.getRect(addButton).right;
    expect(
      tester.getRect(addButton).top,
      greaterThan(tester.getRect(sales).bottom),
      reason: 'the add button must sit below the 月售 line',
    );
    expect(
      rightEdge,
      tester.getRect(sales).right,
      reason: 'the add button must share the 月售 line\'s right edge',
    );
    // The 招牌推荐 tag and the add button share one line, tag left and button
    // right, instead of stacking into two rows.
    final tag = find.descendant(of: detail, matching: find.text('招牌推荐'));
    expect(tag, findsOneWidget);
    expect(
      tester.getRect(tag).center.dy,
      closeTo(tester.getRect(addButton).center.dy, 1),
      reason: 'the 招牌推荐 tag and the add button must sit on the same line',
    );
    expect(
      tester.getRect(tag).right,
      lessThan(tester.getRect(addButton).left),
      reason: 'the tag must stay clear of the button on its left',
    );
    await tester.tap(add);
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byKey(flyBallKey), findsOneWidget,
        reason: 'the first add on the detail page should fly a ball');
    await tester.pumpAndSettle();
    expect(store.cartCount, 1);
    // The button gives its own slot to the stepper, which shows the quantity
    // and keeps the same right edge, so the card doesn't jump on swap.
    expect(add, findsNothing);
    expect(stepper, findsOneWidget);
    expect(tester.getRect(stepper).right, rightEdge,
        reason: 'the stepper must take over the button without shifting it');
    expect(
      find.descendant(of: stepper, matching: find.text('1')),
      findsOneWidget,
    );
    // Second add goes through the stepper and must not fly a ball.
    await tester.tap(
      find.descendant(of: stepper, matching: find.byIcon(Icons.add)),
    );
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byKey(flyBallKey), findsNothing,
        reason: 'later adds on the detail page should not fly a ball');
    await tester.pumpAndSettle();
    expect(store.cartCount, 2);
    // Reducing back to zero brings the button and the stepper's number away.
    for (var i = 0; i < 2; i++) {
      await tester.tap(
        find.descendant(of: stepper, matching: find.byIcon(Icons.remove)),
      );
      await tester.pumpAndSettle();
    }
    expect(store.cartCount, 0);
    expect(stepper, findsNothing);
    expect(add, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // The detail page's cart icon must reveal the selected dishes in a sheet
  // rising from the bottom, without ever leaving the page.
  testWidgets('detail cart icon opens a cart sheet instead of the cart tab', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final store = AppStore(await SharedPreferences.getInstance());
    await store.initialize(seedJson: seedJson);
    await store.login();
    await tester.pumpWidget(RestaurantApp(store: store));
    await tester.pumpAndSettle();
    await tester.tap(find.text('去看看'));
    await tester.pumpAndSettle();
    final cartIcon = find.byTooltip('查看购物车');
    // Empty cart: a sheet with an empty state, not the cart page.
    await tester.tap(cartIcon);
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('购物车还是空的'), findsOneWidget);
    expect(find.text('提交订单'), findsNothing);
    expect(find.byType(DishScreen), findsOneWidget);
    // "去点餐" closes the sheet, leaves the detail page and lands on the
    // 点餐 tab, which is what the button promises.
    await tester.tap(find.text('去点餐'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.byType(DishScreen), findsNothing);
    // Pin the tab by what only the menu page has: dish tiles, and no 本店分类
    // card. ('全部菜品' is useless here — it is the home page's own "see all"
    // link, not a menu label.)
    expect(find.byType(DishListTile), findsWidgets);
    expect(find.text('本店分类'), findsNothing);
    // Back to the home page and in again, this time with a dish in the cart.
    await tester.tap(find.text('首页'));
    await tester.pumpAndSettle();
    expect(find.text('本店分类'), findsOneWidget);
    await tester.tap(find.text('去看看'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('加入购物车'));
    await tester.pumpAndSettle();
    expect(store.cartCount, 1);
    await tester.tap(cartIcon);
    await tester.pumpAndSettle();
    final sheet = find.byType(BottomSheet);
    expect(sheet, findsOneWidget);
    expect(find.descendant(of: sheet, matching: find.text('已选菜品')), findsOneWidget);
    expect(find.descendant(of: sheet, matching: find.text('清空')), findsOneWidget);
    expect(
      find.descendant(of: sheet, matching: find.text('去结算')),
      findsOneWidget,
    );
    final sheetStepper = find.descendant(
      of: sheet,
      matching: find.byType(QuantityStepper),
    );
    expect(sheetStepper, findsOneWidget);
    await tester.tap(
      find.descendant(of: sheetStepper, matching: find.byIcon(Icons.add)),
    );
    await tester.pumpAndSettle();
    expect(store.cartCount, 2);
    // The sheet stays open and follows the live cart.
    expect(sheet, findsOneWidget);
    // "去结算" drops the sheet and the detail page and lands on the cart tab.
    await tester.tap(find.descendant(of: sheet, matching: find.text('去结算')));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.byType(DishScreen), findsNothing);
    expect(find.text('提交订单'), findsOneWidget);
    expect(store.cartCount, 2);
    expect(tester.takeException(), isNull);
  });

  // Clearing from inside the sheet empties the cart and drops the sheet, so
  // the user lands back on the dish they were reading. The cart tab, which
  // shares the same list, has nothing to close and must keep working.
  testWidgets('clearing the cart inside the sheet closes the sheet', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final store = AppStore(await SharedPreferences.getInstance());
    await store.initialize(seedJson: seedJson);
    await store.login();
    await tester.pumpWidget(RestaurantApp(store: store));
    await tester.pumpAndSettle();
    await tester.tap(find.text('去看看'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('加入购物车'));
    await tester.pumpAndSettle();
    expect(store.cartCount, 1);
    await tester.tap(find.byTooltip('查看购物车'));
    await tester.pumpAndSettle();
    final sheet = find.byType(BottomSheet);
    expect(sheet, findsOneWidget);
    await tester.tap(find.descendant(of: sheet, matching: find.text('清空')));
    await tester.pumpAndSettle();
    // Still a two-step delete: the confirm dialog has to be accepted first.
    expect(find.text('确定'), findsOneWidget);
    expect(store.cartCount, 1);
    await tester.tap(find.text('确定'));
    // The sheet is already on its way out, so the cart change behind it must
    // not repaint the exit animation into an empty state.
    await tester.pump();
    expect(find.text('已选菜品'), findsOneWidget);
    expect(find.text('购物车还是空的'), findsNothing);
    await tester.pumpAndSettle();
    expect(store.cartCount, 0);
    expect(sheet, findsNothing);
    expect(find.byType(DishScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // Dismissing the sheet by hand is the one path that must leave everything
  // where it was: no page pop, no cart change.
  testWidgets('dismissing the cart sheet keeps the detail page and cart', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final store = AppStore(await SharedPreferences.getInstance());
    await store.initialize(seedJson: seedJson);
    await store.login();
    await tester.pumpWidget(RestaurantApp(store: store));
    await tester.pumpAndSettle();
    await tester.tap(find.text('去看看'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('加入购物车'));
    await tester.pumpAndSettle();
    expect(store.cartCount, 1);
    await tester.tap(find.byTooltip('查看购物车'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    // Swipe the sheet away on the scrim instead of using a button.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.byType(DishScreen), findsOneWidget);
    expect(find.text('提交订单'), findsNothing);
    expect(store.cartCount, 1);
    expect(tester.takeException(), isNull);
  });

  // The add button only says "已加入购物车" when perform reports success, so
  // that verdict has to be trustworthy. The app has no seam to make a real save
  // fail in a test, so the contract itself is tested here.
  testWidgets('perform tells the caller whether the work succeeded', (
    tester,
  ) async {
    String? verdict;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                final bad = await perform(
                  context,
                  () async => throw StateError('boom'),
                );
                final good = await perform(context, () async {});
                verdict = '$bad/$good';
              },
              child: const Text('go'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(verdict, 'false/true');
    // The failure was surfaced, not swallowed silently. StateError prints as
    // "Bad state: boom" and perform's prefix strip only handles single words.
    expect(find.textContaining('boom'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // The menu's settlement row is the page's own cart icon: tapping it opens the
  // cart as a sheet over the list (rather than jumping to the cart tab), and it
  // registers as a prioritised fly-to-cart landing spot.
  testWidgets('menu settlement row: cart icon opens a sheet and is the fly target', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final store = AppStore(await SharedPreferences.getInstance());
    await store.initialize(seedJson: seedJson);
    await store.login();
    await pumpShell(tester, store);

    // Go to the 点餐 tab and reach the settlement row through the menu.
    await tester.tap(navLabel('点餐'));
    await tester.pumpAndSettle();
    expect(find.byType(MenuTab), findsOneWidget);

    // The settlement row registers a prioritised CartTarget, while the bottom
    // bar icons stay non-prioritised, so balls land on the visible row.
    final menuTargets = tester
        .widgetList<CartTarget>(
          find.descendant(of: find.byType(MenuTab), matching: find.byType(CartTarget)),
        )
        .toList();
    expect(menuTargets.any((t) => t.priority), isTrue,
        reason: 'the settlement row should be a priority fly target');
    final barTargets = tester
        .widgetList<CartTarget>(
          find.descendant(of: find.byType(NavigationBar), matching: find.byType(CartTarget)),
        )
        .toList();
    expect(barTargets.every((t) => !t.priority), isTrue,
        reason: 'the bottom bar should never out-prioritise the row');

    // Tapping the cart icon reveals the cart sheet without leaving the menu.
    await tester.tap(
      find.descendant(
        of: find.byType(MenuTab),
        matching: find.byIcon(Icons.shopping_bag_outlined),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('购物车还是空的'), findsOneWidget);
    expect(find.byType(MenuTab), findsOneWidget);
    expect(pagerPage(tester), 1.0);

    // The empty sheet's 去点餐 closes it and keeps the user on the menu tab.
    await tester.tap(find.text('去点餐'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.byType(MenuTab), findsOneWidget);
    expect(pagerPage(tester), 1.0);
    expect(tester.takeException(), isNull);
  });
}
