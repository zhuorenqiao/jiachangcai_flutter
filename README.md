# 家常菜餐厅 · Flutter 版

由原微信小程序迁移而来的独立 Flutter 工程。原项目 `/workspace/-----` 未作修改；本工程位于同级新目录 `/workspace/jiachangcai_flutter`。

## 启动

验证环境：Flutter **3.47.7 stable** / Dart **3.13.5**。请使用 Flutter 3.47.7 或兼容的更新稳定版，项目已提交 `pubspec.lock`。

```bash
cd /workspace/jiachangcai_flutter
flutter pub get
flutter run -d chrome
```

Android：连接设备或启动模拟器后执行 `flutter run`，生成安装包使用 `flutter build apk --release`。
iOS：在 macOS 上安装 Xcode，执行 `flutter pub get`，使用 `ios/Runner.xcworkspace` 配置开发团队和 Bundle ID，再执行 `flutter run` 或 `flutter build ipa`。若依赖管理需要，先在 `ios` 中执行 `pod install`。

本次 Linux 环境验证了静态分析、自动测试及 Web release 构建，未生成或验证 APK / IPA。Android SDK、iOS SDK 和正式签名不包含在交付物内。

## 已迁移功能

- 导航：5 个标签页（首页/点餐/购物车/订单/我的）支持像微信一样左右滑动切换，底部导航高亮与页面双向同步；点击底部导航也会带动画切页。Web 与桌面端同时支持鼠标/触控板拖拽。
- 首页：餐厅信息、今日推荐、5 类菜单入口、热门推荐；沿用原素材与朱赭色/米白色视觉。
- 点餐：左侧分类、右侧连续菜品列表、点击定位与滚动联动、数量步进器、购物车角标与结算栏。
- 菜品详情：大图缩放、价格/月售/介绍、加入购物车、立即购买。
- 购物车：数量修改与移除、确认清空、100 字备注、实时合计、提交前确认、自动排除下架/删除菜品并采用最新价格。
- 订单：全部/待完成/已完成/已取消筛选、下拉刷新、每批 10 条触底加载、订单详情、确认取消/完成、再来一单。
- 我的：本机身份、订单数量、菜品管理、餐厅联系方式、拨号、退出登录。
- 菜品管理：菜品新增/编辑/删除、上下架、推荐、排序、价格/名称/分类校验、相册选择/拍照；分类新增/重命名/删除及非空保护。
- 持久化：首次装载原始 5 个分类、16 道菜品；会话、菜单、购物车、备注、订单与所选图片保存在设备。购物车/备注/订单按身份隔离。

## 平台差异

1. **登录是本机登录，不是微信登录。** `wx.login` 属于小程序运行时，不能直接移植到 Flutter。当前按钮明确使用本机登录，退出后重新登录会恢复同一本机账号。正式微信登录需要微信开放平台移动应用 AppID、Android 签名/iOS Universal Links、原生 SDK 插件及换取会话的服务端。未将模拟身份伪装成微信授权。
2. **当前迁移原项目实际启用的本地模式。** 原 `utils/config.js` 的云配置为空；Flutter 版未接入 WorkBuddy 微信云 SDK、云数据库、云图片上传或多端同步。后续接后端应以 `lib/data/app_store.dart` 的领域接口为接入边界。
3. **支付方式为餐后到店支付。** 与原项目一致，未接入微信支付。
4. 原小程序沙箱数据无法被 Flutter 直接访问，本次带入的是种子菜单和全部业务图片，不含设备内已有会话/订单/购物车。
5. 菜品管理沿用原项目对所有已登录用户开放的规则，没有独立管理员角色。图片使用压缩后的持久化字节存储，单张上限 4 MB，适合本地演示/单人经营场景。Web 使用浏览器本地存储，清除网站数据会清除记录，不能承担正式业务账本。
6. Web 相机能力由浏览器决定，通常需要 HTTPS 或 localhost；移动端拍照需在真机授权后验证。iOS 已配置相机与相册权限文案。拨号需要设备具备电话处理程序。
7. 跨平台控件、交互反馈和动画采用 Flutter 实现。加购时的飞入购物车动画已用 Overlay 与二次贝塞尔曲线还原：小球从加购按钮抛物线飞向购物车图标，落点时图标回弹；在菜品详情页加购时飞向详情页顶部的购物车图标，在购物车页内增减数量不触发动画。
8. **标签页滑动切换**用 `PageView` 实现，与微信一致：底部导航栏保留，左右滑动与点击导航双向同步，标题栏随页一起滑动。两点与微信不同需说明：一是滑走的标签页会被销毁、滑回时重建，滚动位置不保留（微信小程序 tabBar 页面会保留滚动位置）；二是鼠标拖拽滑动只在 Web/桌面端为分页器单独放开，页内列表仍保持平台默认的触摸类设备，以免影响文本选择与纵向滚动。若后续需要保留各标签页滚动位置，可在 `PageView` 的 `children` 外层加 `AutomaticKeepAliveClientMixin`。

## 目录

```text
lib/
  main.dart                  应用入口、中文本地化、主题与登录页
  data/app_store.dart        本地持久化、会话、菜单、购物车与订单规则
  models/models.dart         类型化模型；金额使用整数分
  screens/shell.dart         五个主标签页
  screens/dish_screen.dart   菜品详情
  screens/order_screens.dart 订单列表与详情
  screens/admin_screens.dart 菜品/分类管理与菜品编辑
  widgets/common.dart        复用图片、卡片、步进器和提示组件
assets/                      原项目素材、种子 JSON、中文字体及许可
android/ ios/ web/            Flutter 官方生成的平台工程
test/                        数据规则与界面流程测试
docs/                        迁移映射与验证记录
tools/                       Web 浏览器检查脚本
```

## 验证与构建

```bash
flutter analyze
flutter test --reporter expanded
flutter build web --release --no-web-resources-cdn --no-wasm-dry-run
python3 -m http.server 5173 --bind 0.0.0.0 --directory build/web
```

Web release 包位于 `build/web`，用 HTTP 服务器访问，不要直接双击 `index.html`。已将中文字体与 Web 渲染资源随构建打包。字体为 Noto Sans CJK SC，许可见 `assets/fonts/OFL.txt`。

Flutter 官方环境安装说明：[Install Flutter](https://docs.flutter.dev/install/manual)。
