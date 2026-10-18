import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:water_app/main.dart';
import 'package:water_app/providers/device_provider.dart';
import 'package:water_app/providers/user_provider.dart';
import 'package:water_app/providers/water_provider.dart';

class _LoginTestWaterProvider extends WaterProvider {
  @override
  Future<void> loadFromLocal() async {}
}

void main() {
  testWidgets('renders the login flow when no local session exists', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<UserProvider>(create: (_) => UserProvider()),
          ChangeNotifierProvider<DeviceProvider>(
            create: (_) => DeviceProvider(),
          ),
          ChangeNotifierProvider<WaterProvider>(
            create: (_) => _LoginTestWaterProvider(),
          ),
        ],
        child: const WaterApp(),
      ),
    );

    await tester.pump();

    expect(find.text('登录账号'), findsOneWidget);
  });
}
