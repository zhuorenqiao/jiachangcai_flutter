import 'package:flutter/material.dart';

import '../data/app_store.dart';
import '../models/models.dart';
import '../widgets/cart_sheet.dart';
import '../widgets/common.dart';

Future<void> openDish(
  BuildContext context,
  AppStore store,
  String id,
  VoidCallback onCart, {
  VoidCallback? onMenu,
}) => Navigator.push(
  context,
  MaterialPageRoute<void>(
    builder: (_) => DishScreen(
      store: store,
      id: id,
      onCart: onCart,
      onMenu: onMenu,
    ),
  ),
);

class DishScreen extends StatelessWidget {
  final AppStore store;
  final String id;
  final VoidCallback onCart;
  /// Brings the user to the 点餐 tab. Left null when the menu tab is already
  /// the page underneath, where simply leaving this page gets them there.
  final VoidCallback? onMenu;
  const DishScreen({
    super.key,
    required this.store,
    required this.id,
    required this.onCart,
    this.onMenu,
  });
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) {
      final dish = store.dish(id);
      if (dish == null) {
        return Scaffold(
          appBar: AppBar(title: const Text('菜品详情')),
          body: const EmptyView('菜品不存在或已删除'),
        );
      }
      return Scaffold(
        appBar: AppBar(title: Text(dish.name)),
        body: ListView(
          children: [
            AspectRatio(
              aspectRatio: 1.2,
              child: InkWell(
                onTap: () => showDishZoom(context, dish.image),
                child: FoodImage(dish.image, radius: 0),
              ),
            ),
            Section(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dish.name,
                    style: const TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Price(dish.price, size: 28),
                      const Spacer(),
                      Text(
                        '月售 ${dish.sales}',
                        style: const TextStyle(color: muted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // One line under the 月售 row: 招牌推荐 on the left when the
                  // dish has it, the add action on the right. The fixed height
                  // stops the card from twitching when the 40dp button swaps
                  // for the 30dp stepper.
                  SizedBox(
                    height: 40,
                    child: Row(
                      children: [
                        if (dish.featured)
                          const Text(
                            '招牌推荐',
                            style: TextStyle(color: accent),
                          ),
                        const Spacer(),
                        _DetailAddAction(store: store, dish: dish, id: id),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Section(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionTitle('菜品介绍'),
                  Text(
                    dish.description.isEmpty ? '现点现炒，美味家常菜。' : dish.description,
                    style: const TextStyle(color: muted, height: 1.8),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                IconButton(
                  tooltip: '查看购物车',
                  onPressed: () async {
                    // The cart opens as a sheet over this page instead of
                    // replacing it, so the dish stays in view while the order
                    // is being tweaked. Only after the sheet is gone does the
                    // page itself get left behind.
                    final action = await showCartSheet(context, store);
                    if (action == null || !context.mounted) return;
                    Navigator.pop(context);
                    if (action == CartSheetAction.checkout) {
                      onCart();
                    } else {
                      onMenu?.call();
                    }
                  },
                  icon: CartTarget(
                    child: Badge(
                      label: Text('${store.cartCount}'),
                      isLabelVisible: store.cartCount > 0,
                      child: const Icon(Icons.shopping_bag_outlined),
                    ),
                  ),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: dish.available
                      ? () => perform(context, () async {
                          if (store.quantity(id) == 0) {
                            await store.setQuantity(id, 1);
                          }
                          if (context.mounted) {
                            Navigator.pop(context);
                            onCart();
                          }
                        })
                      : null,
                  child: const Text('立即购买'),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// The detail page's add action, living inside the price card: a button while
/// the dish is not in the cart yet, and the same [QuantityStepper] the menu
/// list uses once it is, so the quantity can go up and down in place.
class _DetailAddAction extends StatelessWidget {
  final AppStore store;
  final Dish dish;
  final String id;
  const _DetailAddAction({
    required this.store,
    required this.dish,
    required this.id,
  });

  @override
  Widget build(BuildContext context) {
    if (!dish.available) {
      return const FilledButton(onPressed: null, child: Text('已下架'));
    }
    if (store.quantity(id) > 0) {
      // The 0 -> 1 flight already happened on the button, so adds from here
      // just change the number.
      return QuantityStepper(store, id, fly: false);
    }
    return Builder(
      builder: (buttonContext) => FilledButton(
        onPressed: () async {
          // Measured up front: once the quantity lands the button is replaced
          // by the stepper, so there is nothing left to measure afterwards.
          final box = buttonContext.findRenderObject() as RenderBox?;
          final start = (box != null && box.hasSize)
              ? box.localToGlobal(box.size.center(Offset.zero))
              : null;
          final ok = await perform(context, () => store.setQuantity(id, 1));
          // Only promise and animate once it actually happened; perform has
          // already toasted the failure.
          if (!ok || !context.mounted) return;
          if (start != null) flyToCart(context, start);
          toast(context, '已加入购物车');
        },
        child: const Text('加入购物车'),
      ),
    );
  }
}

/// Fullscreen photo viewer: black backdrop, pinch-zoom and drag via
/// InteractiveViewer, tap anywhere or the close button to dismiss.
void showDishZoom(BuildContext context, String image) {
  Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      transitionDuration: const Duration(milliseconds: 220),
      reverseTransitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (_, animation, _) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: _PhotoViewer(image: image),
      ),
    ),
  );
}

class _PhotoViewer extends StatefulWidget {
  final String image;
  const _PhotoViewer({required this.image});
  @override
  State<_PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<_PhotoViewer> {
  final transformation = TransformationController();
  TapDownDetails? lastTapDown;

  @override
  void dispose() {
    transformation.dispose();
    super.dispose();
  }

  /// Double-tap toggles between fit and 2.5x zoom centered on the tap point.
  void toggleZoom(TapDownDetails details) {
    final zoomed = transformation.value.getMaxScaleOnAxis() > 1.05;
    setState(() {
      transformation.value = zoomed
          ? Matrix4.identity()
          : Matrix4(
              2.5, 0, 0, 0, //
              0, 2.5, 0, 0,
              0, 0, 1, 0,
              -details.localPosition.dx * 1.5,
              -details.localPosition.dy * 1.5,
              0,
              1,
            );
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: Stack(
      children: [
        GestureDetector(
          onTapDown: (d) => lastTapDown = d,
          onDoubleTapDown: toggleZoom,
          onTap: () => Navigator.pop(context),
          child: InteractiveViewer(
            transformationController: transformation,
            maxScale: 5,
            minScale: 1,
            child: Center(
              child: FoodImage(widget.image, radius: 0),
            ),
          ),
        ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: IconButton(
                  tooltip: '关闭',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white, size: 28),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
