import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/app_store.dart';
import '../models/models.dart';

const ink = Color(0xFF211E1A);
const accent = Color(0xFFB4531F);
const paper = Color(0xFFF7F5F0);
const muted = Color(0xFF8A8478);
const wash = Color(0xFFF1EDE5);
const line = Color(0xFFECE7DD);

void toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

/// Runs [work], turning any failure into a toast. Tells the caller whether it
/// succeeded, so a promise like "已加入购物车" is only made once it is true.
Future<bool> perform(
  BuildContext context,
  Future<void> Function() work,
) async {
  try {
    await work();
    return true;
  } catch (e) {
    if (context.mounted) {
      toast(
        context,
        e.toString().replaceFirst(RegExp(r'^\w+(Exception|Error)?:\s*'), ''),
      );
    }
    return false;
  }
}

Future<bool> confirm(
  BuildContext context,
  String title,
  String message,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确定'),
          ),
        ],
      ),
    ) ??
    false;

class FoodImage extends StatelessWidget {
  final String source;
  final double? width, height;
  final double radius;
  const FoodImage(
    this.source, {
    super.key,
    this.width,
    this.height,
    this.radius = 8,
  });
  @override
  Widget build(BuildContext context) {
    final fallback = Image.asset(
      'assets/icons/dish-placeholder.png',
      width: width,
      height: height,
      fit: BoxFit.cover,
    );
    Widget picture;
    try {
      picture = source.startsWith('data:')
          ? Image.memory(
              base64Decode(source.split(',').last),
              width: width,
              height: height,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => fallback,
            )
          : Image.asset(
              source.isEmpty ? 'assets/icons/dish-placeholder.png' : source,
              width: width,
              height: height,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => fallback,
            );
    } catch (_) {
      picture = fallback;
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: picture,
    );
  }
}

class Section extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const Section({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
    child: Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: Padding(padding: padding, child: child),
    ),
  );
}

class SectionTitle extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onTap;
  const SectionTitle(this.title, {super.key, this.action, this.onTap});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
        ),
        if (action != null)
          InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Text(
                action!,
                style: const TextStyle(color: muted, fontSize: 12),
              ),
            ),
          ),
      ],
    ),
  );
}

class Price extends StatelessWidget {
  final int cents;
  final double size;
  const Price(this.cents, {super.key, this.size = 20});
  @override
  Widget build(BuildContext context) => Text(
    '¥${money(cents)}',
    style: TextStyle(
      color: accent,
      fontSize: size,
      fontWeight: FontWeight.w600,
    ),
  );
}

/// The live cart bar: total, portion count and the action that moves the user
/// on. Used by the menu tab, the cart tab and the bottom of the cart sheet.
/// When [onIconTap] is set the leading cart icon becomes a button that reveals
/// the cart (the menu list opens it as a sheet); when [target] is set the icon
/// also registers as a priority fly-to-cart landing spot for this screen.
class CartSummary extends StatelessWidget {
  final AppStore store;
  final String label;
  final VoidCallback? onTap;
  final VoidCallback? onIconTap;
  final bool target;
  const CartSummary({
    super.key,
    required this.store,
    required this.label,
    required this.onTap,
    this.onIconTap,
    this.target = false,
  });
  @override
  Widget build(BuildContext context) {
    Widget icon = const Icon(Icons.shopping_bag_outlined, color: accent);
    if (target) icon = CartTarget(priority: true, child: icon);
    if (onIconTap != null) {
      icon = Semantics(
        button: true,
        label: '查看购物车',
        child: InkWell(
          onTap: onIconTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(padding: const EdgeInsets.all(4), child: icon),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      color: Colors.white,
      child: Row(
        children: [
          icon,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Price(store.cartTotal),
                Text(
                  '已选 ${store.cartCount} 份',
                  style: const TextStyle(color: muted, fontSize: 11),
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: store.cartCount > 0 ? onTap : null,
            child: Text(label),
          ),
        ],
      ),
    );
  }
}

/// Registered cart icons, innermost (most recently mounted) first used.
/// The shell's bottom-bar icon registers at startup; the menu settlement row
/// and the dish detail page register prioritised icons while visible, so balls
/// fly to the cart icon the user is actually looking at.
final List<CartTargetState> _cartTargets = [];

/// Picks where a fly ball lands: the most recently mounted cart icon that is
/// genuinely on screen. A [CartTarget.priority] icon (the settlement row on the
/// menu, the detail page) wins over the always-on bottom navigation bar, which
/// is only used as a fallback when no prioritised icon is visible. Pages the
/// pager has scrolled off-screen report a centre outside the viewport, so they
/// are skipped rather than stealing a ball from the tab the user is on.
CartTargetState? _visibleCartTarget(Size screen) {
  CartTargetState? fallback;
  for (final target in _cartTargets.reversed) {
    if (!target.mounted) continue;
    final box = target.context.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || !box.hasSize) continue;
    final center = box.localToGlobal(box.size.center(Offset.zero));
    final onScreen =
        center.dx >= 0 &&
        center.dy >= 0 &&
        center.dx <= screen.width &&
        center.dy <= screen.height;
    if (!onScreen) continue;
    if (target.priority) return target;
    fallback ??= target;
  }
  return fallback;
}

/// Plays the mini-program style fly-to-cart animation: a small ball leaves
/// [start] (global coordinates), follows a quadratic Bezier arc that peaks
/// above both endpoints, and lands on the visible cart icon, which then
/// pulses. Safe no-op when no cart icon is currently mounted.
void flyToCart(BuildContext context, Offset start) {
  final target = _visibleCartTarget(MediaQuery.sizeOf(context));
  if (target == null) return;
  final box = target.context.findRenderObject() as RenderBox?;
  if (box == null || !box.attached || !box.hasSize) return;
  final overlay =
      Overlay.maybeOf(context, rootOverlay: true) ?? Overlay.of(context);
  final end = box.localToGlobal(box.size.center(Offset.zero));
  OverlayEntry? entry;
  entry = OverlayEntry(
    builder: (_) => _FlyBall(
      start: start,
      end: end,
      onLanded: target.bounce,
      onFinished: () => entry?.remove(),
    ),
  );
  overlay.insert(entry);
}

/// Key on the in-flight fly ball, so tests can assert the animation exists.
final GlobalKey flyBallKey = GlobalKey();

/// Wraps a cart icon so it can pulse when a fly-to-cart ball lands on it.
class CartTarget extends StatefulWidget {
  final Widget child;
  final bool priority;
  const CartTarget({
    super.key,
    required this.child,
    this.priority = false,
  });
  @override
  State<CartTarget> createState() => CartTargetState();
}

class CartTargetState extends State<CartTarget>
    with SingleTickerProviderStateMixin {
  /// Whether a visible fly ball should prefer this icon over the bottom bar.
  bool get priority => widget.priority;

  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );
  late final Animation<double> scale = Tween<double>(
    begin: 1,
    end: 1.3,
  ).animate(CurvedAnimation(parent: controller, curve: Curves.easeOutBack));

