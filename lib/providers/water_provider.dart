import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/toast_service.dart';
import '../services/api_service.dart';

class WaterProvider extends ChangeNotifier {
  WaterProvider();

  static const MethodChannel _siriChannel = MethodChannel(
    'com.fakeuy.water/siri',
  );

  String orderNum = '';
  String tableName = '';
  String mac = '';
  bool isRequesting = false;
  List<String> history = [];

  DateTime? startTime;
  Timer? timer;
  String runningTime = '00:00';

  bool _isHandlingPendingAction = false;

  Future<void> loadFromLocal() async {
    final prefs = await SharedPreferences.getInstance();
    orderNum = prefs.getString('water_orderNum') ?? '';
    tableName = prefs.getString('water_tableName') ?? '';
    mac = prefs.getString('water_mac') ?? '';
    history = prefs.getStringList('water_history') ?? [];

    final savedStartTime = prefs.getInt('water_start_time') ?? 0;
    if (orderNum.isNotEmpty && savedStartTime > 0) {
      startTime = DateTime.fromMillisecondsSinceEpoch(savedStartTime);
      _startRunningTimer();
    } else {
      startTime = null;
      runningTime = '00:00';
      timer?.cancel();
      timer = null;
    }

    notifyListeners();
  }

  Future<void> checkPendingAction(
    ValueChanged<String> onSelectDevice,
    List<Map<String, dynamic>> deviceList,
    Map<String, String> customRemarks, {
    String token = '',
    String userId = '',
    String selectedDeviceId = '',
  }) async {
    if (_isHandlingPendingAction) {
      return;
    }

    _isHandlingPendingAction = true;
    try {
      final res = await _siriChannel.invokeMapMethod<String, dynamic>(
        'getPendingAction',
      );
      if (res == null) {
        return;
      }

      final action = (res['action'] ?? '').toString().trim().toLowerCase();
      final targetName = (res['device'] ?? '').toString().trim();
      if (action.isEmpty) {
        return;
      }

      final readyDeviceList = await _waitForDeviceList(deviceList);
      if (action == 'start') {
        final targetDevice = _resolveTargetDevice(
          deviceList: readyDeviceList,
          customRemarks: customRemarks,
          targetName: targetName,
          selectedDeviceId: selectedDeviceId,
        );
        if (targetDevice == null) {
          ToastService.show('No matching device found');
          return;
        }

        final targetDeviceId = targetDevice['deviceInfId']?.toString() ?? '';
        if (targetDeviceId.isNotEmpty) {
          onSelectDevice(targetDeviceId);
        }

        if (token.isNotEmpty && userId.isNotEmpty && orderNum.isEmpty) {
          await startWater(token, userId, targetDevice);
        }
        return;
      }

      if (action == 'stop') {
        if (token.isEmpty || userId.isEmpty || orderNum.isEmpty) {
          return;
        }

        final currentDeviceName = _buildCurrentDeviceName(
          deviceList: readyDeviceList,
          customRemarks: customRemarks,
          selectedDeviceId: selectedDeviceId,
        );
        await stopWater(token, userId, currentDeviceName);
      }
    } on MissingPluginException catch (error) {
      debugPrint('Siri channel is not ready yet: $error');
    } catch (error, stackTrace) {
      debugPrint('Failed to consume pending Siri action: $error');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      _isHandlingPendingAction = false;
    }
  }

  Future<bool> startWater(
    String token,
    String userId,
    Map<String, dynamic> device,
  ) async {
    if (isRequesting) {
      return false;
    }

    isRequesting = true;
    notifyListeners();

    final targetDeviceId = device['deviceInfId'].toString();
    final targetBillType = device['billType'].toString();

    try {
      await ApiService.post(
        'device/useEquipment',
        {
          'orderWay': '1',
          'theConnectionMethod': '2',
          'deviceInfId': targetDeviceId,
          'billType': targetBillType,
          'lackBalance': 'lackBalance',
          'type': '1',
        },
        token: token,
        userId: userId,
        muteToast: true,
      );

      await Future.delayed(const Duration(milliseconds: 550));

      final res2 = await ApiService.post(
        'device/useEquipment',
        {
          'orderWay': '1',
          'theConnectionMethod': '2',
          'deviceInfId': targetDeviceId,
          'billType': targetBillType,
          'lackBalance': 'lackBalance',
          'type': '0',
        },
        token: token,
        userId: userId,
      );

      if (res2 != null && (res2['code'] == 0 || res2['code'] == '0')) {
        startTime = DateTime.now();
        orderNum = res2['data']['orderNum']?.toString() ?? '';
        tableName = res2['data']['tableName']?.toString() ?? '';
        mac = res2['data']['mac']?.toString() ?? '';

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('water_orderNum', orderNum);
        await prefs.setString('water_tableName', tableName);
        await prefs.setString('water_mac', mac);
        await prefs.setInt(
          'water_start_time',
          startTime!.millisecondsSinceEpoch,
        );

        _startRunningTimer();
        ToastService.show('Water started');
        return true;
      }
    } finally {
      isRequesting = false;
      notifyListeners();
    }

    return false;
  }

