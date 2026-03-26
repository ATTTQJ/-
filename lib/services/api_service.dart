import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:http2/http2.dart';
import '../core/toast_service.dart';

class ApiService {
  static const String _realSalt = "e275f1af-1dda-4b47-9d87-afcbe1f96dca";
  static const String _domain = "uyschool.uyxy.xin";
  static ClientTransportConnection? _sharedTransport;

  static Future<ClientTransportConnection> _getTransport() async {
    if (_sharedTransport != null && _sharedTransport!.isOpen) return _sharedTransport!;
    final socket = await SecureSocket.connect(_domain, 443, supportedProtocols: ['h2']).timeout(const Duration(seconds: 10));
    _sharedTransport = ClientTransportConnection.viaSocket(socket);
    return _sharedTransport!;
  }

  static String _generateSign(String dateTime, Map<String, String> extra, String token, String userId) {
    Map<String, String> params = {"AndroidVersionName": "V2.9.2", "AndroidVersionCode": "92", "dateTime": dateTime};
    if (userId.isNotEmpty) params["userId"] = userId; 
    if (token.isNotEmpty) params["token"] = token;
    params.addAll(extra);
    params.removeWhere((key, value) => value.toString().trim().isEmpty);
    var sortedKeys = params.keys.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    String raw = sortedKeys.map((k) => "$k=${params[k]}").join("&");
    raw += token.isNotEmpty ? "&$token" : "&$dateTime";
    raw += "&$_realSalt&292";
    return sha256.convert(utf8.encode(raw)).toString();
  }

  static Future<Map<String, dynamic>?> post(String path, Map<String, String> extra, {String token = "", String userId = "", int retry = 1, bool muteToast = false}) async {
    String ts = DateTime.now().millisecondsSinceEpoch.toString();
    String sign = _generateSign(ts, extra, token, userId);
    StringBuffer sb = StringBuffer();
    extra.forEach((k, v) => sb.write("$k=${Uri.encodeComponent(v)}&"));
    if (userId.isNotEmpty) sb.write("userId=${Uri.encodeComponent(userId)}&");
    if (token.isNotEmpty) sb.write("token=$token&");
    sb.write("AndroidVersionName=V2.9.2&AndroidVersionCode=92&sign=$sign&dateTime=$ts");
    final List<int> bodyBytes = utf8.encode(sb.toString());

    try {
      final transport = await _getTransport();
      final stream = transport.makeRequest([
        Header.ascii(':method', 'POST'), Header.ascii(':authority', _domain),
        Header.ascii(':path', "/ue/app/$path"), Header.ascii(':scheme', 'https'),
        Header.ascii('content-type', 'application/x-www-form-urlencoded'),
        Header.ascii('content-length', bodyBytes.length.toString()),
        Header.ascii('user-agent', 'okhttp/4.9.0'),
        Header.ascii('accept-encoding', 'gzip'),
      ], endStream: false);
      stream.sendData(bodyBytes, endStream: true);

      List<int> resData = [];
      Map<String, String> resHeaders = {};
      await for (var msg in stream.incomingMessages) {
        if (msg is HeadersStreamMessage) {
          for (var h in msg.headers) resHeaders[utf8.decode(h.name).toLowerCase()] = utf8.decode(h.value);
        } else if (msg is DataStreamMessage) {
          resData.addAll(msg.bytes);
        }
      }

      String decoded = (resHeaders['content-encoding'] == 'gzip') ?
      utf8.decode(gzip.decode(resData)) : utf8.decode(resData);
      
      final res = jsonDecode(decoded);

      if (!muteToast && res != null && res["code"] != 0 && res["code"] != "0" && res["code"] != 200) {
        ToastService.show(res["msg"] ?? "请求失败");
      }
      return res;

    } catch (e) {
      _sharedTransport = null;
      if (retry > 0) return post(path, extra, token: token, userId: userId, retry: retry - 1, muteToast: muteToast);
      if (!muteToast) ToastService.show("网络连接异常，请重试");
      return null;
    }
  }
}