import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/water_usage_history_entry.dart';
import '../../providers/device_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/water_provider.dart';
import '../../services/api_service.dart';
import '../../core/toast_service.dart';

/// iOS renders the entire interface in SwiftUI. This adapter deliberately keeps
/// authentication, device commands and history reconciliation in their existing
/// providers; credentials are never included in the native view snapshot.
class NativeWaterPage extends StatefulWidget {
  const NativeWaterPage({super.key, required this.ready});
  final bool ready;

  @override
  State<NativeWaterPage> createState() => _NativeWaterPageState();
}

class _NativeWaterPageState extends State<NativeWaterPage> {
  MethodChannel? _channel;
  UserProvider? _user;
  DeviceProvider? _devices;
  WaterProvider? _water;
  bool _scheduled = false;
  bool _fullPending = true;
  final Set<String> _commands = {};
  String _lastOrder = '';
  bool _lastHistoryLoading = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarBrightness: Brightness.dark,
        statusBarIconBrightness: Brightness.light,
        statusBarColor: Colors.transparent,
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = context.read<UserProvider>();
    final devices = context.read<DeviceProvider>();
    final water = context.read<WaterProvider>();
    if (!identical(_user, user)) {
      _user?.removeListener(_dataChanged);
      _user = user..addListener(_dataChanged);
    }
    if (!identical(_devices, devices)) {
      _devices?.removeListener(_dataChanged);
      _devices = devices..addListener(_dataChanged);
    }
    if (!identical(_water, water)) {
      _water?.removeListener(_waterChanged);
      _water = water..addListener(_waterChanged);
    }
  }

  @override
  void didUpdateWidget(covariant NativeWaterPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ready != widget.ready) _dataChanged();
  }

  void _dataChanged() => _scheduleSnapshot(full: true);

  void _waterChanged() {
    final water = _water!;
    final full =
        _lastOrder != water.orderNum ||
        _lastHistoryLoading != water.isHistoryLoading;
    _lastOrder = water.orderNum;
    _lastHistoryLoading = water.isHistoryLoading;
    _scheduleSnapshot(full: full);
  }

  void _scheduleSnapshot({required bool full}) {
    _fullPending = _fullPending || full;
    if (_scheduled || _channel == null) return;
    _scheduled = true;
    scheduleMicrotask(() {
      _scheduled = false;
      if (!mounted || _channel == null) return;
      final includeData = _fullPending;
      _fullPending = false;
      unawaited(
        _channel!
            .invokeMethod<void>('state', _snapshot(includeData))
            .catchError((Object error) {
              debugPrint('Native UI snapshot failed: $error');
            }),
      );
    });
  }

  Map<String, Object?> _record(WaterUsageHistoryEntry entry) => {
    'id':
        '${entry.orderNum}:${entry.createdAt.millisecondsSinceEpoch}:${entry.deviceId ?? entry.deviceName}',
    'name': entry.displayDeviceName,
    'amount': entry.amount,
    'date': entry.createdAt.millisecondsSinceEpoch,
    'duration': entry.formattedDuration,
    'seconds': entry.durationSeconds,
  };

  Map<String, Object?> _snapshot(bool full) {
    final user = _user!;
    final devices = _devices!;
    final water = _water!;
    final result = <String, Object?>{
      'ready': widget.ready,
      'loggedIn': user.token.isNotEmpty,
      'balance': user.balance,
      'busy': user.isRequesting || devices.isRequesting || water.isRequesting,
      'waterBusy': water.isRequesting,
      'historyLoading': water.isHistoryLoading || water.isHistoryBackfilling,
      'running': water.orderNum.isNotEmpty,
      'activeId': water.activeDeviceId,
      'selectedId': devices.selectedDeviceId,
      'runningTime': water.runningTime,
      'startedAt': water.startTime?.millisecondsSinceEpoch,
    };
    if (!full) return result;
    final history = water.history;
    final now = DateTime.now();
    final today = history.where(
      (entry) =>
          entry.createdAt.year == now.year &&
          entry.createdAt.month == now.month &&
          entry.createdAt.day == now.day,
    );
    result.addAll({
      'profile': {
        'name': user.userName,
        'phone': user.maskedPhone,
        'avatar': user.avatarUrl,
        'school': user.schoolName,
        'campus': user.campusName,
        'building': user.buildingName,
        'room': '${user.floorName} ${user.roomName}'.trim(),
        'address': user.addressInfo,
        'studentNo': user.studentNo,
        'grade': user.grade,
        'realName': user.isRealName,
      },
      'devices': devices.deviceList.map((device) {
        final id = device['deviceInfId'].toString();
        return {
          'id': id,
          'name':
              devices.customRemarks[id] ??
              device['deviceInfName'].toString().replaceFirst(
                RegExp(r'^[12]-'),
                '',
              ),
          'billType': int.tryParse(device['billType'].toString()) ?? 0,
          'count': water.deviceUsageCounts[id] ?? 0,
          'monthly': water.deviceMonthlyUsageCounts[id] ?? <String, int>{},
        };
      }).toList(),
      'records': water.displayHistory.map(_record).toList(),
      'recent': history.take(3).map(_record).toList(),
      'todaySeconds': today.fold<int>(
        0,
        (sum, entry) => sum + (entry.durationSeconds ?? 0),
      ),
      'todayCount': today.length,
      'lastDuration': history.isEmpty ? '' : history.first.formattedDuration,
      'historyYear': water.selectedHistoryYear,
      'historyMonth': water.selectedHistoryMonth,
      'historyYears': water.availableHistoryYears,
      'expandedStats': devices.isAlwaysExpanded,
    });
    return result;
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, String> params,
  ) async {
    final response = await ApiService.post(
      path,
      params,
      token: _user!.token,
      userId: _user!.userId,
      muteToast: true,
    );
    if (response == null || !{0, '0', 200, '200'}.contains(response['code'])) {
      throw StateError(response?['msg']?.toString() ?? '请求失败，请稍后重试');
    }
    return response;
  }

  Future<Object?> _action(MethodCall call) async {
    if (call.method != 'action') throw MissingPluginException();
    final args = Map<String, dynamic>.from(call.arguments as Map? ?? {});
    final action = args['name']?.toString() ?? '';
    final user = _user!;
    final devices = _devices!;
    final water = _water!;
    // Concurrent reads/palette extraction need not block a safety-critical stop.
    final readOnly = {
      'palette',
      'locations',
      'refresh',
      'history',
    }.contains(action);
    if (!widget.ready) {
      throw PlatformException(code: 'loading', message: '正在恢复本地数据');
    }
    final canStop =
        action == 'stop' && !_commands.any({'start', 'stop'}.contains);
    if (!readOnly && _commands.isNotEmpty && !canStop) {
      throw PlatformException(code: 'busy', message: '上一项操作尚未完成');
    }
    if (!{'palette', 'sendCode', 'login'}.contains(action) &&
        user.token.isEmpty) {
      throw PlatformException(code: 'login_required', message: '请先登录');
    }
    if (!readOnly) _commands.add(action);
    try {
      switch (action) {
        case 'palette':
          final bytes = args['image'];
          final scheme = bytes is Uint8List
              ? await ColorScheme.fromImageProvider(
                  provider: MemoryImage(bytes),
                  brightness: Brightness.dark,
                )
              : ColorScheme.fromSeed(
                  seedColor: Color(args['seed'] as int),
                  brightness: Brightness.dark,
                );
          return {
            'primary': scheme.primary.toARGB32(),
            'secondary': scheme.secondary.toARGB32(),
            'tertiary': scheme.tertiary.toARGB32(),
          };
        case 'sendCode':
          final phone = args['phone']?.toString() ?? '';
          if (!RegExp(r'^1\d{10}$').hasMatch(phone)) {
            throw StateError('请输入正确的手机号');
          }
          if (!await user.sendCode(phone)) throw StateError('验证码发送失败，请稍后重试');
          return true;
        case 'login':
          if (!await user.login(
            args['phone'].toString(),
            args['code'].toString(),
          )) {
            throw StateError('登录失败，请检查验证码');
          }
          await devices.loadFromLocal(user.token, user.userId);
          await devices.refreshDeviceListFromNet(user.token, user.userId);
          await water.syncHistoryFromServer(
            token: user.token,
            userId: user.userId,
            muteToast: true,
          );
          return true;
        case 'refresh':
          await user.syncBalance();
          await devices.refreshDeviceListFromNet(user.token, user.userId);
          await water.syncHistoryFromServer(
            token: user.token,
            userId: user.userId,
            muteToast: true,
          );
          return true;
        case 'select':
          final id = args['id'].toString();
          if (water.orderNum.isNotEmpty && id != water.activeDeviceId) {
            throw StateError('请先结束当前设备的用水');
          }
          if (!devices.deviceList.any(
            (d) => d['deviceInfId'].toString() == id,
          )) {
            throw StateError('设备不存在');
          }
          devices.selectDevice(id);
          return true;
        case 'start':
          if (water.orderNum.isNotEmpty) throw StateError('已有设备正在用水');
          final device = devices.deviceList.firstWhere(
            (d) => d['deviceInfId'].toString() == args['id'].toString(),
          );
          devices.selectDevice(device['deviceInfId'].toString());
          if (!await water.startWater(
            user.token,
            user.userId,
            device,
            currentBalance: user.balance,
          )) {
            throw StateError('未能开启设备，请重试');
          }
          return true;
        case 'stop':
          final device = devices.deviceList
              .where((d) => d['deviceInfId'].toString() == water.activeDeviceId)
              .firstOrNull;
          final id = water.activeDeviceId;
          final name =
              devices.customRemarks[id] ??
              device?['deviceInfName']?.toString() ??
              '设备';
          await water.stopWater(
            user.token,
            user.userId,
            name,
            currentBalance: user.balance,
            onBalanceUpdated: user.setBalance,
          );
          if (water.orderNum.isNotEmpty) throw StateError('设备尚未关闭，请重试');
          await water.syncHistoryFromServer(
            token: user.token,
            userId: user.userId,
            muteToast: true,
          );
          return true;
        case 'rename':
          final name = args['value']?.toString().trim() ?? '';
          if (name.isEmpty || name.length > 24) {
            throw StateError('设备名称需为 1–24 个字符');
          }
          await devices.saveDeviceRemark(args['id'].toString(), name);
          return true;
        case 'move':
          await devices.moveDeviceToPosition(
            args['id'].toString(),
            args['index'] as int,
          );
          return true;
        case 'default':
          await devices.setShortcutDefaultDevice(args['id'].toString());
          return true;
        case 'delete':
          final id = args['id'].toString();
          if (id == water.activeDeviceId && water.orderNum.isNotEmpty) {
            throw StateError('请先关闭该设备');
          }
          final device = devices.deviceList.firstWhere(
            (d) => d['deviceInfId'].toString() == id,
          );
          final commonly = device['commonlyId']?.toString() ?? '';
          if (commonly.isEmpty ||
              !await devices.deleteDevice(commonly, user.token, user.userId)) {
            throw StateError('删除失败，请刷新后重试');
          }
          return true;
        case 'expandedStats':
          devices.setAlwaysExpanded(args['value'] == true);
          return true;
        case 'history':
          final year = args['year'] as int;
          final month = args['month'] as int;
          final now = DateTime.now();
          if (month < 1 ||
              month > 12 ||
              year < 2000 ||
              DateTime(year, month).isAfter(DateTime(now.year, now.month))) {
            throw StateError('查询月份无效');
          }
          water.selectHistoryMonth(year, month);
          await water.syncHistoryMonth(
            token: user.token,
            userId: user.userId,
            year: year,
            month: month,
            muteToast: true,
          );
          return true;
        case 'clearHistory':
          await water.clearHistory();
          return true;
        case 'avatar':
          return await user.pickAndUploadAvatar();
        case 'logout':
          if (water.orderNum.isNotEmpty) throw StateError('请先结束用水再退出登录');
          await user.logout();
          // Do not leave the previous account's devices in the native snapshot.
          devices.deviceList = [];
          devices.customRemarks = {};
          devices.selectedDeviceId = '';
          await devices.loadFromLocal('', '');
          return true;
        case 'locations':
          final step = args['step'] as int;
          final response = await _post(
            step == 0 ? 'device/queryDeviceWay' : 'school/querySchoolAddress',
            step == 0 ? {'schId': '27720'} : {'deptId': args['id'].toString()},
          );
          final raw = response['data'];
          final list = raw is List
              ? raw
              : raw is Map
              ? raw.values.whereType<List>().firstOrNull ?? []
              : [];
          String extract(Map item, List<String> keys, String fallback) {
            for (final key in keys) {
              if (item[key] != null) return item[key].toString();
            }
            for (final key in item.keys) {
              if (key.toString().toLowerCase().contains(fallback)) {
                return item[key].toString();
              }
            }
            return '';
          }
          return list
              .whereType<Map>()
              .map(
                (item) => {
                  'id': extract(item, [
                    'deptId',
                    'deviceWayId',
                    'deviceNum',
                    'id',
                    'value',
                    'sn',
                  ], 'id'),
                  'name': extract(item, [
                    'deptName',
                    'wayName',
                    'deviceWayName',
                    'name',
                    'title',
                    'label',
                  ], 'name'),
                },
              )
              .where((item) => item['id']!.isNotEmpty)
              .toList();
        case 'bind':
          final response = await _post('device/queryDeviceInfo', {
            'deviceNum': args['id'].toString(),
            'schId': '27720',
            'deviceWayId': args['way'].toString(),
            'type': '4',
          });
          final data = response['data'];
          if (data is! Map || data['deviceInfId'] == null) {
            throw StateError('设备信息不完整');
          }
          await _post('device/operationDeviceCommonly', {
            'deviceTypeId': data['deviceTypeId']?.toString() ?? '',
            'deviceWayId':
                data['deviceWayId']?.toString() ?? args['way'].toString(),
            'deviceInfId': data['deviceInfId'].toString(),
            'type': '1',
          });
          await devices.refreshDeviceListFromNet(user.token, user.userId);
          return true;
        case 'scan':
          await _post('device/scanTheCode', {
            'deviceWayId': '0',
            'qrCode': args['code'].toString(),
          });
          await devices.refreshDeviceListFromNet(user.token, user.userId);
          return true;
        default:
          throw StateError('不支持的操作');
      }
    } catch (error) {
      throw PlatformException(
        code: 'action_failed',
        message: error is StateError
            ? error.message.toString()
            : '操作失败，请检查网络后重试',
      );
    } finally {
      if (!readOnly) _commands.remove(action);
      _dataChanged();
    }
  }

  @override
  void dispose() {
    _user?.removeListener(_dataChanged);
    _devices?.removeListener(_dataChanged);
    _water?.removeListener(_waterChanged);
    _channel?.setMethodCallHandler(null);
    ToastService.nativePresenter = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => UiKitView(
    viewType: 'com.fakeuy.water/native_ui',
    layoutDirection: TextDirection.ltr,
    onPlatformViewCreated: (id) {
      _channel = MethodChannel('com.fakeuy.water/native_ui_$id');
      _channel!.setMethodCallHandler(_action);
      ToastService.nativePresenter = (message, duration) {
        unawaited(
          _channel?.invokeMethod<void>('toast', {
            'message': message,
            'duration': duration,
          }),
        );
      };
      _dataChanged();
    },
  );
}
