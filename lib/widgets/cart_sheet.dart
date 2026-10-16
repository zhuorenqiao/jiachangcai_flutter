import 'package:flutter/material.dart';

import '../data/app_store.dart';
import 'common.dart';

/// What the user asked the cart sheet to do once it closed.
enum CartSheetAction { menu, checkout }

/// Reveals the selected dishes in a sheet that rises from the bottom, so the
/// dish being browsed stays on screen. The sheet listens to the store, which
/// makes quantity edits inside it live, and reports back which button the
/// user pressed.
Future<CartSheetAction?> showCartSheet(BuildContext context, AppStore store) =>
    showModalBottomSheet<CartSheetAction>(
      context: context,
      isScrollControlled: true,
      backgroundColor: paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _CartSheet(store: store),
    );

/// The 已选菜品 card: a 清空 header and one row per cart line. Shared by the
/// cart tab and the detail page's cart sheet, so both stay visually in sync.
/// [onCleared] lets a host that can dismiss itself do so once the cart really
/// is empty; the cart tab passes nothing, because there is nothing to close.
class CartDishList extends StatelessWidget {
  final AppStore store;
  final VoidCallback? onCleared;
  const CartDishList({super.key, required this.store, this.onCleared});

  @override
  Widget build(BuildContext context) => Section(
    child: Column(
      children: [
        SectionTitle(
          '已选菜品',
          action: '清空',
          onTap: () async {
            if (await confirm(context, '清空购物车', '确定要清空购物车吗？') &&
                context.mounted) {
              // clearCart empties memory synchronously, so the sheet has
              // nothing worth showing the moment the user confirms: leave
              // first, then persist. Awaiting the write before popping would
              // run the pop against a context the user may have already
              // dismissed along with the sheet.
              onCleared?.call();
              await perform(context, store.clearCart);
            }
          },
        ),
        for (final item in store.cartItems)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                FoodImage(item.image, width: 64, height: 64),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Price(item.price, size: 15),
                    ],
                  ),
                ),
                QuantityStepper(store, item.id, fly: false),
              ],
            ),
          ),
      ],
    ),
  );
}

class _CartSheet extends StatefulWidget {
  final AppStore store;
  const _CartSheet({required this.store});

  @override
  State<_CartSheet> createState() => _CartSheetState();
}

class _CartSheetState extends State<_CartSheet> {
  /// The last content built while the sheet was in front. Clearing the cart
  /// notifies listeners while the sheet is already sliding away, which would
  /// otherwise repaint it into its empty state mid-exit.
  Widget? _held;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.store,
    builder: (context, _) {
      final route = ModalRoute.of(context);
      if (route != null && !route.isCurrent && _held != null) return _held!;
      final store = widget.store;
      return _held = Semantics(
        // A route with no AppBar of its own, so the sheet has to name itself
        // for screen readers the moment it appears.
        namesRoute: true,
        label: '已选菜品',
        child: ConstrainedBox(
          // A sheet that grew to the whole screen would hide the dish the user
          // is reading; 60% leaves both readable.
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .6,
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: line,
                      borderRadius: BorderRadius.all(Radius.circular(2)),
                    ),
                    child: SizedBox(width: 36, height: 4),
                  ),
                ),
                if (store.cartItems.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
                    child: Column(
                      children: [
                        const Text(
                          '购物车还是空的',
                          style: TextStyle(color: muted),
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () => Navigator.pop(
                            context,
                            CartSheetAction.menu,
                          ),
                          child: const Text('去点餐'),
                        ),
                      ],
                    ),
                  )
                else ...[
                  Flexible(
                    child: ListView(
                      children: [
                        CartDishList(
                          store: store,
                          // An emptied cart leaves nothing worth showing, so
                          // the sheet gets out of the way right away.
                          onCleared: () => Navigator.pop(context),
                        ),
                        const SizedBox(height: 4),
                      ],
                    ),
                  ),
                  CartSummary(
                    store: store,
                    label: '去结算',
                    onTap: () =>
                        Navigator.pop(context, CartSheetAction.checkout),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    },
  );
}
