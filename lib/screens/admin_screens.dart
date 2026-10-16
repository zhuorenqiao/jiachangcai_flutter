import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/app_store.dart';
import '../models/models.dart';
import '../widgets/common.dart';

class AdminScreen extends StatefulWidget {
  final AppStore store;
  const AdminScreen({super.key, required this.store});
  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  bool categories = false;
  Future<void> editCategory([Category? category]) async {
    final controller = TextEditingController(text: category?.name ?? '');
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(category == null ? '新增分类' : '重命名分类'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 20,
          decoration: const InputDecoration(hintText: '请输入分类名称'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    Future<void>.delayed(const Duration(milliseconds: 350), controller.dispose);
    if (text != null && mounted) {
      await perform(
        context,
        () => widget.store.saveCategory(text, id: category?.id),
      );
    }
  }

  void editDish([Dish? dish]) {
    if (widget.store.categories.isEmpty) {
      toast(context, '请先添加分类');
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => DishEditScreen(store: widget.store, dish: dish),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.store,
    builder: (context, _) {
      final store = widget.store;
      return Scaffold(
        appBar: AppBar(title: const Text('菜品管理')),
        body: ListView(
          padding: const EdgeInsets.only(bottom: 28),
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  for (final item in [
                    ('${store.dishes.length}', '菜品总数'),
                    ('${store.availableDishes.length}', '已上架'),
                    ('${store.categories.length}', '分类数'),
                  ])
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            Text(
                              item.$1,
                              style: const TextStyle(
                                color: accent,
                                fontSize: 26,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              item.$2,
                              style: const TextStyle(
                                color: muted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('菜品')),
                  ButtonSegment(value: true, label: Text('分类')),
                ],
                selected: {categories},
                onSelectionChanged: (s) => setState(() => categories = s.first),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      categories ? '分类列表' : '菜品列表',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => categories ? editCategory() : editDish(),
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(categories ? '新增分类' : '新增菜品'),
                  ),
                ],
              ),
            ),
            if (categories) ...[
              if (store.categories.isEmpty) const EmptyView('还没有分类，先新增一个吧'),
              for (final cat in store.categories)
                Section(
                  padding: EdgeInsets.zero,
                  child: ListTile(
                    title: Text(cat.name),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: '重命名${cat.name}',
                          onPressed: () => editCategory(cat),
                          icon: const Icon(Icons.edit_outlined, size: 20),
                        ),
                        IconButton(
                          tooltip: '删除${cat.name}',
                          onPressed: () async {
                            if (await confirm(
                                  context,
                                  '删除分类',
                                  '确定删除“${cat.name}”吗？分类下有菜品时无法删除。',
                                ) &&
                                context.mounted) {
                              await perform(
                                context,
                                () => store.removeCategory(cat.id),
                              );
                            }
                          },
                          icon: const Icon(Icons.delete_outline, size: 20),
                        ),
                      ],
                    ),
                  ),
                ),
            ] else ...[
              if (store.dishes.isEmpty) const EmptyView('还没有菜品，先新增一道吧'),
              for (final dish in store.dishes)
                Section(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FoodImage(dish.image, width: 60, height: 72),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              dish.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              store.categories
                                      .where((c) => c.id == dish.categoryId)
                                      .firstOrNull
                                      ?.name ??
                                  '未分类',
                              style: const TextStyle(
                                fontSize: 11,
                                color: muted,
                              ),
                            ),
                            Price(dish.price, size: 16),
                          ],
                        ),
                      ),
                      Column(
                        children: [
                          SizedBox(
                            height: 32,
                            child: Switch(
                              value: dish.available,
                              onChanged: (v) => perform(
                                context,
                                () =>
                                    store.saveDish(dish.copyWith(available: v)),
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                tooltip: '编辑${dish.name}',
                                onPressed: () => editDish(dish),
                                icon: const Icon(Icons.edit_outlined, size: 20),
                              ),
                              IconButton(
                                tooltip: '删除${dish.name}',
                                onPressed: () async {
                                  if (await confirm(
                                        context,
                                        '删除菜品',
                                        '删除“${dish.name}”后不可恢复，确定删除吗？',
                                      ) &&
                                      context.mounted) {
                                    await perform(
                                      context,
                                      () => store.removeDish(dish.id),
                                    );
                                  }
                                },
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      );
    },
  );
}

class DishEditScreen extends StatefulWidget {
  final AppStore store;
  final Dish? dish;
  const DishEditScreen({super.key, required this.store, this.dish});
  @override
  State<DishEditScreen> createState() => _DishEditScreenState();
}

class _DishEditScreenState extends State<DishEditScreen> {
  final formKey = GlobalKey<FormState>();
  late final name = TextEditingController(text: widget.dish?.name ?? '');
  late final price = TextEditingController(
    text: widget.dish == null ? '' : money(widget.dish!.price),
  );
  late final description = TextEditingController(
    text: widget.dish?.description ?? '',
  );
  late final sort = TextEditingController(text: '${widget.dish?.sort ?? 0}');
  late String? categoryId = widget.dish?.categoryId;
  late String image = widget.dish?.image ?? '';
  late bool available = widget.dish?.available ?? true,
      featured = widget.dish?.featured ?? false;
  bool busy = false, picking = false;
  @override
  void dispose() {
    name.dispose();
    price.dispose();
    description.dispose();
    sort.dispose();
    super.dispose();
  }

  Future<void> chooseImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('从相册选择'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('拍照'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    setState(() => picking = true);
    await perform(context, () async {
      final selected = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1000,
        maxHeight: 1000,
        imageQuality: 80,
      );
      if (selected == null) return;
      final bytes = await selected.readAsBytes();
      if (bytes.length > 4 * 1024 * 1024) throw ArgumentError('请选择小于 4 MB 的图片');
      if (mounted) {
        setState(
          () => image =
              'data:${selected.mimeType ?? 'image/jpeg'};base64,${base64Encode(bytes)}',
        );
      }
    });
    if (mounted) setState(() => picking = false);
  }

  Future<void> save() async {
    if (!formKey.currentState!.validate() || busy) return;
    setState(() => busy = true);
    await perform(context, () async {
      await widget.store.saveDish(
        Dish(
          id: widget.dish?.id ?? widget.store.newId('d'),
          categoryId: categoryId!,
          name: name.text.trim(),
          price: parsePrice(price.text),
          description: description.text.trim(),
          sort: int.parse(sort.text),
          image: image,
          featured: featured,
          available: available,
          sales: widget.dish?.sales ?? 0,
        ),
      );
      if (mounted) {
        toast(context, '已保存');
        Navigator.pop(context);
      }
    });
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.dish == null ? '新增菜品' : '编辑菜品')),
    body: Form(
      key: formKey,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          Section(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle('菜品图片'),
                Center(
                  child: InkWell(
                    onTap: picking ? null : chooseImage,
                    child: SizedBox(
                      width: 180,
                      height: 180,
                      child: image.isEmpty
                          ? Container(
                              color: paper,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.add_photo_alternate_outlined,
                                    size: 38,
                                    color: muted,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    picking ? '正在读取…' : '点击上传图片',
                                    style: const TextStyle(color: muted),
                                  ),
                                ],
                              ),
                            )
                          : FoodImage(image, width: 180, height: 180),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  '建议使用正方形图片，图片将保存在本设备。',
                  style: TextStyle(color: muted, fontSize: 11),
                ),
              ],
            ),
          ),
          Section(
            child: Column(
              children: [
                TextFormField(
                  controller: name,
                  maxLength: 20,
                  decoration: const InputDecoration(
                    labelText: '名称',
                    hintText: '请输入菜品名称',
                  ),
                  validator: (s) => (s ?? '').trim().isEmpty ? '请输入菜品名称' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: categoryId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: '分类'),
                  items: [
                    for (final c in widget.store.categories)
                      DropdownMenuItem(value: c.id, child: Text(c.name)),
                  ],
                  onChanged: (s) => setState(() => categoryId = s),
                  validator: (s) => s == null ? '请选择分类' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: price,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: '价格（元）',
                    hintText: '0.00',
                  ),
                  validator: (s) {
                    try {
                      parsePrice(s ?? '');
                      return null;
                    } catch (_) {
                      return '请输入非负价格，最多两位小数';
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: sort,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '排序',
                    helperText: '数字越小越靠前',
                  ),
                  validator: (s) =>
                      int.tryParse(s ?? '') == null ? '请输入整数' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: description,
                  maxLength: 60,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: '描述',
                    hintText: '口味、食材等介绍（选填）',
                  ),
                ),
              ],
            ),
          ),
          Section(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('上架销售'),
                  value: available,
                  onChanged: (v) => setState(() => available = v),
                ),
                SwitchListTile(
                  title: const Text('招牌推荐'),
                  value: featured,
                  onChanged: (v) => setState(() => featured = v),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
            child: FilledButton(
              onPressed: busy || picking ? null : save,
              child: Text(busy ? '保存中…' : '保存'),
            ),
          ),
          if (widget.dish != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextButton(
                onPressed: busy
                    ? null
                    : () async {
                        if (await confirm(
                              context,
                              '删除菜品',
                              '删除后不可恢复，确定删除该菜品吗？',
                            ) &&
                            context.mounted) {
                          await perform(context, () async {
                            await widget.store.removeDish(widget.dish!.id);
                            if (context.mounted) Navigator.pop(context);
                          });
                        }
                      },
                child: const Text('删除菜品', style: TextStyle(color: Colors.red)),
              ),
            ),
        ],
      ),
    ),
  );
}
