import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class ShortcutContextService {
  ShortcutContextService._();

  static const MethodChannel _channel = MethodChannel(
    'com.fakeuy.water/shortcut_context',
  );

  static Future<void> syncAuthContext({
    required String token,
    required String userId,
    required String balance,
  }) async {
    await _invoke('syncAuthContext', {
      'token': token,
      'userId': userId,
      'balance': balance,
    });
  }

  static Future<void> syncDeviceCatalog({
    required List<Map<String, dynamic>> devices,
    required Map<String, String> customRemarks,
  }) async {
    final payload = devices
        .map((device) {
          final id = device['deviceInfId']?.toString() ?? '';
          final rawName = device['deviceInfName']?.toString() ?? '';
          final displayName = customRemarks[id]?.trim().isNotEmpty == true
              ? customRemarks[id]!.trim()
              : rawName.replaceFirst(RegExp(r'^[12]-'), '');
          return {
            'id': id,
            'name': displayName,
            'billType': int.tryParse(device['billType']?.toString() ?? '') ?? 2,
          };
        })
        .where((device) => (device['id'] as String).isNotEmpty)
        .toList(growable: false);

    await _invoke('syncDeviceCatalog', {'devicesJson': jsonEncode(payload)});
  }

  static Future<void> setDefaultDevice(String deviceId) async {
    await _invoke('setDefaultDevice', {'deviceId': deviceId});
  }

  static Future<void> clearShortcutContext() async {
    await _invoke('clearShortcutContext', const <String, Object>{});
  }

  static Future<ShortcutWaterSessionSnapshot?> getWaterSessionSnapshot() async {
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      return null;
    }

    try {
      final result = await _channel.invokeMethod<Object?>(
        'getWaterSessionSnapshot',
        const <String, Object>{},
      );
      if (result is Map) {
        return ShortcutWaterSessionSnapshot.fromMap(
          Map<String, dynamic>.from(result),
        );
      }
    } on MissingPluginException catch (error) {
      debugPrint('Shortcut context channel is not ready: $error');
    } on PlatformException catch (error) {
      debugPrint('Shortcut context snapshot failed: ${error.message}');
    } catch (error, stackTrace) {
      debugPrint('Shortcut context snapshot failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
    return null;
  }

  static Future<void> consumeFinishedWaterSession(String orderNum) async {
    await _invoke('consumeFinishedWaterSession', {'orderNum': orderNum});
  }

  static Future<void> _invoke(String method, Map<String, Object> args) async {
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }

    try {
      await _channel.invokeMethod<void>(method, args);
    } on MissingPluginException catch (error) {
      debugPrint('Shortcut context channel is not ready: $error');
    } on PlatformException catch (error) {
      debugPrint('Shortcut context $method failed: ${error.message}');
    } catch (error, stackTrace) {
      debugPrint('Shortcut context $method failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}

class ShortcutWaterSessionSnapshot {
  const ShortcutWaterSessionSnapshot({
    required this.state,
    required this.orderNum,
    required this.tableName,
    required this.mac,
    required this.deviceId,
    required this.deviceName,
    required this.billType,
    required this.startedAtMs,
    required this.initialBalance,
    required this.elapsedSeconds,
    required this.amount,
    required this.amountText,
    required this.balance,
  });

  final String state;
  final String orderNum;
  final String tableName;
  final String mac;
  final String deviceId;
  final String deviceName;
  final int billType;
  final int startedAtMs;
  final String initialBalance;
  final int elapsedSeconds;
  final double amount;
  final String amountText;
  final String balance;

  bool get isRunning => state == 'running' && orderNum.isNotEmpty;
  bool get isFinished => state == 'finished' && orderNum.isNotEmpty;

  DateTime get startedAt => startedAtMs > 0
      ? DateTime.fromMillisecondsSinceEpoch(startedAtMs)
      : DateTime.now();

  factory ShortcutWaterSessionSnapshot.fromMap(Map<String, dynamic> map) {
    return ShortcutWaterSessionSnapshot(
      state: map['state']?.toString() ?? 'none',
      orderNum: map['orderNum']?.toString() ?? '',
      tableName: map['tableName']?.toString() ?? '',
      mac: map['mac']?.toString() ?? '',
      deviceId: map['deviceId']?.toString() ?? '',
      deviceName: map['deviceName']?.toString() ?? '',
      billType: _intValue(map['billType']),
      startedAtMs: _intValue(map['startedAtMs']),
      initialBalance: map['initialBalance']?.toString() ?? '',
      elapsedSeconds: _intValue(map['elapsedSeconds']),
      amount: _doubleValue(map['amount']),
      amountText: map['amountText']?.toString() ?? '',
      balance: map['balance']?.toString() ?? '',
    );
  }

  static int _intValue(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is double) {
      return value.round();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _doubleValue(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    final filtered = (value?.toString() ?? '').replaceAll(
      RegExp(r'[^0-9.\-]'),
      '',
    );
    return double.tryParse(filtered) ?? 0;
  }
}
