import 'package:flutter/material.dart';

import '../data/app_store.dart';
import '../widgets/common.dart';

Future<void> openDish(
  BuildContext context,
  AppStore store,
  String id,
  VoidCallback onCart,
) => Navigator.push(
  context,
  MaterialPageRoute<void>(
    builder: (_) => DishScreen(store: store, id: id, onCart: onCart),
  ),
);

class DishScreen extends StatelessWidget {
  final AppStore store;
  final String id;
  final VoidCallback onCart;
  const DishScreen({
    super.key,
    required this.store,
    required this.id,
    required this.onCart,
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
                  if (dish.featured)
                    const Padding(
                      padding: EdgeInsets.only(top: 10),
                      child: Text('招牌推荐', style: TextStyle(color: accent)),
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
                  onPressed: () {
                    Navigator.pop(context);
                    onCart();
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
                      ? () async {
                          // Match the list stepper: only the first add
                          // (0 -> 1) flies the ball into the cart.
                          if (store.quantity(id) == 0) {
                            final box =
                                context.findRenderObject() as RenderBox?;
                            if (box != null && box.hasSize) {
                              flyToCart(
                                context,
                                box.localToGlobal(
                                  Offset(
                                    box.size.width - 40,
                                    box.size.height / 2,
                                  ),
                                ),
                              );
                            }
                          }
                          await perform(
                            context,
                            () => store.setQuantity(id, store.quantity(id) + 1),
                          );
                          if (context.mounted) toast(context, '已加入购物车');
                        }
                      : null,
                  child: Text(dish.available ? '加入购物车' : '已下架'),
                ),
                const SizedBox(width: 8),
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
