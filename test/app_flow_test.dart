import 'dart:convert';
import 'dart:io';

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jiachangcai_flutter/data/app_store.dart';
import 'package:jiachangcai_flutter/main.dart';
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
  // The dish detail page must follow the same rule as the list stepper.
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
    await tester.tap(find.text('全部菜品'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DishListTile).first);
    await tester.pumpAndSettle();
    expect(find.text('加入购物车'), findsOneWidget);
    await tester.tap(find.text('加入购物车'));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byKey(flyBallKey), findsOneWidget,
        reason: 'the first add on the detail page should fly a ball');
    await tester.pumpAndSettle();
    expect(store.cartCount, 1);
    // Second add: no ball.
    await tester.tap(find.text('加入购物车'));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byKey(flyBallKey), findsNothing,
        reason: 'later adds on the detail page should not fly a ball');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(store.cartCount, 2);
  });
}
