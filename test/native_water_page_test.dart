import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:water_app/models/water_usage_history_entry.dart';
import 'package:water_app/providers/device_provider.dart';
import 'package:water_app/providers/user_provider.dart';
import 'package:water_app/providers/water_provider.dart';
import 'package:water_app/ui/pages/native_water_page.dart';

class _Water extends WaterProvider {
  String? stoppedDevice;
  @override
  List<WaterUsageHistoryEntry> get history => [];
  @override
  List<WaterUsageHistoryEntry> get displayHistory => [];
  @override
  Future<void> stopWater(
    String token,
    String userId,
    String currentDeviceName, {
    String currentBalance = '',
    BalanceUpdateCallback? onBalanceUpdated,
  }) async {
    stoppedDevice = currentDeviceName;
    orderNum = '';
    activeDeviceId = '';
    notifyListeners();
  }

  @override
  Future<bool> syncHistoryFromServer({
    required String token,
    required String userId,
    bool muteToast = false,
  }) async => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const codec = StandardMethodCodec();
  late String channelName;
  late List<Map<dynamic, dynamic>> snapshots;
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    snapshots = [];
    SharedPreferences.setMockInitialValues({});
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
      call,
    ) async {
      if (call.method == 'create') {
        final id = (call.arguments as Map)['id'];
        channelName = 'com.fakeuy.water/native_ui_$id';
        messenger.setMockMethodCallHandler(MethodChannel(channelName), (
          call,
        ) async {
          if (call.method == 'state') snapshots.add(call.arguments as Map);
          return null;
        });
      }
      return null;
    });
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
    messenger.setMockMethodCallHandler(MethodChannel(channelName), null);
  });

  Future<void> mount(
    WidgetTester tester,
    UserProvider user,
    DeviceProvider devices,
    _Water water, {
    bool ready = true,
  }) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<UserProvider>.value(value: user),
          ChangeNotifierProvider<DeviceProvider>.value(value: devices),
          ChangeNotifierProvider<WaterProvider>.value(value: water),
        ],
        child: MaterialApp(home: NativeWaterPage(ready: ready)),
      ),
    );
    await tester.pump();
  }

  Future<Object?> action(Map<String, Object?> args) async {
    final completion = Completer<ByteData?>();
    messenger.handlePlatformMessage(
      channelName,
      codec.encodeMethodCall(MethodCall('action', args)),
      completion.complete,
    );
    return codec.decodeEnvelope((await completion.future)!);
  }

  testWidgets(
    'native snapshots do not expose credentials and selection cannot switch a running device',
    (tester) async {
      final user = UserProvider()
        ..token = 'private-token'
        ..userId = 'private-user';
      final devices = DeviceProvider()
        ..deviceList = [
          {'deviceInfId': 'a', 'deviceInfName': '热水', 'billType': 2},
          {'deviceInfId': 'b', 'deviceInfName': '饮水', 'billType': 1},
        ]
        ..selectedDeviceId = 'a';
      final water = _Water()
        ..orderNum = 'order'
        ..activeDeviceId = 'a';
      await mount(tester, user, devices, water);
      expect(snapshots, isNotEmpty);
      expect(snapshots.last.toString(), isNot(contains('private-token')));
      expect(snapshots.last.toString(), isNot(contains('private-user')));
      expect(snapshots.last['running'], true);
      await expectLater(
        action({'name': 'select', 'id': 'b'}),
        throwsA(isA<PlatformException>()),
      );
      expect(devices.selectedDeviceId, 'a');
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'native stop uses the active device even when another device is selected',
    (tester) async {
      final user = UserProvider()
        ..token = 'token'
        ..userId = 'user';
      final devices = DeviceProvider()
        ..deviceList = [
          {'deviceInfId': 'a', 'deviceInfName': '热水', 'billType': 2},
          {'deviceInfId': 'b', 'deviceInfName': '饮水', 'billType': 1},
        ]
        ..selectedDeviceId = 'b'
        ..customRemarks = {'a': '正在使用的淋浴'};
      final water = _Water()
        ..orderNum = 'order'
        ..activeDeviceId = 'a';
      await mount(tester, user, devices, water);
      expect(await action({'name': 'stop'}), true);
      expect(water.stoppedDevice, '正在使用的淋浴');
      expect(water.orderNum, isEmpty);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('native actions wait for local recovery and require login', (
    tester,
  ) async {
    final user = UserProvider();
    final devices = DeviceProvider();
    final water = _Water();
    await mount(tester, user, devices, water, ready: false);
    await expectLater(
      action({'name': 'refresh'}),
      throwsA(
        isA<PlatformException>().having((e) => e.code, 'code', 'loading'),
      ),
    );
    await mount(tester, user, devices, water);
    await expectLater(
      action({'name': 'refresh'}),
      throwsA(
        isA<PlatformException>().having(
          (e) => e.code,
          'code',
          'login_required',
        ),
      ),
    );
    await tester.pumpWidget(const SizedBox());
  });
}
