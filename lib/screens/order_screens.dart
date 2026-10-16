import 'package:flutter/material.dart';

import '../data/app_store.dart';
import '../models/models.dart';
import '../widgets/common.dart';

class OrdersTab extends StatefulWidget {
  final AppStore store;
  final VoidCallback onMenu, onCart;
  const OrdersTab({
    super.key,
    required this.store,
    required this.onMenu,
    required this.onCart,
  });
  @override
  State<OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<OrdersTab>
    with SingleTickerProviderStateMixin {
  static const statuses = [null, ...OrderStatus.values];
  late final TabController tabs = TabController(length: statuses.length, vsync: this)
    ..addListener(() {
      if (tabs.indexIsChanging) return;
      setState(() {
        filter = statuses[tabs.index];
        limit = 10;
      });
    });
  OrderStatus? filter;
  int limit = 10;
  @override
  void dispose() {
    tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orders = widget.store.orders
        .where((o) => filter == null || o.status == filter)
        .toList();
    return Column(
      children: [
        Container(
          color: Colors.white,
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
          child: TabBar(
            controller: tabs,
            isScrollable: false,
            indicatorColor: accent,
            indicatorSize: TabBarIndicatorSize.tab,
            indicatorWeight: 3,
            labelColor: ink,
            unselectedLabelColor: muted,
            labelStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: const TextStyle(fontSize: 14),
            dividerColor: Colors.transparent,
            tabs: [
              for (final status in statuses)
                Tab(height: 44, text: status?.label ?? '全部'),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              setState(() => limit = 10);
            },
            child: orders.isEmpty
                ? LayoutBuilder(
                    builder: (ctx, c) => ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: c.maxHeight,
                          child: EmptyView('还没有相关订单', onMenu: widget.onMenu),
                        ),
                      ],
                    ),
                  )
                : NotificationListener<ScrollNotification>(
                    onNotification: (n) {
                      if (n.metrics.extentAfter < 120 &&
                          limit < orders.length) {
                        setState(() => limit += 10);
                      }
                      return false;
                    },
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: orders.take(limit).length + 1,
                      itemBuilder: (context, i) {
                        if (i >= orders.take(limit).length) {
                          return Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text(
                              limit < orders.length ? '上拉加载更多' : '已显示全部订单',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: muted,
                                fontSize: 12,
                              ),
                            ),
                          );
                        }
                        final order = orders[i];
                        return Section(
                          child: InkWell(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => OrderDetailScreen(
                                  store: widget.store,
                                  id: order.id,
                                  onCart: widget.onCart,
                                ),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '订单 ${order.number}',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                    Text(
                                      order.status.label,
                                      style: TextStyle(
                                        color: statusColor(order.status),
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 24),
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      for (final item in order.items)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            right: 8,
                                          ),
                                          child: FoodImage(
                                            item.image,
                                            width: 60,
                                            height: 60,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  order.items
                                      .map((x) => '${x.name} ×${x.quantity}')
                                      .join('、'),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        dateLabel(order.createdAt),
                                        style: const TextStyle(
                                          color: muted,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                    Text('共 ${order.count} 份  '),
                                    Price(order.total, size: 18),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class OrderDetailScreen extends StatelessWidget {
  final AppStore store;
  final String id;
  final VoidCallback onCart;
  const OrderDetailScreen({
    super.key,
    required this.store,
    required this.id,
    required this.onCart,
  });
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) {
      final order = store.orders.where((o) => o.id == id).firstOrNull;
      if (order == null) {
        return Scaffold(
          appBar: AppBar(title: const Text('订单详情')),
          body: const EmptyView('订单不存在'),
        );
      }
      final description = switch (order.status) {
        OrderStatus.pending => '订单已提交，请到店就餐',
        OrderStatus.completed => '订单已完成，感谢光临',
        OrderStatus.cancelled => '订单已取消',
      };
      Future<void> update(OrderStatus status) async {
        if (await confirm(
              context,
              status == OrderStatus.cancelled ? '取消订单' : '确认完成',
              status == OrderStatus.cancelled ? '确定要取消该订单吗？' : '确认收到菜品并完成该订单吗？',
            ) &&
            context.mounted) {
          await perform(context, () => store.updateOrderStatus(id, status));
        }
      }

      return Scaffold(
        appBar: AppBar(title: const Text('订单详情')),
        body: ListView(
          padding: const EdgeInsets.only(bottom: 28),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFE08A4C), Color(0xFFB4531F)],
                ),
              ),
              child: Row(
                children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: Colors.white24,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  switch (order.status) {
                    OrderStatus.pending => Icons.schedule,
                    OrderStatus.completed => Icons.check,
                    OrderStatus.cancelled => Icons.close,
                  },
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.status.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
                ],
              ),
            ),
            Section(
              child: Column(
                children: [
                  const SectionTitle('菜品清单'),
                  for (final item in order.items)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          FoodImage(item.image, width: 58, height: 58),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.name),
                                Text(
                                  '¥${money(item.price)} × ${item.quantity}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Price(item.subtotal, size: 16),
                        ],
                      ),
                    ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const Text('合计  '),
                      Price(order.total, size: 24),
                    ],
                  ),
                ],
              ),
            ),
            Section(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionTitle('订单信息'),
                  _row('订单编号', order.number),
                  _row('下单时间', dateLabel(order.createdAt)),
                  _row('支付方式', '餐后到店支付'),
                  _row('备注', order.remark.isEmpty ? '无' : order.remark),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: order.status == OrderStatus.pending
                  ? Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => update(OrderStatus.cancelled),
                            child: const Text('取消订单'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () => update(OrderStatus.completed),
                            child: const Text('确认完成'),
                          ),
                        ),
                      ],
                    )
                  : FilledButton(
                      onPressed: () => perform(context, () async {
                        final skipped = await store.reorder(order);
                        if (context.mounted) {
                          toast(
                            context,
                            skipped > 0
                                ? '已加入购物车，跳过 $skipped 件下架或删除菜品'
                                : '已加入购物车',
                          );
                          Navigator.pop(context);
                          onCart();
                        }
                      }),
                      child: const Text('再来一单'),
                    ),
            ),
          ],
        ),
      );
    },
  );
  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 82,
          child: Text(
            label,
            style: const TextStyle(color: muted, fontSize: 12),
          ),
        ),
        Expanded(
          child: SelectableText(value, style: const TextStyle(fontSize: 13)),
        ),
      ],
    ),
  );
}
