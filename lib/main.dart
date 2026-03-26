import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// 导入你重构后的各个模块
import 'core/global_keys.dart';
import 'providers/user_provider.dart';
import 'providers/device_provider.dart';
import 'providers/water_provider.dart';
import 'ui/pages/home_page.dart';
import 'ui/pages/login_page.dart';

void main() async {
  // 确保 Flutter 绑定初始化（用于本地存储等异步操作）
  WidgetsFlutterBinding.ensureInitialized();
  
  // 绕过部分旧服务器的证书校验（可选，根据你的网络环境决定）
  HttpOverrides.global = MyHttpOverrides();
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => DeviceProvider()),
        ChangeNotifierProvider(create: (_) => WaterProvider()),
      ],
      child: const WaterApp(),
    ),
  );
}

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}

class WaterApp extends StatefulWidget {
  const WaterApp({Key? key}) : super(key: key);

  @override
  State<WaterApp> createState() => _WaterAppState();
}

class _WaterAppState extends State<WaterApp> with WidgetsBindingObserver {
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 应用启动时，执行各个模块的初始化加载逻辑
    _initApp();
  }

  Future<void> _initApp() async {
    final userProvider = context.read<UserProvider>();
    final deviceProvider = context.read<DeviceProvider>();
    final waterProvider = context.read<WaterProvider>();

    // 1. 加载本地用户信息
    await userProvider.loadFromLocal();
    // 2. 加载设备列表（依赖用户信息）
    await deviceProvider.loadFromLocal(userProvider.token, userProvider.userId);
    // 3. 加载水控状态
    await waterProvider.loadFromLocal();

    // 4. 如果已登录，检查是否有待处理的 Siri 指令（iOS 特有逻辑）
    if (userProvider.token.isNotEmpty) {
      waterProvider.checkPendingAction(
        deviceProvider.selectDevice,
        deviceProvider.deviceList,
        deviceProvider.customRemarks
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 当 App 从后台回到前台时，再次检查是否有 Siri 调用的待办指令
    if (state == AppLifecycleState.resumed) {
      final userProvider = context.read<UserProvider>();
      if (userProvider.token.isNotEmpty) {
        Future.delayed(const Duration(milliseconds: 500), () {
          final deviceProvider = context.read<DeviceProvider>();
          context.read<WaterProvider>().checkPendingAction(
            deviceProvider.selectDevice,
            deviceProvider.deviceList,
            deviceProvider.customRemarks
          );
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // 关键点：绑定全局导航键，实现无 Context 的 Toast 弹出
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'UY Water',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true, // 开启 Material 3 视觉规范
      ),
      // 核心路由分发：监听 token 变化
      home: Consumer<UserProvider>(
        builder: (context, userProvider, child) {
          if (userProvider.token.isEmpty) {
            return const LoginPage();
          }
          return const HomePage();
        },
      ),
    );
  }
}