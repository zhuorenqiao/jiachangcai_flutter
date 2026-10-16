import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/app_store.dart';
import '../models/models.dart';
import '../widgets/cart_sheet.dart';
import '../widgets/common.dart';
import 'dish_screen.dart';
import 'order_screens.dart';
import 'admin_screens.dart';

class RestaurantShell extends StatefulWidget {
  final AppStore store;
  const RestaurantShell({super.key, required this.store});
  @override
  State<RestaurantShell> createState() => _RestaurantShellState();
}

/// Lets the tab pager accept mouse and trackpad drags on top of the default
/// touch-like devices, so the WeChat-style swipe also works with a mouse on Web
/// and desktop. Scoped to the pager only: vertical lists and text selection in
/// the pages keep the platform-default device set.
class _PagerScrollBehavior extends MaterialScrollBehavior {
  const _PagerScrollBehavior();
  @override
  Set<PointerDeviceKind> get dragDevices => const {
    PointerDeviceKind.touch,
    PointerDeviceKind.stylus,
    PointerDeviceKind.invertedStylus,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.mouse,
    PointerDeviceKind.unknown,
  };
}

/// One swipeable tab: a title bar plus the tab body, both travelling with the
/// page. The bar lives inside the page (instead of [Scaffold.appBar]) so every
/// page fills the pager viewport exactly; otherwise the bar would appear halfway
/// through a swipe and change the viewport height under the moving content.
class _TabPage extends StatelessWidget {
  final String title;
  final Widget child;
  const _TabPage({required this.title, required this.child});
  @override
  Widget build(BuildContext context) =>
      Column(children: [AppBar(title: Text(title)), Expanded(child: child)]);
}

class _RestaurantShellState extends State<RestaurantShell> {
  static const _swipe = Duration(milliseconds: 280);
  int tab = 0;
  String? categoryId;

  final page = PageController();

  /// Non-null while a tap-driven page animation runs. The nav highlight is then
  /// already on the target, so page changes reported mid-animation are ignored
  /// (they would flick it back through the intermediate pages).
  int? animatingTo;

  @override
  void dispose() {
    page.dispose();
    super.dispose();
  }

  Future<void> _animateTo(int value) async {
    if (!page.hasClients) return;
    animatingTo = value;
    try {
      await page.animateToPage(value, duration: _swipe, curve: Curves.easeOutCubic);
    } catch (_) {
      // Navigation must never surface an error: a swiped or disposed pager can
      // cancel the animation and complete it with an error.
    } finally {
      // A newer tap may have retargeted the pager; only the latest call settles.
      if (animatingTo == value) {
        animatingTo = null;
        // Reconcile with where the pager actually ended up. A user swipe can
        // interrupt this animation and settle on another page, and the
        // suppression above would otherwise leave the nav highlight on the
        // abandoned target.
        final settled = page.hasClients ? page.page?.round() : null;
        if (mounted && settled != null && settled != tab) {
          setState(() => tab = settled);
        }
      }
    }
  }

