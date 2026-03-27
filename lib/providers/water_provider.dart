import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/toast_service.dart';
import '../models/water_usage_history_entry.dart';
import '../services/api_service.dart';

typedef BalanceUpdateCallback = Future<void> Function(String balance);

class WaterProvider extends ChangeNotifier {
  WaterProvider();

  static const MethodChannel _siriChannel = MethodChannel(
    'com.fakeuy.water/siri',
  );

  String orderNum = '';
  String tableName = '';
  String mac = '';
  bool isRequesting = false;
  List<WaterUsageHistoryEntry> history = [];

  DateTime? startTime;
  Timer? timer;
  String runningTime = '00:00';

  bool _isHandlingPendingAction = false;

  Future<void> loadFromLocal() async {
    final prefs = await SharedPreferences.getInstance();
    orderNum = prefs.getString('water_orderNum') ?? '';
    tableName = prefs.getString('water_tableName') ?? '';
    mac = prefs.getString('water_mac') ?? '';
    history = (prefs.getStringList('water_history') ?? [])
        .map(WaterUsageHistoryEntry.fromStorage)
        .toList();

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
    String currentBalance = '',
    BalanceUpdateCallback? onBalanceUpdated,
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
          ToastService.show('未找到匹配设备');
          return;
        }

        final targetDeviceId = targetDevice['deviceInfId']?.toString() ?? '';
        if (targetDeviceId.isNotEmpty) {
          onSelectDevice(targetDeviceId);
        }

