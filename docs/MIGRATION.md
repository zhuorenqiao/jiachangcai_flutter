# 迁移映射

| 原微信小程序 | Flutter 位置 / 替代能力 |
|---|---|
| app.js / app.json / app.wxss | lib/main.dart：启动、主题、中文本地化 |
| pages/login | LoginScreen：本机身份建立与恢复 |
| pages/main + main-tabbar | RestaurantShell：PageView 左右滑动 + 底部 NavigationBar，双向同步 |
| components/tab-home | HomeTab |
| components/tab-menu | MenuTab：分类定位与连续滚动 |
| components/tab-cart | CartTab + 提交前确认对话框 |
| components/tab-orders | OrdersTab：筛选、刷新与批量加载 |
| components/tab-profile | ProfileTab |
| pages/dish | DishScreen |
| pages/order-detail | OrderDetailScreen |
| pages/admin | AdminScreen |
| pages/dish-edit | DishEditScreen |
| dish-card / stepper / cart-bar / empty | DishListTile / QuantityStepper / CartSummary / EmptyView |
| utils/auth.js / wx.storage | AppStore + shared_preferences |
| utils/cart.js / utils/store.js 本地分支 | AppStore：购物车、菜单、订单 |
| utils/seed-menu.js | assets/menu.json；保留原名称、价格、描述、销量、排序、推荐标记 |
| wx.chooseImage / wx.saveFile | image_picker + 持久化图片字节 |
| wx.showModal / wx.showToast | Material Dialog / SnackBar |
| wx.previewImage | Dialog + InteractiveViewer |
| wx 小程序导航 | Navigator + PageView 滑动分页（滑走的标签页会被销毁，回到时重建） |
| 小程序云服务分支 | 当前未启用；后续需单独移植后端协议与认证 |

金额统一用整数分计算，订单创建时使用最新有效菜品快照。菜品后续编辑或删除不会改变历史订单。订单仅允许从待完成进入已完成或已取消，终态不可再次转换。再来一单会忽略已下架或删除的菜品。

未更改原目录内的任何文件。Flutter 工程与素材副本均置于独立同级目录。原文件 SHA-256 校验结果见 `VALIDATION.md`。
