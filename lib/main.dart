import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/global_keys.dart';
import 'providers/device_provider.dart';
import 'providers/user_provider.dart';
import 'providers/water_provider.dart';
import 'ui/pages/home_page.dart';
import 'ui/pages/login_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = MyHttpOverrides();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<UserProvider>(create: (_) => UserProvider()),
        ChangeNotifierProvider<DeviceProvider>(create: (_) => DeviceProvider()),
        ChangeNotifierProvider<WaterProvider>(create: (_) => WaterProvider()),
      ],
      child: const WaterApp(),
    ),
  );
}

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

class WaterApp extends StatefulWidget {
  const WaterApp({super.key});

  @override
  State<WaterApp> createState() => _WaterAppState();
}

class _WaterAppState extends State<WaterApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initApp();
    });
  }

  Future<void> _initApp() async {
    final userProvider = context.read<UserProvider>();
    final deviceProvider = context.read<DeviceProvider>();
    final waterProvider = context.read<WaterProvider>();

    await userProvider.loadFromLocal();
    if (!mounted) {
      return;
    }

    await deviceProvider.loadFromLocal(userProvider.token, userProvider.userId);
    if (!mounted) {
      return;
    }

    await waterProvider.loadFromLocal();
    if (!mounted) {
      return;
    }

    if (userProvider.token.isNotEmpty && userProvider.userId.isNotEmpty) {
      await waterProvider.syncHistoryFromServer(
        token: userProvider.token,
        userId: userProvider.userId,
        muteToast: true,
      );
      if (!mounted) {
        return;
      }

      unawaited(
        waterProvider.backfillHistoryIfNeeded(
          token: userProvider.token,
          userId: userProvider.userId,
        ),
      );
    }

    await _consumePendingAction();
  }

  Future<void> _consumePendingAction() async {
    final userProvider = context.read<UserProvider>();
    if (userProvider.token.isEmpty || userProvider.userId.isEmpty) {
      return;
    }

    final deviceProvider = context.read<DeviceProvider>();
    final waterProvider = context.read<WaterProvider>();

    await waterProvider.checkPendingAction(
      deviceProvider.selectDevice,
      deviceProvider.deviceList,
      deviceProvider.customRemarks,
      token: userProvider.token,
      userId: userProvider.userId,
      selectedDeviceId: deviceProvider.selectedDeviceId,
      currentBalance: userProvider.balance,
      onBalanceUpdated: userProvider.setBalance,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      return;
    }

    Future<void>.delayed(const Duration(milliseconds: 500), () async {
      if (!mounted) {
        return;
      }
      await _consumePendingAction();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'UY Water',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
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
