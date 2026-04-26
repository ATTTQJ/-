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
