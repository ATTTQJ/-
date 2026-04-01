import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http2/http2.dart';

import '../core/toast_service.dart';

class ApiService {
  static const String _realSalt = 'e275f1af-1dda-4b47-9d87-afcbe1f96dca';
  static const String _domain = 'uyschool.uyxy.xin';

  static ClientTransportConnection? _sharedTransport;

  static Future<ClientTransportConnection> _getTransport() async {
    if (_sharedTransport != null && _sharedTransport!.isOpen) {
      return _sharedTransport!;
    }

    final socket = await SecureSocket.connect(
      _domain,
      443,
      supportedProtocols: ['h2'],
    ).timeout(const Duration(seconds: 10));
    _sharedTransport = ClientTransportConnection.viaSocket(socket);
    return _sharedTransport!;
  }

  static String _generateSign(
    String dateTime,
    Map<String, String> extra,
    String token,
    String userId,
  ) {
    final params = <String, String>{
      'AndroidVersionName': 'V2.9.2',
      'AndroidVersionCode': '92',
      'dateTime': dateTime,
      ...extra,
    };

    if (userId.trim().isNotEmpty) {
      params['userId'] = userId;
    }
    if (token.trim().isNotEmpty) {
      params['token'] = token;
    }

    params.removeWhere((key, value) => value.trim().isEmpty);
    final sortedKeys = params.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    var raw = sortedKeys.map((key) => '$key=${params[key]}').join('&');
    raw += token.trim().isNotEmpty ? '&$token' : '&$dateTime';
    raw += '&$_realSalt&292';
    return sha256.convert(utf8.encode(raw)).toString();
  }

  static Future<Map<String, dynamic>?> post(
    String path,
    Map<String, String> extra, {
    String token = '',
    String userId = '',
    int retry = 1,
    bool muteToast = false,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final sign = _generateSign(timestamp, extra, token, userId);

    final bodyBuffer = StringBuffer();
    for (final entry in extra.entries) {
      bodyBuffer.write('${entry.key}=${Uri.encodeComponent(entry.value)}&');
    }
    if (userId.trim().isNotEmpty) {
      bodyBuffer.write('userId=${Uri.encodeComponent(userId)}&');
    }
    if (token.trim().isNotEmpty) {
      bodyBuffer.write('token=$token&');
    }
    bodyBuffer.write(
      'AndroidVersionName=V2.9.2&AndroidVersionCode=92&sign=$sign&dateTime=$timestamp',
    );

    final bodyBytes = utf8.encode(bodyBuffer.toString());

    try {
      final transport = await _getTransport();
      final stream = transport.makeRequest([
        Header.ascii(':method', 'POST'),
        Header.ascii(':authority', _domain),
        Header.ascii(':path', '/ue/app/$path'),
        Header.ascii(':scheme', 'https'),
        Header.ascii('content-type', 'application/x-www-form-urlencoded'),
        Header.ascii('content-length', bodyBytes.length.toString()),
        Header.ascii('user-agent', 'okhttp/4.9.0'),
        Header.ascii('accept-encoding', 'gzip'),
      ], endStream: false);

      stream.sendData(bodyBytes, endStream: true);

      final responseBytes = <int>[];
      final responseHeaders = <String, String>{};

      await for (final message in stream.incomingMessages) {
        if (message is HeadersStreamMessage) {
          for (final header in message.headers) {
            responseHeaders[utf8.decode(header.name).toLowerCase()] = utf8
                .decode(header.value);
          }
        } else if (message is DataStreamMessage) {
          responseBytes.addAll(message.bytes);
        }
      }

      final decodedBody = responseHeaders['content-encoding'] == 'gzip'
          ? utf8.decode(gzip.decode(responseBytes))
          : utf8.decode(responseBytes);
      final response = jsonDecode(decodedBody);

      if (!muteToast && !_isSuccessCode(response['code'])) {
        ToastService.show(
          response['msg']?.toString() ?? '\u8bf7\u6c42\u5931\u8d25',
        );
      }

      if (response is Map<String, dynamic>) {
        return response;
      }
      if (response is Map) {
        return Map<String, dynamic>.from(response);
      }
      return null;
    } catch (_) {
      _sharedTransport = null;
      if (retry > 0) {
        return post(
          path,
          extra,
          token: token,
          userId: userId,
          retry: retry - 1,
          muteToast: muteToast,
        );
      }
      if (!muteToast) {
        ToastService.show('\u7f51\u7edc\u8fde\u63a5\u5f02\u5e38\uff0c\u8bf7\u91cd\u8bd5');
      }
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>?> fetchBillHistoryMonth({
    required String token,
    required String userId,
    required int year,
    required int month,
    int limit = 100,
    int begin = 0,
    String type = 'bill_0',
    bool muteToast = true,
  }) async {
    final response = await post(
      'bill/myBillList',
      {
        'month': '$month',
        'limit': '$limit',
        'type': type,
        'begin': '$begin',
        'years': '$year',
      },
      token: token,
      userId: userId,
      muteToast: muteToast,
    );

    if (response == null || !_isSuccessCode(response['code'])) {
      return null;
    }

    final data = response['data'];
    if (data is! Map) {
      return <Map<String, dynamic>>[];
    }

    final listData = data['listData'];
    if (listData is! List) {
      return <Map<String, dynamic>>[];
    }

    return listData
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  static Future<List<Map<String, dynamic>>?> fetchAllBillHistoryMonth({
    required String token,
    required String userId,
    required int year,
    required int month,
    int pageSize = 100,
    String type = 'bill_0',
    bool muteToast = true,
  }) async {
    final allItems = <Map<String, dynamic>>[];
    var begin = 0;

    while (true) {
      final page = await fetchBillHistoryMonth(
        token: token,
        userId: userId,
        year: year,
        month: month,
        limit: pageSize,
        begin: begin,
        type: type,
        muteToast: muteToast,
      );

      if (page == null) {
        return null;
      }

      if (page.isEmpty) {
        break;
      }

      allItems.addAll(page);
      if (page.length < pageSize) {
        break;
      }

      begin += page.length;
    }

    return allItems;
  }

  static Future<List<Map<String, dynamic>>?> fetchBillHistory({
    required String token,
    required String userId,
    int limit = 100,
    int begin = 0,
    String type = 'bill_0',
    bool muteToast = true,
  }) async {
    final now = DateTime.now();
    return fetchBillHistoryMonth(
      token: token,
      userId: userId,
      year: now.year,
      month: now.month,
      limit: limit,
      begin: begin,
      type: type,
      muteToast: muteToast,
    );
  }

  static Future<List<Map<String, dynamic>>?> fetchAllBillHistory({
    required String token,
    required String userId,
    int pageSize = 100,
    String type = 'bill_0',
    bool muteToast = true,
  }) async {
    final now = DateTime.now();
    return fetchAllBillHistoryMonth(
      token: token,
      userId: userId,
      year: now.year,
      month: now.month,
      pageSize: pageSize,
      type: type,
      muteToast: muteToast,
    );
  }

  static bool _isSuccessCode(Object? code) {
    return code == 0 || code == '0' || code == 200 || code == '200';
  }
}
