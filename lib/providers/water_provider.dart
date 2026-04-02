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

  static const int _historySchemaVersion = 3;
  static const int _historyBackfillMaxMonths = 48;
  static const int _historyBackfillEmptyStopCount = 6;

  static const String _historySchemaVersionKey = 'water_history_schema_version';
  static const String _legacyHistoryStorageKey = 'water_history';
  static const String _displayHistoryStorageKey = 'water_display_history';
  static const String _historyMonthCacheKey = 'water_history_month_cache';
  static const String _historySelectedMonthKey = 'water_history_selected_month';
  static const String _historySyncedMonthsKey = 'water_history_synced_months';
  static const String _localDurationStorageKey = 'water_local_duration_records';
  static const String _durationPatchStorageKey = 'water_history_duration_patches';
  static const String _historyPatchLinksKey = 'water_history_patch_links';
  static const String _deviceUsageStatsKey = 'water_device_usage_stats';
  static const String _countedUsageOrderNumsKey = 'water_counted_usage_order_nums';

  String orderNum = '';
  String tableName = '';
  String mac = '';
  String activeDeviceId = '';
  bool isRequesting = false;
  bool isHistoryLoading = false;
  bool isHistoryBackfilling = false;

  final Map<String, List<WaterUsageHistoryEntry>> _monthlyServerHistoryCache = {};
  final Map<String, WaterUsageHistoryEntry> _durationPatches = {};
  final Map<String, String> _historyPatchLinks = {};
  final Map<String, int> _deviceUsageCounts = {};
  final Set<String> _countedUsageOrderNums = <String>{};
  List<WaterUsageHistoryEntry> _localDurationRecords = [];
  final Set<String> _syncedHistoryMonths = <String>{};
  String _selectedHistoryMonthKey = '';
  bool _needsHistoryBackfill = false;

  DateTime? startTime;
  Timer? timer;
  String runningTime = '00:00';

  bool _isHandlingPendingAction = false;

  List<WaterUsageHistoryEntry> get history => List.unmodifiable(
    _buildUsageHistory(),
  );

  List<WaterUsageHistoryEntry> get displayHistory => List.unmodifiable(
    buildDisplayHistoryForMonth(selectedHistoryMonthKey),
  );

  String get selectedHistoryMonthKey =>
      _selectedHistoryMonthKey.isEmpty ? _currentMonthKey() : _selectedHistoryMonthKey;

  int get selectedHistoryYear => _monthDate(selectedHistoryMonthKey).year;

  int get selectedHistoryMonth => _monthDate(selectedHistoryMonthKey).month;

  List<int> get availableHistoryYears {
    final years = <int>{DateTime.now().year};
    for (final monthKey in _monthlyServerHistoryCache.keys) {
      years.add(_monthDate(monthKey).year);
    }
    for (final entry in _localDurationRecords) {
      years.add(entry.createdAt.year);
    }
    final result = years.toList()..sort((a, b) => b.compareTo(a));
    return result;
  }

  bool get needsHistoryBackfill => _needsHistoryBackfill;

  Map<String, int> get deviceUsageCounts => Map.unmodifiable(_deviceUsageCounts);

  List<WaterUsageHistoryEntry> get localDurationRecords =>
      List.unmodifiable(_localDurationRecords);

  List<int> availableMonthsForYear(int year) {
    final now = DateTime.now();
    final maxMonth = year == now.year ? now.month : 12;
    return List<int>.generate(maxMonth, (index) => index + 1);
  }

  Future<void> loadFromLocal() async {
    final prefs = await SharedPreferences.getInstance();
    orderNum = prefs.getString('water_orderNum') ?? '';
    tableName = prefs.getString('water_tableName') ?? '';
    mac = prefs.getString('water_mac') ?? '';
    activeDeviceId = prefs.getString('water_activeDeviceId') ?? '';

    _monthlyServerHistoryCache
      ..clear()
      ..addAll(_decodeMonthlyHistoryCache(prefs.getString(_historyMonthCacheKey)));
    _durationPatches
      ..clear()
      ..addAll(_decodeDurationPatches(prefs.getString(_durationPatchStorageKey)));
    _historyPatchLinks
      ..clear()
      ..addAll(_decodeStringMap(prefs.getString(_historyPatchLinksKey)));
    _deviceUsageCounts
      ..clear()
      ..addAll(_decodeIntMap(prefs.getString(_deviceUsageStatsKey)));
    _countedUsageOrderNums
      ..clear()
      ..addAll(
        (prefs.getStringList(_countedUsageOrderNumsKey) ?? const <String>[])
            .where((item) => item.trim().isNotEmpty),
      );
    _rebuildLocalDurationRecordsFromPatches();
    final legacyLocalDurationRecords = _decodeHistoryEntries(
      prefs.getStringList(_localDurationStorageKey),
    );
    _syncedHistoryMonths
      ..clear()
      ..addAll(
        (prefs.getStringList(_historySyncedMonthsKey) ?? const <String>[])
            .where((item) => item.trim().isNotEmpty),
      );
    _selectedHistoryMonthKey =
        prefs.getString(_historySelectedMonthKey)?.trim() ?? '';

    _ingestDurationRecords(
      _monthlyServerHistoryCache.values
          .expand((entries) => entries)
          .where(_hasDuration),
    );

    await _migrateLegacyHistoryIfNeeded(
      prefs,
      legacyLocalDurationRecords: legacyLocalDurationRecords,
    );

    if (_durationPatches.isEmpty && legacyLocalDurationRecords.isNotEmpty) {
      _ingestDurationRecords(legacyLocalDurationRecords);
    }
    _rebuildLocalDurationRecordsFromPatches();
    _reconcileUsageCountsFromEntries(_buildUsageHistory());
    _historyPatchLinks.removeWhere(
      (_, patchKey) => !_durationPatches.containsKey(patchKey),
    );
    if (_selectedHistoryMonthKey.isEmpty ||
        _isMonthKeyInFuture(_selectedHistoryMonthKey)) {
      _selectedHistoryMonthKey = _currentMonthKey();
    }

    final schemaVersion = prefs.getInt(_historySchemaVersionKey) ?? 0;
    final hasOnlyCurrentMonthCache =
        _syncedHistoryMonths.isEmpty ||
        (_syncedHistoryMonths.length == 1 &&
            _syncedHistoryMonths.contains(_currentMonthKey()));
    _needsHistoryBackfill =
        schemaVersion < _historySchemaVersion || hasOnlyCurrentMonthCache;

    final savedStartTime = prefs.getInt('water_start_time') ?? 0;
    if (orderNum.isNotEmpty && savedStartTime > 0) {
      startTime = DateTime.fromMillisecondsSinceEpoch(savedStartTime);
      _startRunningTimer();
    } else {
      startTime = null;
      runningTime = '00:00';
      timer?.cancel();
      timer = null;
      activeDeviceId = '';
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
          ToastService.show('\u672a\u627e\u5230\u5339\u914d\u8bbe\u5907');
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
        activeDeviceId = targetDeviceId;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('water_orderNum', orderNum);
        await prefs.setString('water_tableName', tableName);
        await prefs.setString('water_mac', mac);
        await prefs.setString('water_activeDeviceId', activeDeviceId);
        await prefs.setInt(
          'water_start_time',
          startTime!.millisecondsSinceEpoch,
        );
        if (currentBalance.trim().isNotEmpty) {
          await prefs.setString('water_initial_balance', currentBalance.trim());
        }

        _upsertLocalDurationRecord(
          WaterUsageHistoryEntry(
            createdAt: startTime!,
            deviceName: _localHistoryDeviceName(device),
            amount: 0,
            orderNum: orderNum,
            deviceId: targetDeviceId,
            isLocalOnly: true,
          ),
        );
        _incrementUsageCount(targetDeviceId, orderNum);
        await _persistHistoryCaches(prefs: prefs);

        _startRunningTimer();
        ToastService.show('\u8bbe\u5907\u5df2\u5f00\u542f\uff0c\u51fa\u6c34\u4e2d...');
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
    final currentActiveDeviceId = activeDeviceId;
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
        await prefs.remove('water_activeDeviceId');

        orderNum = '';
        tableName = '';
        mac = '';
        activeDeviceId = '';
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
            ? '\u672a\u547d\u540d\u8bbe\u5907'
            : currentDeviceName.trim();

        ToastService.show(
          '\u5df2\u5173\u6c34\n\u6263\u8d39\u91d1\u989d\uff1a\u00a5${amount.toStringAsFixed(2)}\n\u7528\u6c34\u65f6\u957f\uff1a${_formatDuration(durationSeconds)}',
          durationMs: 4200,
        );

        _upsertLocalDurationRecord(
          WaterUsageHistoryEntry(
            createdAt: currentStartTime ?? DateTime.now(),
            deviceName: safeDeviceName,
            amount: amount,
            deviceId: currentActiveDeviceId.isEmpty ? null : currentActiveDeviceId,
            isLocalOnly: true,
            durationSeconds: durationSeconds,
            orderNum: currentOrderNum,
          ),
        );
        await _persistHistoryCaches(prefs: prefs);
      }
    } finally {
      isRequesting = false;
      notifyListeners();
    }
  }

  void selectHistoryMonth(int year, int month) {
    if (_isFutureMonth(year, month)) {
      final now = DateTime.now();
      year = now.year;
      month = now.month;
    }
    _selectedHistoryMonthKey = _monthKey(year, month);
    unawaited(_persistSelectedHistoryMonth());
    notifyListeners();
  }

  Future<bool> syncHistoryMonth({
    required String token,
    required String userId,
    required int year,
    required int month,
    bool selectAfterSync = false,
    bool muteToast = false,
  }) async {
    if (token.trim().isEmpty || userId.trim().isEmpty) {
      return false;
    }
    if (_isFutureMonth(year, month) || isHistoryLoading) {
      return false;
    }

    isHistoryLoading = true;
    notifyListeners();

    try {
      final serverItems = await ApiService.fetchAllBillHistoryMonth(
        token: token,
        userId: userId,
        year: year,
        month: month,
        muteToast: muteToast,
      );

      if (serverItems == null) {
        return false;
      }

      final monthKey = _monthKey(year, month);
      final monthEntries = serverItems
          .map(WaterUsageHistoryEntry.fromServerBill)
          .toList(growable: false)
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      final mergedMonthEntries = _mergeServerEntriesWithLocalDurations(
        serverEntries: monthEntries,
        rememberLinks: true,
      );
      _monthlyServerHistoryCache[monthKey] = mergedMonthEntries;
      _reconcileUsageCountsFromEntries(mergedMonthEntries);
      _syncedHistoryMonths.add(monthKey);
      if (selectAfterSync) {
        _selectedHistoryMonthKey = monthKey;
        await _persistSelectedHistoryMonth();
      }

      await _persistHistoryCaches();
      return true;
    } finally {
      isHistoryLoading = false;
      notifyListeners();
    }
  }

  Future<bool> syncHistoryFromServer({
    required String token,
    required String userId,
    bool muteToast = false,
  }) async {
    final now = DateTime.now();
    return syncHistoryMonth(
      token: token,
      userId: userId,
      year: now.year,
      month: now.month,
      muteToast: muteToast,
    );
  }

  Future<void> backfillHistoryIfNeeded({
    required String token,
    required String userId,
  }) async {
    if (!_needsHistoryBackfill ||
        isHistoryBackfilling ||
        token.trim().isEmpty ||
        userId.trim().isEmpty) {
      return;
    }

    isHistoryBackfilling = true;
    notifyListeners();

    var backfillCompleted = false;

    try {
      final now = DateTime.now();
      var cursor = DateTime(now.year, now.month - 1);
      var emptyMonthStreak = 0;

      for (var step = 0;
          step < _historyBackfillMaxMonths &&
              emptyMonthStreak < _historyBackfillEmptyStopCount;
          step++) {
        final monthKey = _monthKey(cursor.year, cursor.month);
        final hasCachedMonth =
            _syncedHistoryMonths.contains(monthKey) &&
            _monthlyServerHistoryCache.containsKey(monthKey);

        if (hasCachedMonth) {
          final cachedEntries =
              _monthlyServerHistoryCache[monthKey] ??
              const <WaterUsageHistoryEntry>[];
          emptyMonthStreak = cachedEntries.isEmpty ? emptyMonthStreak + 1 : 0;
        } else {
          final serverItems = await ApiService.fetchAllBillHistoryMonth(
            token: token,
            userId: userId,
            year: cursor.year,
            month: cursor.month,
            muteToast: true,
          );

          if (serverItems == null) {
            return;
          }

          final monthEntries = serverItems
              .map(WaterUsageHistoryEntry.fromServerBill)
              .toList(growable: false)
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          final mergedMonthEntries = _mergeServerEntriesWithLocalDurations(
            serverEntries: monthEntries,
            rememberLinks: true,
          );
          _monthlyServerHistoryCache[monthKey] = mergedMonthEntries;
          _reconcileUsageCountsFromEntries(mergedMonthEntries);
          _syncedHistoryMonths.add(monthKey);
          emptyMonthStreak = monthEntries.isEmpty ? emptyMonthStreak + 1 : 0;

          await _persistHistoryCaches();
          notifyListeners();
          await Future.delayed(const Duration(milliseconds: 320));
        }

        cursor = DateTime(cursor.year, cursor.month - 1);
      }

      backfillCompleted = true;
      _needsHistoryBackfill = false;
      await _persistHistoryCaches(markSchemaCurrent: true);
    } finally {
      isHistoryBackfilling = false;
      if (!backfillCompleted) {
        _needsHistoryBackfill = true;
      }
      notifyListeners();
    }
  }

  Future<void> clearHistory() async {
    _monthlyServerHistoryCache.clear();
    _durationPatches.clear();
    _historyPatchLinks.clear();
    _deviceUsageCounts.clear();
    _countedUsageOrderNums.clear();
    _localDurationRecords.clear();
    _syncedHistoryMonths.clear();
    _selectedHistoryMonthKey = _currentMonthKey();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyMonthCacheKey);
    await prefs.remove(_durationPatchStorageKey);
    await prefs.remove(_historyPatchLinksKey);
    await prefs.remove(_deviceUsageStatsKey);
    await prefs.remove(_countedUsageOrderNumsKey);
    await prefs.remove(_localDurationStorageKey);
    await prefs.remove(_displayHistoryStorageKey);
    await prefs.remove(_legacyHistoryStorageKey);
    await prefs.remove(_historySelectedMonthKey);
    await prefs.remove(_historySyncedMonthsKey);
    notifyListeners();
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  List<WaterUsageHistoryEntry> buildDisplayHistoryForMonth(String monthKey) {
    final resolvedMonthKey =
        monthKey.trim().isEmpty ? selectedHistoryMonthKey : monthKey.trim();
    final serverEntries =
        _monthlyServerHistoryCache[resolvedMonthKey] ??
        const <WaterUsageHistoryEntry>[];
    final mergedEntries = _mergeServerEntriesWithLocalDurations(
      serverEntries: serverEntries,
    ).toList(growable: true);
    final monthLocalEntries = _localDurationRecords
        .where((entry) => _monthKeyForDate(entry.createdAt) == resolvedMonthKey)
        .toList(growable: false);

    if (monthLocalEntries.isEmpty) {
      return mergedEntries;
    }

    for (final localEntry in monthLocalEntries) {
      final existingIndex = _findDisplayMergeIndexForLocal(
        displayEntries: mergedEntries,
        localEntry: localEntry,
      );
      if (existingIndex == null) {
        mergedEntries.add(localEntry);
        continue;
      }

      mergedEntries[existingIndex] = _preferHistoryEntry(
        mergedEntries[existingIndex],
        localEntry,
      );
    }

    mergedEntries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return mergedEntries;
  }

  int? _findDisplayMergeIndexForLocal({
    required List<WaterUsageHistoryEntry> displayEntries,
    required WaterUsageHistoryEntry localEntry,
  }) {
    final localOrderNum = localEntry.orderNum.trim();
    if (localOrderNum.isNotEmpty) {
      for (var index = 0; index < displayEntries.length; index++) {
        if (displayEntries[index].orderNum.trim() == localOrderNum) {
          return index;
        }
      }
    }

    final localDeviceId = localEntry.deviceId?.trim() ?? '';
    if (localDeviceId.isNotEmpty) {
      for (var index = 0; index < displayEntries.length; index++) {
        final candidate = displayEntries[index];
        final candidateDeviceId = candidate.deviceId?.trim() ?? '';
        if (candidateDeviceId.isEmpty || candidateDeviceId != localDeviceId) {
          continue;
        }

        final diffSeconds = candidate.createdAt
            .difference(localEntry.createdAt)
            .inSeconds
            .abs();
        if (diffSeconds <= 3 * 24 * 60 * 60) {
          return index;
        }
      }
    }

    for (var index = 0; index < displayEntries.length; index++) {
      final candidate = displayEntries[index];
      if (!_historyNamesLikelySame(
        candidate.displayDeviceName,
        localEntry.displayDeviceName,
      )) {
        continue;
      }

      final diffSeconds = candidate.minutePrecisionTime
          .difference(localEntry.minutePrecisionTime)
          .inSeconds
          .abs();
      if (diffSeconds > 12 * 60 * 60) {
        continue;
      }
      return index;
    }

    return null;
  }

  void _incrementUsageCount(
    String deviceId,
    String orderNum, {
    DateTime? createdAt,
    double? amount,
  }) {
    final resolvedDeviceId = deviceId.trim();
    if (resolvedDeviceId.isEmpty) {
      return;
    }

    final usageKey = _usageCountKey(
      orderNum: orderNum,
      deviceId: resolvedDeviceId,
      createdAt: createdAt,
      amount: amount,
    );
    if (_countedUsageOrderNums.contains(usageKey)) {
      return;
    }

    _countedUsageOrderNums.add(usageKey);
    _deviceUsageCounts[resolvedDeviceId] =
        (_deviceUsageCounts[resolvedDeviceId] ?? 0) + 1;
  }

  void _reconcileUsageCountsFromEntries(
    Iterable<WaterUsageHistoryEntry> entries,
  ) {
    for (final entry in entries) {
      final deviceId = entry.deviceId?.trim() ?? '';
      if (deviceId.isEmpty) {
        continue;
      }
      _incrementUsageCount(
        deviceId,
        entry.orderNum,
        createdAt: entry.createdAt,
        amount: entry.amount,
      );
    }
  }

  String _usageCountKey({
    required String orderNum,
    required String deviceId,
    DateTime? createdAt,
    double? amount,
  }) {
    final trimmedOrderNum = orderNum.trim();
    if (trimmedOrderNum.isNotEmpty) {
      return 'order:$trimmedOrderNum';
    }
    final timeKey = (createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
        .toIso8601String();
    final amountKey = (amount ?? 0).toStringAsFixed(2);
    return 'device:$deviceId|$timeKey|$amountKey';
  }

  Future<void> _migrateLegacyHistoryIfNeeded(
    SharedPreferences prefs, {
    List<WaterUsageHistoryEntry> legacyLocalDurationRecords =
        const <WaterUsageHistoryEntry>[],
  }) async {
    var changed = false;
    final currentMonthKey = _currentMonthKey();

    final legacyDisplayHistory = _decodeHistoryEntries(
      prefs.getStringList(_displayHistoryStorageKey),
    );
    if (_monthlyServerHistoryCache.isEmpty && legacyDisplayHistory.isNotEmpty) {
      _monthlyServerHistoryCache[currentMonthKey] = legacyDisplayHistory
          .where((entry) => !entry.isLocalOnly)
          .toList(growable: false);
      _syncedHistoryMonths.add(currentMonthKey);
      changed = true;
    }

    final legacyHistory = _decodeHistoryEntries(
      prefs.getStringList(_legacyHistoryStorageKey),
    );
    final migratedDurationRecords = _mergeLocalDurationRecords([
      ...legacyLocalDurationRecords,
      ..._extractLocalDurationRecordsFromLegacy(legacyHistory),
    ]);
    if (legacyHistory.isNotEmpty || migratedDurationRecords.isNotEmpty) {
      if (_monthlyServerHistoryCache.isEmpty) {
        final legacyServerEntries = legacyHistory
            .where((entry) => !entry.isLocalOnly)
            .toList(growable: false);
        if (legacyServerEntries.isNotEmpty) {
          _monthlyServerHistoryCache[currentMonthKey] = legacyServerEntries;
          _syncedHistoryMonths.add(currentMonthKey);
          changed = true;
        }
      }

      final beforeLocal = List<WaterUsageHistoryEntry>.from(_localDurationRecords);
      _ingestDurationRecords(migratedDurationRecords);
      if (!_historyListsEqual(beforeLocal, _localDurationRecords)) {
        changed = true;
      }
    }

    if (changed) {
      await _persistHistoryCaches(prefs: prefs);
    }
  }

  Future<void> _persistHistoryCaches({
    SharedPreferences? prefs,
    bool markSchemaCurrent = false,
  }) async {
    final resolvedPrefs = prefs ?? await SharedPreferences.getInstance();
    final monthCachePayload = <String, List<Map<String, dynamic>>>{};

    for (final entry in _monthlyServerHistoryCache.entries) {
      monthCachePayload[entry.key] = entry.value
          .map((item) => item.toJson())
          .toList(growable: false);
    }

    await resolvedPrefs.setString(
      _historyMonthCacheKey,
      jsonEncode(monthCachePayload),
    );
    final patchPayload = <String, Map<String, dynamic>>{};
    for (final entry in _durationPatches.entries) {
      patchPayload[entry.key] = entry.value.toJson();
    }
    _historyPatchLinks.removeWhere(
      (_, patchKey) => !_durationPatches.containsKey(patchKey),
    );
    await resolvedPrefs.setString(
      _durationPatchStorageKey,
      jsonEncode(patchPayload),
    );
    await resolvedPrefs.setString(
      _historyPatchLinksKey,
      jsonEncode(_historyPatchLinks),
    );
    await resolvedPrefs.setString(
      _deviceUsageStatsKey,
      jsonEncode(_deviceUsageCounts),
    );
    await resolvedPrefs.setStringList(
      _countedUsageOrderNumsKey,
      _countedUsageOrderNums.toList()..sort(),
    );
    await resolvedPrefs.setStringList(
      _localDurationStorageKey,
      _localDurationRecords.map((entry) => jsonEncode(entry.toJson())).toList(),
    );
    await resolvedPrefs.setString(
      _historySelectedMonthKey,
      selectedHistoryMonthKey,
    );
    await resolvedPrefs.setStringList(
      _historySyncedMonthsKey,
      _syncedHistoryMonths.toList()..sort(),
    );

    if (markSchemaCurrent) {
      await resolvedPrefs.setInt(
        _historySchemaVersionKey,
        _historySchemaVersion,
      );
    }
  }

  Future<void> _persistSelectedHistoryMonth({
    SharedPreferences? prefs,
  }) async {
    final resolvedPrefs = prefs ?? await SharedPreferences.getInstance();
    await resolvedPrefs.setString(
      _historySelectedMonthKey,
      selectedHistoryMonthKey,
    );
  }

  Map<String, List<WaterUsageHistoryEntry>> _decodeMonthlyHistoryCache(
    String? raw,
  ) {
    if (raw == null || raw.trim().isEmpty) {
      return <String, List<WaterUsageHistoryEntry>>{};
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return <String, List<WaterUsageHistoryEntry>>{};
      }

      final result = <String, List<WaterUsageHistoryEntry>>{};
      for (final entry in decoded.entries) {
        final monthKey = entry.key.toString();
        final value = entry.value;
        if (value is! List) {
          continue;
        }
        final monthEntries = <WaterUsageHistoryEntry>[];
        for (final item in value) {
          if (item is Map<String, dynamic>) {
            monthEntries.add(WaterUsageHistoryEntry.fromJson(item));
            continue;
          }
          if (item is Map) {
            monthEntries.add(
              WaterUsageHistoryEntry.fromJson(Map<String, dynamic>.from(item)),
            );
            continue;
          }
          if (item is String) {
            monthEntries.add(WaterUsageHistoryEntry.fromStorage(item));
          }
        }
        monthEntries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        result[monthKey] = monthEntries;
      }
      return result;
    } catch (_) {
      return <String, List<WaterUsageHistoryEntry>>{};
    }
  }

  List<WaterUsageHistoryEntry> _decodeHistoryEntries(List<String>? rawEntries) {
    if (rawEntries == null || rawEntries.isEmpty) {
      return <WaterUsageHistoryEntry>[];
    }
    return rawEntries.map(WaterUsageHistoryEntry.fromStorage).toList();
  }

  Map<String, WaterUsageHistoryEntry> _decodeDurationPatches(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return <String, WaterUsageHistoryEntry>{};
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return <String, WaterUsageHistoryEntry>{};
      }

      final result = <String, WaterUsageHistoryEntry>{};
      for (final entry in decoded.entries) {
        final patchKey = entry.key.toString();
        final value = entry.value;
        WaterUsageHistoryEntry? patch;
        if (value is Map<String, dynamic>) {
          patch = WaterUsageHistoryEntry.fromJson(value);
        } else if (value is Map) {
          patch = WaterUsageHistoryEntry.fromJson(
            Map<String, dynamic>.from(value),
          );
        } else if (value is String) {
          patch = WaterUsageHistoryEntry.fromStorage(value);
        }

        if (patch != null) {
          result[patchKey] = _asLocalDurationRecord(patch);
        }
      }
      return result;
    } catch (_) {
      return <String, WaterUsageHistoryEntry>{};
    }
  }

  Map<String, String> _decodeStringMap(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return <String, String>{};
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return <String, String>{};
      }
      return decoded.map<String, String>(
        (key, value) => MapEntry(key.toString(), value.toString()),
      );
    } catch (_) {
      return <String, String>{};
    }
  }

  Map<String, int> _decodeIntMap(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return <String, int>{};
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return <String, int>{};
      }
      return decoded.map<String, int>(
        (key, value) => MapEntry(
          key.toString(),
          value is num ? value.toInt() : (int.tryParse(value.toString()) ?? 0),
        ),
      );
    } catch (_) {
      return <String, int>{};
    }
  }

  List<WaterUsageHistoryEntry> _extractLocalDurationRecordsFromLegacy(
    List<WaterUsageHistoryEntry> legacyHistory,
  ) {
    return _mergeLocalDurationRecords(
      legacyHistory
          .where(
            (entry) =>
                entry.isLocalOnly ||
                _hasDuration(entry) ||
                entry.orderNum.trim().isNotEmpty,
          )
          .map(_asLocalDurationRecord),
    );
  }

  WaterUsageHistoryEntry _asLocalDurationRecord(WaterUsageHistoryEntry entry) {
    return entry.copyWith(
      isLocalOnly: true,
      durationLabel: _durationLabelForMerge(entry),
    );
  }

  void _upsertLocalDurationRecord(WaterUsageHistoryEntry entry) {
    _upsertDurationPatch(entry);
  }

  void _upsertDurationPatch(
    WaterUsageHistoryEntry entry, {
    bool rebuildList = true,
  }) {
    final localEntry = _asLocalDurationRecord(entry);
    final patchKey = _durationPatchKey(localEntry);
    final existing = _durationPatches[patchKey];
    final mergedEntry = existing == null
        ? localEntry
        : _preferHistoryEntry(existing, localEntry).copyWith(
            isLocalOnly: true,
            durationLabel: _durationLabelForMerge(
              _preferHistoryEntry(existing, localEntry),
            ),
          );
    _durationPatches[patchKey] = mergedEntry;
    if (rebuildList) {
      _rebuildLocalDurationRecordsFromPatches();
    }
  }

  void _ingestDurationRecords(Iterable<WaterUsageHistoryEntry> entries) {
    for (final entry in entries) {
      _upsertDurationPatch(entry, rebuildList: false);
    }
    _rebuildLocalDurationRecordsFromPatches();
  }

  void _rebuildLocalDurationRecordsFromPatches() {
    _localDurationRecords = _mergeLocalDurationRecords(_durationPatches.values);
  }

  List<WaterUsageHistoryEntry> _mergeLocalDurationRecords(
    Iterable<WaterUsageHistoryEntry> entries,
  ) {
    final deduped = <String, WaterUsageHistoryEntry>{};
    for (final entry in entries) {
      final localEntry = _asLocalDurationRecord(entry);
      final key = _historyMergeKey(localEntry);
      final existing = deduped[key];
      if (existing == null) {
        deduped[key] = localEntry;
        continue;
      }

      final mergedEntry = _preferHistoryEntry(existing, localEntry);
      deduped[key] = mergedEntry.copyWith(
        isLocalOnly: true,
        durationLabel: _durationLabelForMerge(mergedEntry),
      );
    }

    final merged = deduped.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return merged;
  }

  List<WaterUsageHistoryEntry> _buildUsageHistory() {
    final merged = <String, WaterUsageHistoryEntry>{};

    for (final entry in _localDurationRecords) {
      merged[_historyMergeKey(entry)] = entry;
    }

    final sortedMonthKeys = _monthlyServerHistoryCache.keys.toList()
      ..sort((a, b) => _monthDate(b).compareTo(_monthDate(a)));

    for (final monthKey in sortedMonthKeys) {
      final monthEntries = _mergeServerEntriesWithLocalDurations(
        serverEntries:
            _monthlyServerHistoryCache[monthKey] ??
            const <WaterUsageHistoryEntry>[],
      );
      for (final entry in monthEntries) {
        final key = _historyMergeKey(entry);
        final existing = merged[key];
        if (existing == null) {
          merged[key] = entry;
          continue;
        }
        merged[key] = _preferHistoryEntry(existing, entry);
      }
    }

    final usageHistory = merged.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return usageHistory;
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
        ? '\u70ed\u6c34'
        : '\u76f4\u996e\u6c34';
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

  List<WaterUsageHistoryEntry> _mergeServerEntriesWithLocalDurations({
    required List<WaterUsageHistoryEntry> serverEntries,
    bool rememberLinks = false,
  }) {
    if (serverEntries.isEmpty) {
      return <WaterUsageHistoryEntry>[];
    }

    final merged = <WaterUsageHistoryEntry>[];
    final usedPatchKeys = <String>{};

    for (final serverEntry in serverEntries) {
      final localEntry = _resolveDurationPatchForServerEntry(
        serverEntry: serverEntry,
        usedPatchKeys: usedPatchKeys,
        rememberLink: rememberLinks,
      );
      if (localEntry == null) {
        merged.add(serverEntry);
        continue;
      }

      merged.add(
        serverEntry.copyWith(
          durationSeconds: localEntry.durationSeconds ?? serverEntry.durationSeconds,
          durationLabel:
              _durationLabelForMerge(localEntry) ??
              _durationLabelForMerge(serverEntry),
          deviceId: localEntry.deviceId ?? serverEntry.deviceId,
        ),
      );
    }

    final deduped = <String, WaterUsageHistoryEntry>{};
    for (final entry in merged) {
      final key = _historyMergeKey(entry);
      final existing = deduped[key];
      if (existing == null) {
        deduped[key] = entry;
        continue;
      }
      deduped[key] = _preferHistoryEntry(existing, entry);
    }

    final result = deduped.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result;
  }

  WaterUsageHistoryEntry? _resolveDurationPatchForServerEntry({
    required WaterUsageHistoryEntry serverEntry,
    required Set<String> usedPatchKeys,
    bool rememberLink = false,
  }) {
    final directPatchKey = _directPatchKeyForOrder(serverEntry.orderNum);
    if (directPatchKey != null &&
        !usedPatchKeys.contains(directPatchKey) &&
        _durationPatches.containsKey(directPatchKey)) {
      usedPatchKeys.add(directPatchKey);
      if (rememberLink) {
        _historyPatchLinks[_serverPatchLinkKey(serverEntry)] = directPatchKey;
      }
      return _durationPatches[directPatchKey];
    }

    final linkedPatchKey = _historyPatchLinks[_serverPatchLinkKey(serverEntry)];
    if (linkedPatchKey != null &&
        !usedPatchKeys.contains(linkedPatchKey) &&
        _durationPatches.containsKey(linkedPatchKey)) {
      usedPatchKeys.add(linkedPatchKey);
      return _durationPatches[linkedPatchKey];
    }

    final devicePatchKey = _findBestPatchByDeviceId(
      target: serverEntry,
      usedPatchKeys: usedPatchKeys,
    );
    if (devicePatchKey != null) {
      usedPatchKeys.add(devicePatchKey);
      if (rememberLink) {
        _historyPatchLinks[_serverPatchLinkKey(serverEntry)] = devicePatchKey;
      }
      return _durationPatches[devicePatchKey];
    }

    final bestPatchKey = _findBestLocalHistoryMatch(
      target: serverEntry,
      usedPatchKeys: usedPatchKeys,
    );
    if (bestPatchKey == null) {
      return null;
    }

    usedPatchKeys.add(bestPatchKey);
    if (rememberLink) {
      _historyPatchLinks[_serverPatchLinkKey(serverEntry)] = bestPatchKey;
    }
    return _durationPatches[bestPatchKey];
  }

  String _historyMergeKey(WaterUsageHistoryEntry entry) {
    final orderKey = entry.orderNum.trim();
    if (orderKey.isNotEmpty) {
      return 'order:$orderKey';
    }

    final normalizedName = _historySignature(entry.displayDeviceName);
    final amountKey = entry.amount.toStringAsFixed(2);
    final timeKey = entry.minutePrecisionTime.toIso8601String();
    return 'fallback:$normalizedName|$amountKey|$timeKey';
  }

  String _durationPatchKey(WaterUsageHistoryEntry entry) {
    final directKey = _directPatchKeyForOrder(entry.orderNum);
    if (directKey != null) {
      return directKey;
    }

    final normalizedName = _historySignature(entry.displayDeviceName);
    final timeKey = entry.createdAt.toIso8601String();
    return 'patch:$normalizedName|$timeKey';
  }

  String? _directPatchKeyForOrder(String orderNum) {
    final trimmed = orderNum.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return 'order:$trimmed';
  }

  String _serverPatchLinkKey(WaterUsageHistoryEntry entry) {
    final orderKey = entry.orderNum.trim();
    if (orderKey.isNotEmpty) {
      return 'bill-order:$orderKey';
    }

    final deviceId = entry.deviceId?.trim() ?? '';
    if (deviceId.isNotEmpty) {
      return 'bill-device:$deviceId|${entry.minutePrecisionTime.toIso8601String()}';
    }

    final normalizedName = _historySignature(entry.displayDeviceName);
    final amountKey = entry.amount.toStringAsFixed(2);
    final timeKey = entry.minutePrecisionTime.toIso8601String();
    return 'bill:$normalizedName|$amountKey|$timeKey';
  }

  WaterUsageHistoryEntry _preferHistoryEntry(
    WaterUsageHistoryEntry current,
    WaterUsageHistoryEntry candidate,
  ) {
    if (current.isLocalOnly && !candidate.isLocalOnly) {
      return candidate.copyWith(
        durationSeconds: candidate.durationSeconds ?? current.durationSeconds,
        durationLabel: _durationLabelForMerge(current) ?? candidate.durationLabel,
        deviceId: candidate.deviceId ?? current.deviceId,
        isLocalOnly: false,
      );
    }
    if (!current.isLocalOnly && candidate.isLocalOnly) {
      return current.copyWith(
        durationSeconds: current.durationSeconds ?? candidate.durationSeconds,
        durationLabel: current.durationLabel ?? _durationLabelForMerge(candidate),
        deviceId: current.deviceId ?? candidate.deviceId,
        isLocalOnly: false,
      );
    }

    final currentHasDuration = _hasDuration(current);
    final candidateHasDuration = _hasDuration(candidate);
    if (candidateHasDuration && !currentHasDuration) {
      return candidate;
    }
    if (currentHasDuration && !candidateHasDuration) {
      return current;
    }

    final currentHasOrder = current.orderNum.trim().isNotEmpty;
    final candidateHasOrder = candidate.orderNum.trim().isNotEmpty;
    if (candidateHasOrder && !currentHasOrder) {
      return candidate;
    }
    if (currentHasOrder && !candidateHasOrder) {
      return current;
    }

    return candidate.createdAt.isAfter(current.createdAt) ? candidate : current;
  }

  bool _hasDuration(WaterUsageHistoryEntry entry) {
    final label = entry.durationLabel?.trim() ?? '';
    return entry.durationSeconds != null || (label.isNotEmpty && label != '--');
  }

  String? _findBestLocalHistoryMatch({
    required WaterUsageHistoryEntry target,
    required Set<String> usedPatchKeys,
  }) {
    String? bestPatchKey;
    double? bestScore;
    final targetAmount = target.amount;
    final targetMinute = target.minutePrecisionTime;

    for (final entry in _durationPatches.entries) {
      final patchKey = entry.key;
      if (usedPatchKeys.contains(patchKey)) {
        continue;
      }

      final candidate = entry.value;
      if (!_historyNamesLikelySame(
        target.displayDeviceName,
        candidate.displayDeviceName,
      )) {
        continue;
      }

      final diffSeconds = candidate.minutePrecisionTime
          .difference(targetMinute)
          .inSeconds
          .abs();
      if (diffSeconds > 12 * 60 * 60) {
        continue;
      }

      final amountDiff = (candidate.amount - targetAmount).abs();
      final score = diffSeconds + (amountDiff * 600);
      if (bestScore != null && score >= bestScore!) {
        continue;
      }

      bestPatchKey = patchKey;
      bestScore = score;
    }

    return bestPatchKey;
  }

  String? _findBestPatchByDeviceId({
    required WaterUsageHistoryEntry target,
    required Set<String> usedPatchKeys,
  }) {
    final targetDeviceId = target.deviceId?.trim() ?? '';
    if (targetDeviceId.isEmpty) {
      return null;
    }

    String? bestPatchKey;
    int? bestDiffSeconds;
    for (final entry in _durationPatches.entries) {
      final patchKey = entry.key;
      if (usedPatchKeys.contains(patchKey)) {
        continue;
      }

      final candidate = entry.value;
      final candidateDeviceId = candidate.deviceId?.trim() ?? '';
      if (candidateDeviceId.isEmpty || candidateDeviceId != targetDeviceId) {
        continue;
      }

      final diffSeconds = candidate.createdAt
          .difference(target.createdAt)
          .inSeconds
          .abs();
      if (diffSeconds > 3 * 24 * 60 * 60) {
        continue;
      }

      if (bestDiffSeconds != null && diffSeconds >= bestDiffSeconds!) {
        continue;
      }

      bestPatchKey = patchKey;
      bestDiffSeconds = diffSeconds;
    }

    return bestPatchKey;
  }

  String? _durationLabelForMerge(WaterUsageHistoryEntry entry) {
    final rawLabel = entry.durationLabel?.trim() ?? '';
    if (rawLabel.isNotEmpty && rawLabel != '--') {
      return rawLabel;
    }

    final derived = entry.formattedDuration.trim();
    if (derived.isEmpty || derived == '--') {
      return null;
    }
    return derived;
  }

  String _normalizeHistoryDeviceName(String name) {
    var normalized = name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');
    normalized = normalized.replaceAll('hot', '\u70ed\u6c34');
    normalized = normalized.replaceAll('cold', '\u76f4\u996e');
    normalized = normalized.replaceAll('drink', '\u76f4\u996e');
    normalized = normalized.replaceAll('\u76f4\u996e\u6c34', '\u76f4\u996e');
    normalized = normalized.replaceAll(
      '\u8bbe\u5907\u7528\u6c34',
      '\u70ed\u6c34',
    );
    normalized = normalized.replaceAll('\u6d17\u6d74', '\u70ed\u6c34');
    return normalized;
  }

  String _localHistoryDeviceName(Map<String, dynamic> device) {
    final rawName = (device['deviceInfName'] ?? device['deviceName'] ?? '')
        .toString()
        .replaceFirst(RegExp(r'^[12]-'), '');
    final suffix = device['billType'] == 2 ? '\u70ed\u6c34' : '\u76f4\u996e';
    if (rawName.isEmpty) {
      return suffix;
    }
    return '$rawName$suffix';
  }

  bool _historyNamesLikelySame(String left, String right) {
    final leftNormalized = _normalizeHistoryDeviceName(left);
    final rightNormalized = _normalizeHistoryDeviceName(right);
    if (leftNormalized == rightNormalized) {
      return true;
    }

    final leftSignature = _historySignature(leftNormalized);
    final rightSignature = _historySignature(rightNormalized);
    if (leftSignature == rightSignature) {
      return true;
    }

    final leftType = _historyType(leftNormalized);
    final rightType = _historyType(rightNormalized);
    final leftRoom = _historyRoomToken(leftNormalized);
    final rightRoom = _historyRoomToken(rightNormalized);
    return leftType.isNotEmpty &&
        leftType == rightType &&
        leftRoom.isNotEmpty &&
        leftRoom == rightRoom;
  }

  String _historySignature(String name) {
    final normalized = _normalizeHistoryDeviceName(name);
    final room = _historyRoomToken(normalized);
    final type = _historyType(normalized);
    if (room.isNotEmpty || type.isNotEmpty) {
      return '$room|$type';
    }
    return normalized;
  }

  String _historyRoomToken(String normalized) {
    final matches = RegExp(r'(\d{2,})').allMatches(normalized).toList();
    if (matches.isEmpty) {
      return '';
    }
    return matches.last.group(1) ?? '';
  }

  String _historyType(String normalized) {
    if (normalized.contains('\u70ed\u6c34')) {
      return '\u70ed\u6c34';
    }
    if (normalized.contains('\u76f4\u996e')) {
      return '\u76f4\u996e';
    }
    return '';
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
    return '${minutes}\u5206${seconds}\u79d2';
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

  String _monthKey(int year, int month) {
    return '$year-${month.toString().padLeft(2, '0')}';
  }

  String _monthKeyForDate(DateTime date) {
    return _monthKey(date.year, date.month);
  }

  String _currentMonthKey() {
    final now = DateTime.now();
    return _monthKey(now.year, now.month);
  }

  DateTime _monthDate(String monthKey) {
    final parts = monthKey.split('-');
    if (parts.length != 2) {
      return DateTime.now();
    }
    final year = int.tryParse(parts[0]) ?? DateTime.now().year;
    final month = int.tryParse(parts[1]) ?? DateTime.now().month;
    return DateTime(year, month);
  }

  bool _isFutureMonth(int year, int month) {
    final now = DateTime.now();
    if (year > now.year) {
      return true;
    }
    if (year == now.year && month > now.month) {
      return true;
    }
    return false;
  }

  bool _isMonthKeyInFuture(String monthKey) {
    final date = _monthDate(monthKey);
    return _isFutureMonth(date.year, date.month);
  }

  bool _historyListsEqual(
    List<WaterUsageHistoryEntry> left,
    List<WaterUsageHistoryEntry> right,
  ) {
    if (left.length != right.length) {
      return false;
    }
    for (var i = 0; i < left.length; i++) {
      if (jsonEncode(left[i].toJson()) != jsonEncode(right[i].toJson())) {
        return false;
      }
    }
    return true;
  }
}