        if (token.isNotEmpty && userId.isNotEmpty && orderNum.isEmpty) {
          await startWater(
            token,
            userId,
            targetDevice,
            currentBalance: currentBalance,
          );
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
        await stopWater(
          token,
          userId,
          currentDeviceName,
          currentBalance: currentBalance,
          onBalanceUpdated: onBalanceUpdated,
        );
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
    Map<String, dynamic> device, {
    String currentBalance = '',
  }) async {
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

      final res = await ApiService.post(
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

      if (res != null && (res['code'] == 0 || res['code'] == '0')) {
        startTime = DateTime.now();
        orderNum = res['data']['orderNum']?.toString() ?? '';
        tableName = res['data']['tableName']?.toString() ?? '';
        mac = res['data']['mac']?.toString() ?? '';

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('water_orderNum', orderNum);
        await prefs.setString('water_tableName', tableName);
        await prefs.setString('water_mac', mac);
        await prefs.setInt(
          'water_start_time',
          startTime!.millisecondsSinceEpoch,
        );
        if (currentBalance.trim().isNotEmpty) {
          await prefs.setString('water_initial_balance', currentBalance.trim());
        }

        _startRunningTimer();
        ToastService.show('设备已开启，正在出水...');
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
    String currentDeviceName, {
    String currentBalance = '',
    BalanceUpdateCallback? onBalanceUpdated,
  }) async {
    if (orderNum.isEmpty || isRequesting) {
      return;
    }

    isRequesting = true;
    notifyListeners();

    final finalTime = runningTime;
    final currentOrderNum = orderNum;
    final currentStartTime = startTime;
    final prefs = await SharedPreferences.getInstance();
    final savedInitialBalance = prefs.getString('water_initial_balance') ?? '';

    try {
      final res = await ApiService.post(
        'device/endEquipment',
        {'orderNum': orderNum, 'mac': mac, 'tableName': tableName},
        token: token,
        userId: userId,
      );

      if (res != null && (res['code'] == 0 || res['code'] == '0')) {
        final syncedBalance = await _syncBalance(token, userId);
        if (syncedBalance != null && onBalanceUpdated != null) {
          await onBalanceUpdated(syncedBalance);
        }

        timer?.cancel();
        timer = null;

        await prefs.remove('water_orderNum');
        await prefs.remove('water_tableName');
        await prefs.remove('water_mac');
        await prefs.remove('water_start_time');
        await prefs.remove('water_initial_balance');

        orderNum = '';
        tableName = '';
        mac = '';
        startTime = null;
        runningTime = '00:00';

        final amount = _resolveSettlementAmount(
          response: res,
          initialBalance: savedInitialBalance.isNotEmpty
              ? savedInitialBalance
              : currentBalance,
          syncedBalance: syncedBalance ?? currentBalance,
        );
        final durationSeconds = _resolveDurationSeconds(
          response: res,
          startedAt: currentStartTime,
          fallbackRunningTime: finalTime,
        );
        final safeDeviceName = currentDeviceName.trim().isEmpty
            ? '未命名设备'
            : currentDeviceName.trim();

        ToastService.show(
          '已关水\n扣费金额：¥${amount.toStringAsFixed(2)}\n用水时长：${_formatDuration(durationSeconds)}',
          durationMs: 4200,
        );

        history.insert(
          0,
          WaterUsageHistoryEntry(
            createdAt: DateTime.now(),
            deviceName: safeDeviceName,
            amount: amount,
            durationSeconds: durationSeconds,
            orderNum: currentOrderNum,
          ),
        );
        if (history.length > 50) {
          history = history.sublist(0, 50);
        }
        await _persistHistory();
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

  Future<void> _persistHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'water_history',
      history.map((entry) => jsonEncode(entry.toJson())).toList(),
    );
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
    final suffix = resolvedDevice['billType'] == 2 ? '热水' : '直饮水';
    return '$baseName$suffix';
  }

  String _normalizeDeviceName(String value) {
    return _stripDevicePrefix(value).trim().toLowerCase();
  }

  String _stripDevicePrefix(String value) {
    return value.replaceFirst(RegExp(r'^[12]-'), '');
  }

  Future<String?> _syncBalance(String token, String userId) async {
    final syncRes = await ApiService.post(
      'user/queryUserWalletInfo',
      {},
      token: token,
      userId: userId,
      muteToast: true,
    );

    if (syncRes != null &&
        (syncRes['code'] == 0 || syncRes['code'] == '0') &&
        syncRes['data'] != null) {
      return syncRes['data']['uBalance']?.toString();
    }
    return null;
  }

  double _resolveSettlementAmount({
    required Map<String, dynamic> response,
    required String initialBalance,
    required String syncedBalance,
  }) {
    final extractedAmount = _extractSettlementAmount(response);
    if (extractedAmount != null) {
      return extractedAmount;
    }

    final before = double.tryParse(initialBalance) ?? 0;
    final after = double.tryParse(syncedBalance) ?? 0;
    final diff = before - after;
    return diff > 0 ? diff : 0;
  }

  int _resolveDurationSeconds({
    required Map<String, dynamic> response,
    required DateTime? startedAt,
    required String fallbackRunningTime,
  }) {
    final extractedDuration = _extractDurationSeconds(response);
    if (extractedDuration != null && extractedDuration >= 0) {
      return extractedDuration;
    }

    if (startedAt != null) {
      final diff = DateTime.now().difference(startedAt).inSeconds;
      if (diff >= 0) {
        return diff;
      }
    }

    return _parseClockDurationToSeconds(fallbackRunningTime);
  }

  double? _extractSettlementAmount(Map<String, dynamic> response) {
    final value = _findFirstMatchingValue(response, const [
      'expAmount',
      'expAmountStr',
      'cost',
      'costStr',
      'amount',
      'amountStr',
      'money',
      'fee',
      'feeStr',
      'deductAmount',
      'deductAmountStr',
      'consumeAmount',
      'payAmount',
    ]);
    return _parseMoneyValue(value);
  }

  int? _extractDurationSeconds(Map<String, dynamic> response) {
    final directValue = _findFirstMatchingValue(response, const [
      'durationSeconds',
      'useSeconds',
      'useSecond',
      'timeLength',
      'timeLen',
      'useLong',
      'useTimeLong',
      'duration',
      'useTime',
      'timeStr',
    ]);
    final directDuration = _parseDurationValue(directValue);
    if (directDuration != null) {
      return directDuration;
    }

    final startRaw = _findFirstMatchingValue(response, const [
      'startTime',
      'beginTime',
      'beginDate',
      'openTime',
      'createTime',
    ]);
    final endRaw = _findFirstMatchingValue(response, const [
      'endTime',
      'stopTime',
      'finishTime',
      'closeTime',
      'updateTime',
    ]);

    final start = _parseDateTimeValue(startRaw);
    final end = _parseDateTimeValue(endRaw);
    if (start != null && end != null) {
      final diff = end.difference(start).inSeconds;
      if (diff >= 0) {
        return diff;
      }
    }

    return null;
  }

  Object? _findFirstMatchingValue(Object? source, List<String> candidateKeys) {
    if (source is Map) {
      for (final entry in source.entries) {
        final key = entry.key.toString().toLowerCase();
        if (candidateKeys.any((candidate) => candidate.toLowerCase() == key)) {
          return entry.value;
        }
      }

      for (final entry in source.entries) {
        final nested = _findFirstMatchingValue(entry.value, candidateKeys);
        if (nested != null) {
          return nested;
        }
      }
    }

    if (source is Iterable) {
      for (final item in source) {
        final nested = _findFirstMatchingValue(item, candidateKeys);
        if (nested != null) {
          return nested;
        }
      }
    }

    return null;
  }

  double? _parseMoneyValue(Object? raw) {
    if (raw == null) {
      return null;
    }
    if (raw is num) {
      return raw.toDouble();
    }

    final normalized = raw.toString().replaceAll(RegExp(r'[^0-9.\-]'), '');
    return double.tryParse(normalized);
  }

  int? _parseDurationValue(Object? raw) {
    if (raw == null) {
      return null;
    }
    if (raw is int) {
      return raw;
    }
    if (raw is double) {
      return raw.round();
    }

    final text = raw.toString().trim();
    if (text.isEmpty) {
      return null;
    }

    final minuteSecondMatch = RegExp(r'(\d+)\s*分\s*(\d+)\s*秒').firstMatch(text);
    if (minuteSecondMatch != null) {
      final minutes = int.tryParse(minuteSecondMatch.group(1)!) ?? 0;
      final seconds = int.tryParse(minuteSecondMatch.group(2)!) ?? 0;
      return minutes * 60 + seconds;
    }

    final clockMatch = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(text);
    if (clockMatch != null) {
      final minutes = int.tryParse(clockMatch.group(1)!) ?? 0;
      final seconds = int.tryParse(clockMatch.group(2)!) ?? 0;
      return minutes * 60 + seconds;
    }

    final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(digits);
  }

  DateTime? _parseDateTimeValue(Object? raw) {
    if (raw == null) {
      return null;
    }

    final text = raw.toString().trim();
    if (text.isEmpty) {
      return null;
    }

    final normalized = text.replaceAll('/', '-').replaceFirst(' ', 'T');
    return DateTime.tryParse(normalized);
  }

  int _parseClockDurationToSeconds(String value) {
    final parts = value.split(':');
    if (parts.length != 2) {
      return 0;
    }

    final minutes = int.tryParse(parts[0]) ?? 0;
    final seconds = int.tryParse(parts[1]) ?? 0;
    return minutes * 60 + seconds;
  }

  String _formatDuration(int durationSeconds) {
    final minutes = durationSeconds ~/ 60;
    final seconds = durationSeconds % 60;
    return '${minutes}分${seconds}秒';
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