  @override
  void initState() {
    super.initState();
    _cartTargets.add(this);
  }

  @override
  void dispose() {
    _cartTargets.remove(this);
    controller.dispose();
    super.dispose();
  }

  void bounce() {
    if (!mounted) return;
    controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) =>
      ScaleTransition(scale: scale, child: widget.child);
}

class _FlyBall extends StatefulWidget {
  final Offset start, end;
  final VoidCallback onLanded, onFinished;
  const _FlyBall({
    required this.start,
    required this.end,
    required this.onLanded,
    required this.onFinished,
  });
  @override
  State<_FlyBall> createState() => _FlyBallState();
}

class _FlyBallState extends State<_FlyBall>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );

  @override
  void initState() {
    super.initState();
    controller.addStatusListener((status) {
      if (status != AnimationStatus.completed) return;
      widget.onLanded();
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onFinished());
    });
    controller.forward();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  /// Quadratic Bezier through an apex raised above both endpoints.
  Offset point(double t) {
    final a = widget.start;
    final b = widget.end;
    final c = Offset((a.dx + b.dx) / 2, math.min(a.dy, b.dy) - 100);
    final u = 1 - t;
    return Offset(
      a.dx * u * u + c.dx * 2 * u * t + b.dx * t * t,
      a.dy * u * u + c.dy * 2 * u * t + b.dy * t * t,
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final t = Curves.easeInOut.transform(controller.value);
      final position = point(t);
      final size = 18.0 * (1 - 0.4 * t);
      return Positioned(
        key: flyBallKey,
        left: position.dx - size / 2,
        top: position.dy - size / 2,
        child: IgnorePointer(
          child: Container(
            width: size,
            height: size,
            decoration: const BoxDecoration(
              color: accent,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Color(0x33B4531F), blurRadius: 6)],
            ),
          ),
        ),
      );
    },
  );
}

class QuantityStepper extends StatelessWidget {
  final AppStore store;
  final String dishId;
  final bool fly;
  const QuantityStepper(this.store, this.dishId, {super.key, this.fly = true});
  @override
  Widget build(BuildContext context) {
    final n = store.quantity(dishId);
    Widget button(
      IconData icon,
      String label,
      VoidCallback onTap, {
      bool filled = false,
    }) => Semantics(
      button: true,
      label: label,
      child: InkResponse(
        onTap: onTap,
        radius: 22,
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? accent : Colors.white,
            border: Border.all(color: filled ? accent : line),
          ),
          child: Icon(icon, size: 18, color: filled ? Colors.white : muted),
        ),
      ),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (n > 0) ...[
          button(
            Icons.remove,
            '减少${store.dish(dishId)?.name ?? ''}',
            () => perform(context, () => store.setQuantity(dishId, n - 1)),
          ),
          SizedBox(width: 30, child: Text('$n', textAlign: TextAlign.center)),
        ],
        button(
          Icons.add,
          '添加${store.dish(dishId)?.name ?? ''}',
          () {
            // Only the first add (0 -> 1) flies the ball into the cart.
            if (fly && n == 0) {
              final box = context.findRenderObject() as RenderBox?;
              if (box != null && box.hasSize) {
                flyToCart(
                  context,
                  box.localToGlobal(box.size.center(Offset.zero)),
                );
              }
            }
            perform(context, () => store.setQuantity(dishId, n + 1));
          },
          filled: true,
        ),
      ],
    );
  }
}

class EmptyView extends StatelessWidget {
  final String text;
  final VoidCallback? onMenu;
  const EmptyView(this.text, {super.key, this.onMenu});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset('assets/icons/empty.png', width: 110, height: 110),
          const SizedBox(height: 16),
          Text(text, style: const TextStyle(color: muted)),
          if (onMenu != null)
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: FilledButton(onPressed: onMenu, child: const Text('去点餐')),
            ),
        ],
      ),
    ),
  );
}

String dateLabel(DateTime time) =>
    '${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
Color statusColor(OrderStatus status) => switch (status) {
  OrderStatus.pending => accent,
  OrderStatus.completed => const Color(0xFF4E7A58),
  OrderStatus.cancelled => muted,
};
