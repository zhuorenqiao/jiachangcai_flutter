import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/app_store.dart';
import 'screens/shell.dart';
import 'widgets/common.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final store = AppStore(await SharedPreferences.getInstance());
    await store.initialize();
    runApp(RestaurantApp(store: store));
  } catch (_) {
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text('本地数据读取失败。请重启应用，或备份后清理应用数据再试。'),
            ),
          ),
        ),
      ),
    );
  }
}

class RestaurantApp extends StatelessWidget {
  final AppStore store;
  const RestaurantApp({super.key, required this.store});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: '家常菜餐厅',
    debugShowCheckedModeBanner: false,
    locale: const Locale('zh', 'CN'),
    supportedLocales: const [Locale('zh', 'CN')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: ThemeData(
      useMaterial3: true,
      fontFamily: 'NotoSansSC',
      scaffoldBackgroundColor: paper,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accent,
        primary: accent,
        surface: paper,
        onSurface: ink,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: paper,
        foregroundColor: ink,
        centerTitle: true,
        scrolledUnderElevation: 0,
      ),
      dividerTheme: const DividerThemeData(color: line, thickness: 1),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(minimumSize: const Size(48, 44)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: line),
        ),
      ),
    ),
    builder: (context, child) => ColoredBox(
      color: wash,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: child,
        ),
      ),
    ),
    home: ListenableBuilder(
      listenable: store,
      builder: (context, _) => store.userId == null
          ? LoginScreen(store: store)
          : RestaurantShell(store: store),
    ),
  );
}

class LoginScreen extends StatefulWidget {
  final AppStore store;
  const LoginScreen({super.key, required this.store});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool busy = false;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 60),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFF0854A), Color(0xFFD14A08)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.vertical(
                        bottom: Radius.circular(30),
                      ),
                    ),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 38,
                          backgroundColor: Colors.white,
                          child: Image.asset(
                            'assets/icons/avatar-default.png',
                            width: 72,
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          '家常菜餐厅',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 3,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '现炒家常菜 · 好吃不贵',
                          style: TextStyle(
                            color: Colors.white,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Section(
                    child: Row(
                      children: [
                        for (final item in [
                          ('cat-meat', '明厨亮灶'),
                          ('cat-soup', '每日现熬'),
                          ('cat-staple', '现点现炒'),
                        ])
                          Expanded(
                            child: Column(
                              children: [
                                Image.asset(
                                  'assets/icons/${item.$1}.png',
                                  width: 40,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  item.$2,
                                  style: const TextStyle(color: muted),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(30, 48, 30, 36),
                    child: Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: busy
                                ? null
                                : () async {
                                    setState(() => busy = true);
                                    await perform(
                                      context,
                                      () => widget.store.login(),
                                    );
                                    if (mounted) setState(() => busy = false);
                                  },
                            icon: const Icon(Icons.login),
                            label: Text(busy ? '正在进入…' : '本机登录，开始点餐'),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          '本地模式 · 菜单与订单保存在本设备\n此登录不代表微信授权',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: muted,
                            height: 1.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