  void goTab(int value, {String? category}) {
    if (value == tab && category == categoryId) return;
    setState(() {
      tab = value;
      categoryId = category;
    });
    if (page.hasClients && page.page?.round() != value) _animateTo(value);
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final pages = <Widget>[
      HomeTab(
        store: store,
        onMenu: (id) => goTab(1, category: id),
        onCart: () => goTab(2),
      ),
      _TabPage(
        title: '点餐',
        child: MenuTab(
          store: store,
          initialCategory: categoryId,
          onCart: () => goTab(2),
        ),
      ),
      _TabPage(
        title: '购物车',
        child: CartTab(
          store: store,
          onMenu: () => goTab(1),
          onOrders: () => goTab(3),
        ),
      ),
      _TabPage(
        title: '订单',
        child: OrdersTab(
          store: store,
          onMenu: () => goTab(1),
          onCart: () => goTab(2),
        ),
      ),
      _TabPage(
        title: '我的',
        child: ProfileTab(store: store, onOrders: () => goTab(3)),
      ),
    ];
    const labels = ['首页', '点餐', '购物车', '订单', '我的'];
    const icons = ['home', 'menu', 'cart', 'orders', 'profile'];
    return Scaffold(
      body: SafeArea(
        child: PageView(
          controller: page,
          scrollBehavior: const _PagerScrollBehavior(),
          onPageChanged: (value) {
            if (animatingTo == null && value != tab) setState(() => tab = value);
          },
          children: pages,
        ),
      ),
      bottomNavigationBar: NavigationBar(
        height: 68,
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFF6EDE3),
        selectedIndex: tab,
        onDestinationSelected: goTab,
        destinations: [
          for (int i = 0; i < labels.length; i++)
            NavigationDestination(
              label: labels[i],
              icon: i == 2
                  ? CartTarget(
                      key: ValueKey('cart-inactive'),
                      child: Badge(
                        isLabelVisible: store.cartCount > 0,
                        label: Text(
                          store.cartCount > 99 ? '99+' : '${store.cartCount}',
                        ),
                        child: Image.asset(
                          'assets/icons/tab-${icons[i]}.png',
                          width: 24,
                          height: 24,
                        ),
                      ),
                    )
                  : Badge(
                      isLabelVisible: false,
                      label: const Text(''),
                      child: Image.asset(
                        'assets/icons/tab-${icons[i]}.png',
                        width: 24,
                        height: 24,
                      ),
                    ),
              selectedIcon: i == 2
                  ? CartTarget(
                      key: ValueKey('cart-active'),
                      child: Badge(
                        isLabelVisible: store.cartCount > 0,
                        label: Text(
                          store.cartCount > 99 ? '99+' : '${store.cartCount}',
                        ),
                        child: Image.asset(
                          'assets/icons/tab-${icons[i]}-active.png',
                          width: 24,
                          height: 24,
                        ),
                      ),
                    )
                  : Badge(
                      isLabelVisible: false,
                      label: const Text(''),
                      child: Image.asset(
                        'assets/icons/tab-${icons[i]}-active.png',
                        width: 24,
                        height: 24,
                      ),
                    ),
            ),
        ],
      ),
    );
  }
}