  Future<void> stopWater(
    String token,
    String userId,
    String currentDeviceName,
  ) async {
    if (orderNum.isEmpty || isRequesting) {
      return;
    }

    isRequesting = true;
    notifyListeners();

    final finalTime = runningTime;

    try {
      final res = await ApiService.post(
        'device/endEquipment',
        {'orderNum': orderNum, 'mac': mac, 'tableName': tableName},
        token: token,
        userId: userId,
      );

      if (res != null && (res['code'] == 0 || res['code'] == '0')) {
        timer?.cancel();
        timer = null;

        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('water_orderNum');
        await prefs.remove('water_tableName');
        await prefs.remove('water_mac');
        await prefs.remove('water_start_time');

        orderNum = '';
        tableName = '';
        mac = '';
        startTime = null;
        runningTime = '00:00';

        ToastService.show('Water stopped after $finalTime', durationMs: 4000);

        final safeDeviceName = currentDeviceName.trim().isEmpty
            ? 'Device'
            : currentDeviceName.trim();
        history.insert(
          0,
          '${DateFormat('MM-dd HH:mm').format(DateTime.now())} ($safeDeviceName $finalTime)',
        );
        if (history.length > 50) {
          history = history.sublist(0, 50);
        }
        await prefs.setStringList('water_history', history);
      }
    } finally {
      isRequesting = false;
      notifyListeners();
    }
  }

  Future<void> clearHistory() async {
    history.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('water_history');
    notifyListeners();
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _waitForDeviceList(
    List<Map<String, dynamic>> deviceList,
  ) async {
    var retry = 0;
    while (deviceList.isEmpty && retry < 30) {
      await Future.delayed(const Duration(milliseconds: 200));
      retry++;
    }
    return deviceList;
  }

  Map<String, dynamic>? _resolveTargetDevice({
    required List<Map<String, dynamic>> deviceList,
    required Map<String, String> customRemarks,
    required String targetName,
    required String selectedDeviceId,
  }) {
    if (deviceList.isEmpty) {
      return null;
    }

    final normalizedTarget = _normalizeDeviceName(targetName);
    if (normalizedTarget.isNotEmpty) {
      for (final device in deviceList) {
        final deviceId = device['deviceInfId']?.toString() ?? '';
        final remarkName = customRemarks[deviceId] ?? '';
        final backendName = device['deviceInfName']?.toString() ?? '';
        final candidates = <String>{
          _normalizeDeviceName(remarkName),
          _normalizeDeviceName(backendName),
        }..removeWhere((name) => name.isEmpty);

        final matched = candidates.any(
          (candidate) =>
              candidate == normalizedTarget ||
              candidate.contains(normalizedTarget) ||
              normalizedTarget.contains(candidate),
        );
        if (matched) {
          return device;
        }
      }
    }

    if (selectedDeviceId.isNotEmpty) {
      for (final device in deviceList) {
        if (device['deviceInfId']?.toString() == selectedDeviceId) {
          return device;
        }
      }
    }

    return deviceList.first;
  }

  String _buildCurrentDeviceName({
    required List<Map<String, dynamic>> deviceList,
    required Map<String, String> customRemarks,
    required String selectedDeviceId,
  }) {
    if (deviceList.isEmpty) {
      return '';
    }

    Map<String, dynamic>? device;
    if (selectedDeviceId.isNotEmpty) {
      for (final item in deviceList) {
        if (item['deviceInfId']?.toString() == selectedDeviceId) {
          device = item;
          break;
        }
      }
    }
    final resolvedDevice = device ?? deviceList.first;

    final deviceId = resolvedDevice['deviceInfId']?.toString() ?? '';
    final customName = customRemarks[deviceId];
    final backendName = resolvedDevice['deviceInfName']?.toString() ?? '';
    final baseName = (customName == null || customName.trim().isEmpty)
        ? _stripDevicePrefix(backendName)
        : customName.trim();
    final suffix = resolvedDevice['billType'] == 2
        ? ' hot water'
        : ' drinking water';
    return '$baseName$suffix';
  }

  String _normalizeDeviceName(String value) {
    return _stripDevicePrefix(value).trim().toLowerCase();
  }

  String _stripDevicePrefix(String value) {
    return value.replaceFirst(RegExp(r'^[12]-'), '');
  }

  void _startRunningTimer() {
    timer?.cancel();
    if (startTime == null) {
      runningTime = '00:00';
      return;
    }

    void syncRunningTime() {
      final diff = DateTime.now().difference(startTime!);
      runningTime =
          '${diff.inMinutes.toString().padLeft(2, '0')}:${(diff.inSeconds % 60).toString().padLeft(2, '0')}';
      notifyListeners();
    }

    syncRunningTime();
    timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => syncRunningTime(),
    );
  }
}
