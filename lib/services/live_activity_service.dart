import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class LiveActivityService {
  LiveActivityService._();

  static const MethodChannel _channel = MethodChannel(
    'com.fakeuy.water/live_activity',
  );

  static Future<void> startWater({
    required String deviceId,
    required String deviceName,
    required String orderNum,
    required DateTime startTime,
  }) async {
    await _invoke(
      'startWater',
      {
        'deviceId': deviceId,
        'deviceName': deviceName,
        'orderNum': orderNum,
        'startTimeMillis': startTime.millisecondsSinceEpoch,
        'elapsedSeconds': 0,
      },
    );
  }

  static Future<void> updateWater({
    required String orderNum,
    required DateTime startTime,
    required int elapsedSeconds,
    String statusText = '正在用水',
  }) async {
    await _invoke(
      'updateWater',
      {
        'orderNum': orderNum,
        'startTimeMillis': startTime.millisecondsSinceEpoch,
        'elapsedSeconds': elapsedSeconds,
        'statusText': statusText,
        'isRunning': true,
      },
    );
  }

  static Future<void> endWater({
    required String orderNum,
    required int elapsedSeconds,
    String amountText = '',
  }) async {
    await _invoke(
      'endWater',
      {
        'orderNum': orderNum,
        'elapsedSeconds': elapsedSeconds,
        'amountText': amountText,
      },
    );
  }

  static Future<void> _invoke(String method, Map<String, Object> args) async {
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }

    try {
      await _channel.invokeMethod<void>(method, args);
    } on MissingPluginException catch (error) {
      debugPrint('Live activity channel is not ready: $error');
    } on PlatformException catch (error) {
      debugPrint('Live activity $method failed: ${error.message}');
    } catch (error, stackTrace) {
      debugPrint('Live activity $method failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}