class HomeTab extends StatelessWidget {
  final AppStore store;
  final void Function(String?) onMenu;
  final VoidCallback onCart;
  const HomeTab({
    super.key,
    required this.store,
    required this.onMenu,
    required this.onCart,
  });
  @override
  Widget build(BuildContext context) {
    final featured = store.availableDishes.where((d) => d.featured).toList();
    final top = featured.firstOrNull;
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.white,
                    child: Image.asset(
                      'assets/icons/avatar-default.png',
                      width: 46,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '家常菜餐厅',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 3,
                          ),
                        ),
                        SizedBox(height: 5),
                        Text(
                          '现炒家常菜 · 好吃不贵',
                          style: TextStyle(
                            fontSize: 11,
                            color: muted,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  _Info(Icons.schedule, '营业中 09:00–21:00'),
                  _Info(Icons.location_on_outlined, '文华路 88 号（地铁口旁）'),
                ],
              ),
            ],
          ),
        ),
        if (top != null)
          Section(
            padding: EdgeInsets.zero,
            child: InkWell(
              onTap: () => openDish(
                context,
                store,
                top.id,
                onCart,
                onMenu: () => onMenu(top.categoryId),
              ),
              child: Row(
                children: [
                  FoodImage(top.image, width: 120, height: 158, radius: 8),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '今日推荐',
                            style: TextStyle(
                              color: accent,
                              fontSize: 10,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            top.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            top.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: muted, fontSize: 11),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 10,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Price(top.price, size: 18),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: accent,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  '去看看',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        Section(
          child: Column(
            children: [
              SectionTitle('本店分类', action: '全部菜品', onTap: () => onMenu(null)),
              Wrap(
                children: [
                  for (final c in store.categories)
                    SizedBox(
                      width:
                          (MediaQuery.sizeOf(context).width.clamp(0, 700) -
                              56) /
                          5,
                      child: InkWell(
                        onTap: () => onMenu(c.id),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Column(
                            children: [
                              Image.asset(
                                'assets/icons/${c.icon}.png',
                                width: 44,
                                height: 44,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                c.name,
                                maxLines: 2,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        if (featured.length > 1)
          Section(
            child: Column(
              children: [
                SectionTitle('热门推荐', action: '更多', onTap: () => onMenu(null)),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 12,
                    mainAxisExtent: 246,
                  ),
                  itemCount: featured.length - 1,
                  itemBuilder: (context, i) {
                    final d = featured[i + 1];
                    return InkWell(
                      onTap: () => openDish(
                        context,
                        store,
                        d.id,
                        onCart,
                        onMenu: () => onMenu(d.categoryId),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: FoodImage(d.image, height: 132),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            d.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '月售 ${d.sales}',
                            style: const TextStyle(fontSize: 11, color: muted),
                          ),
                          const Spacer(),
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 6,
                            runSpacing: 5,
                            children: [
                              Price(d.price, size: 16),
                              QuantityStepper(store, d.id),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        const Section(
          child: Text(
            '当前为本地模式：菜单与订单数据保存在本机。',
            style: TextStyle(color: muted, fontSize: 11, height: 1.6),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _Info extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Info(this.icon, this.text);
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 14, color: muted),
      const SizedBox(width: 4),
      Text(text, style: const TextStyle(fontSize: 11, color: muted)),
    ],
  );
}

class MenuTab extends StatefulWidget {
  final AppStore store;
  final String? initialCategory;
  final VoidCallback onCart;
  const MenuTab({
    super.key,
    required this.store,
    this.initialCategory,
    required this.onCart,
  });
  @override
  State<MenuTab> createState() => _MenuTabState();
}

class _MenuTabState extends State<MenuTab> {
  final scroll = ScrollController();
  final Map<String, GlobalKey> keys = {};
  String? active;
  bool jumping = false;
  @override
  void initState() {
    super.initState();
    scroll.addListener(syncCategory);
    active = widget.initialCategory ?? widget.store.categories.firstOrNull?.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialCategory != null) jump(widget.initialCategory!);
    });
  }

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  void syncCategory() {
    if (jumping) return;
    String? selected;
    for (final c in widget.store.categories) {
      final box = keys[c.id]?.currentContext?.findRenderObject() as RenderBox?;
      if (box != null && box.localToGlobal(Offset.zero).dy <= 160) {
        selected = c.id;
      }
    }
    if (selected != null && selected != active && mounted) {
      setState(() => active = selected);
    }
  }

  Future<void> jump(String id) async {
    final target = keys[id]?.currentContext;
    if (target == null) return;
    setState(() => active = id);
    jumping = true;
    final object = target.findRenderObject();
    // Scroll this category list's own position. Scrollable.ensureVisible walks
    // every ancestor Scrollable as well, so it would also drag the tab pager.
    if (scroll.hasClients && object != null && object.attached) {
      await scroll.position.ensureVisible(
        object,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
    // Swiping away disposes this page mid-jump.
    if (!mounted) return;
    jumping = false;
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 88,
              child: ColoredBox(
                color: wash,
                child: ListView(
                  children: [
                    for (final c in widget.store.categories)
                      InkWell(
                        onTap: () => jump(c.id),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 20,
                            horizontal: 8,
                          ),
                          decoration: BoxDecoration(
                            color: active == c.id
                                ? Colors.white
                                : Colors.transparent,
                            border: Border(
                              left: BorderSide(
                                color: active == c.id
                                    ? accent
                                    : Colors.transparent,
                                width: 3,
                              ),
                            ),
                          ),
                          child: Text(
                            c.name,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: active == c.id ? ink : muted,
                              fontWeight: active == c.id
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: widget.store.categories.isEmpty
                  ? const EmptyView('暂无分类')
                  // Eager rather than a lazy ListView: jumping to a category
                  // needs that section's GlobalKey to have been built, and a
                  // lazy sliver never inflates sections that are far below the
                  // viewport, so the jump used to silently do nothing for the
                  // categories farthest down the menu.
                  : SingleChildScrollView(
                      controller: scroll,
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 60),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final c in widget.store.categories)
                            Column(
                              key: keys.putIfAbsent(c.id, () => GlobalKey()),
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  child: Text(
                                    c.name,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ),
                                if (!widget.store.availableDishes.any(
                                  (d) => d.categoryId == c.id,
                                ))
                                  const Padding(
                                    padding: EdgeInsets.all(24),
                                    child: Text(
                                      '暂无上架菜品',
                                      style: TextStyle(
                                        color: muted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                for (final d
                                    in widget.store.availableDishes.where(
                                      (d) => d.categoryId == c.id,
                                    ))
                                  DishListTile(
                                    store: widget.store,
                                    dish: d,
                                    onCart: widget.onCart,
                                  ),
                              ],
                            ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
      CartSummary(
        store: widget.store,
        label: '去结算',
        onTap: widget.onCart,
        // The settlement row is this page's cart icon: added dishes fly here
        // rather than to the bottom bar, and tapping it opens the cart as a
        // sheet so the menu stays in view. 去结算 still jumps to the cart tab.
        target: true,
        onIconTap: () async {
          final action = await showCartSheet(context, widget.store);
          if (action == CartSheetAction.checkout && mounted) widget.onCart();
        },
      ),
    ],
  );
}

class DishListTile extends StatelessWidget {
  final AppStore store;
  final Dish dish;
  final VoidCallback onCart;
  const DishListTile({
    super.key,
    required this.store,
    required this.dish,
    required this.onCart,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: InkWell(
      onTap: () => openDish(context, store, dish.id, onCart),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FoodImage(dish.image, width: 68, height: 76),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dish.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dish.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: muted, fontSize: 11),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '月售 ${dish.sales}',
                        style: const TextStyle(color: muted, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: Price(dish.price, size: 17)),
                QuantityStepper(store, dish.id),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class CartTab extends StatefulWidget {
  final AppStore store;
  final VoidCallback onMenu, onOrders;
  const CartTab({
    super.key,
    required this.store,
    required this.onMenu,
    required this.onOrders,
  });
  @override
  State<CartTab> createState() => _CartTabState();
}

class _CartTabState extends State<CartTab> {
  late final TextEditingController remark = TextEditingController(
    text: widget.store.remark,
  );
  @override
  void dispose() {
    remark.dispose();
    super.dispose();
  }

  bool busy = false;
  Future<void> submit() async {
    if (busy) return;
    final yes = await confirm(
      context,
      '确认订单',
      '共 ${widget.store.cartCount} 份菜品，合计 ¥${money(widget.store.cartTotal)}。\n支付方式：餐后到店支付。',
    );
    if (!yes || !mounted) return;
    setState(() => busy = true);
    await perform(context, () async {
      await widget.store.checkout();
      if (mounted) {
        toast(context, '下单成功');
        widget.onOrders();
      }
    });
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    return Column(
      children: [
        if (store.invalidCount > 0)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              '有 ${store.invalidCount} 件菜品已下架或删除，未计入合计',
              style: const TextStyle(color: accent, fontSize: 12),
            ),
          ),
        Expanded(
          child: store.cartItems.isEmpty
              ? EmptyView('购物车还是空的', onMenu: widget.onMenu)
              : ListView(
                  children: [
                    CartDishList(store: store),
                    Section(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SectionTitle('备注'),
                          TextField(
                            controller: remark,
                            maxLength: 100,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              hintText: '口味偏好、忌口等要求（选填）',
                            ),
                            onChanged: (s) =>
                                perform(context, () => store.setRemark(s)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
        ),
        if (store.cartItems.isNotEmpty)
          CartSummary(
            store: store,
            label: busy ? '提交中…' : '提交订单',
            onTap: busy ? null : submit,
          ),
      ],
    );
  }
}

class ProfileTab extends StatelessWidget {
  final AppStore store;
  final VoidCallback onOrders;
  const ProfileTab({super.key, required this.store, required this.onOrders});
  @override
  Widget build(BuildContext context) => ListView(
    children: [
      Section(
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: paper,
              child: Image.asset('assets/icons/avatar-default.png', width: 58),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    store.userName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '本地模式',
                    style: TextStyle(color: muted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      Section(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.receipt_long_outlined),
              title: const Text('我的订单'),
              trailing: Text('${store.orders.length} 单  ›'),
              onTap: onOrders,
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.restaurant_menu),
              title: const Text('菜品管理'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => AdminScreen(store: store),
                ),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.call_outlined),
              title: const Text('联系餐厅'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => showDialog<void>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('联系餐厅'),
                  content: const Text(
                    '订餐热线：0755-6688 6688\n门店地址：文华路 88 号（地铁口旁）\n营业时间：09:00–21:00',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('知道了'),
                    ),
                    FilledButton(
                      onPressed: () async {
                        final ok = await launchUrl(
                          Uri(scheme: 'tel', path: '075566886688'),
                        );
                        if (!ok && context.mounted) {
                          toast(context, '请拨打 0755-6688 6688');
                        }
                      },
                      child: const Text('拨打电话'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.all(24),
        child: OutlinedButton(
          onPressed: () async {
            if (await confirm(
                  context,
                  '退出登录',
                  '退出后可以重新使用本机账号登录，历史订单和购物车会保留。',
                ) &&
                context.mounted) {
              await perform(context, store.logout);
            }
          },
          child: const Text('退出登录'),
        ),
      ),
    ],
  );
}
