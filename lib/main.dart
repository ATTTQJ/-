import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 🌟 新增：用于 MethodChannel 与原生通信
import 'package:http2/http2.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_scanner/mobile_scanner.dart'; 

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = MyHttpOverrides();
  await SharedPreferences.getInstance(); 
  runApp(const MaterialApp(debugShowCheckedModeBanner: false, home: WaterApp()));
}

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}

class WaterApp extends StatefulWidget {
  const WaterApp({super.key});
  @override
  State<WaterApp> createState() => _WaterAppState();
}

class _WaterAppState extends State<WaterApp> with TickerProviderStateMixin {
  String _token = "";
  String _userId = "";
  String _userPhone = "";
  String _userName = "User"; 
  String _balance = "0.00"; 
  
  String _orderNum = ""; 
  String _tableName = ""; 
  String _mac = "";
  bool _isRequesting = false;
  List<String> _history = [];
  
  List<Map<String, dynamic>> _deviceList = []; 
  String _selectedDeviceId = "";
  bool _isDeviceExpanded = false; 
  bool _isAlwaysExpanded = false; 
  bool _isActionMenuCollapsed = false;
  Map<String, String> _customRemarks = {}; 

  bool _hasShownBalanceWarning = false;

  DateTime? _startTime;
  Timer? _timer;
  String _runningTime = "00:00";
  
  int _countdown = 0;
  Timer? _countdownTimer;

  final String _realSalt = "e275f1af-1dda-4b47-9d87-afcbe1f96dca";
  final String _domain = "uyschool.uyxy.xin";
  final Color _deepTextColor = const Color(0xFF2C2C2E); 
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();

  ClientTransportConnection? _sharedTransport;

  OverlayEntry? _toastEntry;
  Timer? _toastOverlayTimer;

  // 🌟 新增：与 iOS 原生 Siri Intent 通信的频道
  final MethodChannel _siriChannel = const MethodChannel('com.fakeuy.water/siri');

  @override
  void initState() {
    super.initState();
    _loadFromLocal();
    _initSiriListener(); // 🌟 启动 Siri 监听
  }

  @override
  void dispose() { 
    _timer?.cancel(); 
    _toastOverlayTimer?.cancel();
    _toastEntry?.remove();
    _countdownTimer?.cancel();
    _sharedTransport?.finish();
    super.dispose();
  }

  // 🌟 新增：监听来自 Siri / 快捷指令的操作
  void _initSiriListener() {
    _siriChannel.setMethodCallHandler((call) async {
      if (call.method == "executeAction") {
        final args = call.arguments;
        String action = "";
        String targetName = "";

        if (args is Map) {
          action = args["action"]?.toString() ?? "";
          targetName = args["device"]?.toString() ?? "";
        } else if (args is String) {
          action = args;
        }

        if (action == "start") {
          // 如果 Siri 传来了指定的设备名称，尝试匹配
          if (targetName.isNotEmpty && _deviceList.isNotEmpty) {
            for (var d in _deviceList) {
              String id = d["deviceInfId"].toString();
              String name = _customRemarks[id] ?? d["deviceInfName"].toString();
              // 模糊匹配：只要语音包含备注名，或者备注名包含语音，就算匹配成功
              if (name.contains(targetName) || targetName.contains(name)) {
                setState(() => _selectedDeviceId = id);
                break;
              }
            }
          }
          // Siri 触发时，带上 force: true 强制开启，跳过时段弹窗
          startWater(force: true);
        } else if (action == "stop") {
          stopWater();
        }
      }
    });
  }

  void _showGlassBottomSheet(Widget child) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "GlassBottomSheet",
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 600), 
      pageBuilder: (context, anim1, anim2) {
        double kbHeight = MediaQuery.of(context).viewInsets.bottom;
        double screenH = MediaQuery.of(context).size.height;
        double maxDialogHeight = screenH - kbHeight - 80;
        if (maxDialogHeight < 200) maxDialogHeight = 200; 

        return Stack(
          children: [
            GestureDetector(onTap: () => Navigator.pop(context), child: Container(color: Colors.transparent)),
            Align(
              alignment: Alignment.bottomCenter,
              child: AnimatedPadding(
                padding: EdgeInsets.only(bottom: kbHeight), 
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                child: Container(
                  margin: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
                  width: double.infinity,
                  constraints: BoxConstraints(maxHeight: maxDialogHeight), 
                  decoration: ShapeDecoration(
                    color: Colors.white.withOpacity(0.92), 
                    shape: ContinuousRectangleBorder(borderRadius: BorderRadius.circular(45))
                  ),
                  child: Material(
                    color: Colors.transparent, 
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22.5),
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Padding(
                          padding: const EdgeInsets.only(
                            left: 24, right: 24, top: 24,
                            bottom: 24 
                          ),
                          child: child
                        )
                      )
                    )
                  )
                ),
              ),
            )
          ]
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        final curve = Curves.easeOutCubic;
        return Stack(
          children: [
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 4.5 * curve.transform(anim1.value), sigmaY: 4.5 * curve.transform(anim1.value)), 
              child: Container(color: Colors.transparent)
            ),
            SlideTransition(
              position: Tween(begin: const Offset(0, 1.0), end: Offset.zero).animate(CurvedAnimation(parent: anim1, curve: curve)), 
              child: child
            ),
          ]
        );
      }
    );
  }

  Future<void> _loadFromLocal() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _token = prefs.getString('token') ?? "";
      _userId = prefs.getString('userId') ?? "";
      _userPhone = prefs.getString('userPhone') ?? "";
      _userName = prefs.getString('userName') ?? "User";
      _balance = prefs.getString('balance') ?? "0.00";
      
      _orderNum = prefs.getString('water_orderNum') ?? "";
      _tableName = prefs.getString('water_tableName') ?? "";
      _mac = prefs.getString('water_mac') ?? "";
      
      _history = prefs.getStringList('water_history') ?? [];
      
      _isAlwaysExpanded = prefs.getBool('always_expanded') ?? false;
      if (_isAlwaysExpanded) {
        _isDeviceExpanded = true;
        _isActionMenuCollapsed = true; 
      }

      String? remarksStr = prefs.getString('device_remarks');
      if (remarksStr != null && remarksStr.isNotEmpty) {
        try {
          _customRemarks = Map<String, String>.from(jsonDecode(remarksStr));
        } catch (e) {}
      }
    });
    int savedStartTime = prefs.getInt('water_start_time') ?? 0;
    if (_orderNum.isNotEmpty && savedStartTime > 0) {
      _startTime = DateTime.fromMillisecondsSinceEpoch(savedStartTime);
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        final diff = DateTime.now().difference(_startTime!);
        if (mounted) setState(() => _runningTime = "${diff.inMinutes.toString().padLeft(2, '0')}:${(diff.inSeconds % 60).toString().padLeft(2, '0')}");
      });
    }

    if (_token.isNotEmpty) {
      await _silentTokenGuard();
      await _fetchUserInfo(); 
      await _loadDeviceList();
      await _fetchRealHistoryData();
    }
  }

  void _checkLowBalance(String currentBalance) {
    double bal = double.tryParse(currentBalance) ?? 0.0;
    if (bal >= 5.0) {
      _hasShownBalanceWarning = false;
    } else if (bal < 5.0 && !_hasShownBalanceWarning) {
      _hasShownBalanceWarning = true;
      Future.delayed(const Duration(milliseconds: 500), () => _showLowBalanceWarning());
    }
  }

  void _showLowBalanceWarning() {
    _showGlassBottomSheet(
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.account_balance_wallet_rounded, color: Colors.orange[400], size: 48),
          const SizedBox(height: 16),
          Text("余额不足提醒", style: TextStyle(color: _deepTextColor, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text("您的当前余额为 ¥$_balance，已低于 5.00 元。\n\n为避免洗浴时突然断水，请前往「U易官方App」进行充值哦！", 
               style: const TextStyle(color: Color(0xFF666666), fontSize: 14, height: 1.5), textAlign: TextAlign.center),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _deepTextColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: () => Navigator.pop(context),
              child: const Text("我知道了", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          )
        ],
      )
    );
  }

  void _showHotWaterTimeWarning() {
    _showGlassBottomSheet(
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.access_time_rounded, color: Colors.orange[400], size: 48),
          const SizedBox(height: 16),
          Text("非热水供应时段", style: TextStyle(color: _deepTextColor, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          const Text("当前不在规定的热水供应时段。\n(06:00-09:30、11:30-14:30、18:00-23:50)\n\n此时开启可能只有冷水，是否继续？", 
               style: TextStyle(color: Color(0xFF666666), fontSize: 14, height: 1.5), textAlign: TextAlign.center),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context), 
                  child: const Text("取消", style: TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.bold))
                )
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: () {
                    Navigator.pop(context);
                    startWater(force: true); 
                  },
                  child: const Text("继续使用", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                )
              )
            ],
          )
        ],
      )
    );
  }

  Future<void> _saveDeviceRemark(String id, String remark) async {
    setState(() {
      if (remark.trim().isEmpty) {
        _customRemarks.remove(id);
      } else {
        _customRemarks[id] = remark.trim();
      }
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('device_remarks', jsonEncode(_customRemarks));
  }

  void _showEditRemarkDialog(String id, String currentName) {
    TextEditingController editingController = TextEditingController(text: _customRemarks[id] ?? currentName);
    _showGlassBottomSheet(
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("自定义设备备注", style: TextStyle(color: _deepTextColor, fontSize: 18, fontWeight: FontWeight.bold)),
              if (_customRemarks.containsKey(id)) 
                GestureDetector(
                  onTap: () {
                    _saveDeviceRemark(id, "");
                    Navigator.pop(context);
                  },
                  child: const Text("重置原名", style: TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w600))
                )
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: editingController,
            autofocus: true, 
            decoration: InputDecoration(
              hintText: "如：我的小电驴、536热水",
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: TextButton(onPressed: () => Navigator.pop(context), child: const Text("取消", style: TextStyle(color: Colors.grey)))),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: _deepTextColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: () {
                    _saveDeviceRemark(id, editingController.text);
                    Navigator.pop(context);
                  },
                  child: const Text("保存", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                )
              )
            ],
          )
        ],
      )
    );
  }

  void _showCascadingAddDeviceDialog() {
    _showGlassBottomSheet(
      DeviceSelectorDialog(
        httpPost: _http2Post,
        onSuccess: () => _refreshDeviceListFromNet(),
        onToast: (msg) => _appToast(msg),
        onScan: () {
          Navigator.pop(context); 
          _openScanner();         
        },
      )
    );
  }

  void _openScanner() async {
    final String? result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const QRScannerPage()),
    );
    if (result != null && result.isNotEmpty) {
      _performScanAdd(result);
    }
  }

  Future<void> _performScanAdd(String qrCode) async {
    setState(() => _isRequesting = true);
    try {
      final res = await _http2Post("device/scanTheCode", {
        "deviceWayId": "0",
        "qrCode": qrCode,
      });

      if (res != null && (res["code"] == 0 || res["code"] == "0" || res["code"] == 200)) {
        _appToast("设备绑定成功！");
        await _refreshDeviceListFromNet(); 
      } else {
        _appToast(res?["msg"] ?? "扫码绑定失败");
      }
    } catch (e) {
      _appToast("网络异常");
    } finally {
      setState(() => _isRequesting = false);
    }
  }

  void _showDeleteConfirmDialog(String commonlyId, String deviceName) {
    _showGlassBottomSheet(
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("移除设备", style: TextStyle(color: _deepTextColor, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Text("确定要将「$deviceName」从你的常用列表中移除吗？", style: const TextStyle(color: Color(0xFF666666), fontSize: 15, height: 1.5), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: TextButton(onPressed: () => Navigator.pop(context), child: const Text("取消", style: TextStyle(color: Colors.grey)))),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: () {
                    Navigator.pop(context);
                    _performDeleteDevice(commonlyId);
                  },
                  child: const Text("确认移除", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                )
              )
            ],
          )
        ],
      )
    );
  }

  void _showLogoutConfirm() {
    _showGlassBottomSheet(
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start, 
        children: [
          Text("Logout", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _deepTextColor)),
          const SizedBox(height: 16),
          const Text("确定要退出当前账号吗？", style: TextStyle(color: Color(0xFF666666), fontSize: 15)),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: TextButton(onPressed: () => Navigator.pop(context), child: const Text("取消", style: TextStyle(color: Colors.grey, fontSize: 16)))),
              Expanded(
                child: TextButton(
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.clear();
                    setState(() { _token = ""; _userId = ""; });
                    Navigator.pop(context);
                  }, 
                  child: const Text("退出登录", style: TextStyle(color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.bold))
                )
              ),
            ]
          ),
        ]
      )
    );
  }

  void _appToast(String message, {int durationMs = 3000}) {
    _toastOverlayTimer?.cancel();
    _toastEntry?.remove();
    _toastEntry = null;
    _toastEntry = OverlayEntry(
      builder: (context) => TopToastWidget(message: message, durationMs: durationMs)
    );

    Overlay.of(context).insert(_toastEntry!);
    _toastOverlayTimer = Timer(Duration(milliseconds: durationMs + 300), () {
      if (_toastEntry != null) {
        _toastEntry?.remove();
        _toastEntry = null;
      }
    });
  }

  Future<ClientTransportConnection> _getTransport() async {
    if (_sharedTransport != null && _sharedTransport!.isOpen) return _sharedTransport!;
    final socket = await SecureSocket.connect(_domain, 443, supportedProtocols: ['h2']).timeout(const Duration(seconds: 10));
    _sharedTransport = ClientTransportConnection.viaSocket(socket);
    return _sharedTransport!;
  }

  Future<Map<String, dynamic>?> _http2Post(String path, Map<String, String> extra, {int retry = 1}) async {
    String ts = DateTime.now().millisecondsSinceEpoch.toString();
    String sign = _generateSign(ts, extra);
    StringBuffer sb = StringBuffer();
    extra.forEach((k, v) => sb.write("$k=${Uri.encodeComponent(v)}&"));
    if (_userId.isNotEmpty) sb.write("userId=${Uri.encodeComponent(_userId)}&");
    if (_token.isNotEmpty) sb.write("token=$_token&");
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
        } else if (msg is DataStreamMessage) resData.addAll(msg.bytes);
      }
      String decoded = (resHeaders['content-encoding'] == 'gzip') ?
        utf8.decode(gzip.decode(resData)) : utf8.decode(resData);
      return jsonDecode(decoded);
    } catch (e) {
      _sharedTransport = null;
      if (retry > 0) return _http2Post(path, extra, retry: retry - 1);
      return null;
    }
  }

  String _generateSign(String dateTime, Map<String, String> extra) {
    Map<String, String> params = {"AndroidVersionName": "V2.9.2", "AndroidVersionCode": "92", "dateTime": dateTime};
    if (_userId.isNotEmpty) params["userId"] = _userId; 
    if (_token.isNotEmpty) params["token"] = _token;
    params.addAll(extra);
    params.removeWhere((key, value) => value.toString().trim().isEmpty);
    var sortedKeys = params.keys.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    String raw = sortedKeys.map((k) => "$k=${params[k]}").join("&");
    raw += _token.isNotEmpty ? "&$_token" : "&$dateTime";
    raw += "&$_realSalt&292";
    return sha256.convert(utf8.encode(raw)).toString();
  }

  Future<void> _fetchUserInfo() async {
    final res = await _http2Post("user/queryUserInfo", {});
    if (res != null && (res["code"] == 0 || res["code"] == "0") && res["data"] != null) {
      String name = res["data"]["userName"] ?? res["data"]["nickname"] ?? "User";
      setState(() => _userName = name);
      (await SharedPreferences.getInstance()).setString("userName", name);
    }
  }

  Future<void> _silentTokenGuard() async {
    final res = await _http2Post("user/queryUserWalletInfo", {});
    if (res != null) {
      if (res["code"] == 0 || res["code"] == "0") {
        setState(() => _balance = res["data"]["uBalance"].toString());
        _checkLowBalance(_balance); 
      } else if (res["code"] == 401 || res["code"] == "401") {
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
        setState(() { _token = ""; _userId = ""; });
      }
    }
  }

  Future<void> _loadDeviceList() async {
    final prefs = await SharedPreferences.getInstance();
    String? savedListStr = prefs.getString('saved_device_list');
    if (savedListStr != null && savedListStr.isNotEmpty) {
      try {
        List<dynamic> decoded = jsonDecode(savedListStr);
        setState(() {
          _deviceList = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
          if (_deviceList.isNotEmpty && _selectedDeviceId.isEmpty) {
            _selectedDeviceId = _deviceList[0]["deviceInfId"].toString();
          }
        });
        return; 
      } catch (e) {}
    }
    await _refreshDeviceListFromNet();
  }

  Future<void> _refreshDeviceListFromNet() async {
    final res = await _http2Post("device/findDeviceCommonlyByUserId", {});
    if (res != null && (res["code"] == 0 || res["code"] == "0")) {
      var rawData = res["data"];
      List<dynamic> list = (rawData is List) ? rawData : (rawData is Map ? (rawData["listDeviceCommonly"] ?? rawData["listData"] ?? rawData["list"] ?? []) : []);
      List<Map<String, dynamic>> processedList = [];
      for (var item in list) {
        if (item is Map) {
          String id = (item["deviceInfId"] ?? "").toString();
          String name = (item["deviceName"] ?? "未知设备").toString();
          String commonlyId = (item["id"] ?? item["commonlyId"] ?? "").toString();
          int bType = int.tryParse((item["deviceWayId"] ?? item["billType"] ?? 2).toString()) ?? 2;
          if (id.isNotEmpty) {
            processedList.add({
              "deviceInfId": id, 
              "deviceInfName": name, 
              "billType": bType,
              "commonlyId": commonlyId
            });
          }
        }
      }
      processedList.sort((a, b) {
        int typeA = a["billType"] as int;
        int typeB = b["billType"] as int;
        if (typeA != typeB) return typeB.compareTo(typeA); 
        return a["deviceInfName"].toString().compareTo(b["deviceInfName"].toString());
      });
      setState(() { 
        _deviceList = processedList; 
        if (_deviceList.isNotEmpty && !_deviceList.any((d) => d["deviceInfId"].toString() == _selectedDeviceId)) {
           _selectedDeviceId = _deviceList[0]["deviceInfId"].toString(); 
        } else if (_deviceList.isEmpty) {
           _selectedDeviceId = "";
        }
      });
      _saveDeviceListToLocal(); 
    }
  }

  Future<void> _saveDeviceListToLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_device_list', jsonEncode(_deviceList));
  }

  Future<void> _performDeleteDevice(String commonlyId) async {
    setState(() => _isRequesting = true);
    try {
      var res = await _http2Post("device/operationDeviceCommonly", {
        "commonlyId": commonlyId,
        "type": "2" 
      });
      if (res != null && (res["code"] == 0 || res["code"] == "0" || res["code"] == 200)) {
        _appToast("已移除常用设备");
        await _refreshDeviceListFromNet(); 
      } else {
        _appToast(res?["msg"] ?? "删除失败，请重试");
      }
    } catch (e) {
      _appToast("网络异常");
    } finally {
      setState(() => _isRequesting = false);
    }
  }

  Future<void> sendCode() async {
    String tel = _phoneController.text.trim();
    if (tel.length != 11 || _countdown > 0) return;
    setState(() => _isRequesting = true);
    try {
      int now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      String ts = "${now}000";
      Map<String, String> p = {"tel": tel, "AndroidVersionName": "V2.9.2", "AndroidVersionCode": "92", "dateTime": ts};
      var keys = p.keys.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      String sign = sha256.convert(utf8.encode(keys.map((k) => "$k=${p[k]}").join("&") + "&$ts&$_realSalt&292")).toString();
      String body = "tel=$tel&AndroidVersionName=V2.9.2&AndroidVersionCode=92&sign=$sign&dateTime=$ts";
      final socket = await SecureSocket.connect(_domain, 443, supportedProtocols: ['h2']);
      final transport = ClientTransportConnection.viaSocket(socket);
      final stream = transport.makeRequest([
        Header.ascii(':method', 'POST'), Header.ascii(':authority', _domain),
        Header.ascii(':path', "/ue/app/user/sendRegisterMsg"), Header.ascii(':scheme', 'https'),
        Header.ascii('content-type', 'application/x-www-form-urlencoded'),
        Header.ascii('content-length', utf8.encode(body).length.toString()),
        Header.ascii('user-agent', 'okhttp/4.9.0'),
        Header.ascii('accept-encoding', 'gzip'),
      ], endStream: false);
      stream.sendData(utf8.encode(body), endStream: true);
      List<int> resData = [];
      Map<String, String> resHeaders = {};
      await for (var msg in stream.incomingMessages) { 
        if (msg is HeadersStreamMessage) { 
          for (var h in msg.headers) resHeaders[utf8.decode(h.name).toLowerCase()] = utf8.decode(h.value);
        } else if (msg is DataStreamMessage) {
          resData.addAll(msg.bytes);
        }
      }
      await transport.finish();
      String decoded = (resHeaders['content-encoding'] == 'gzip') ? utf8.decode(gzip.decode(resData)) : utf8.decode(resData);
      final res = jsonDecode(decoded);
      if (res != null && (res["code"] == 0 || res["code"] == "0")) { 
        _appToast("验证码已发送");
        _startCountdown(); 
      } else { 
        _appToast(res?["msg"] ?? "发送失败");
      }
    } catch (e) { _appToast("网络异常"); }
    finally { setState(() => _isRequesting = false);
    }
  }

  void _startCountdown() {
    setState(() => _countdown = 60);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) { 
      if (_countdown == 0) {
        t.cancel(); 
      } else if (mounted) {
        setState(() => _countdown--); 
      }
    });
  }

  Future<void> login() async {
    String tel = _phoneController.text.trim();
    String code = _codeController.text.trim();
    if (tel.isEmpty || code.isEmpty) return;
    setState(() => _isRequesting = true);
    try {
      int now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      String ts = "${now}000";
      Map<String, String> p = {"tel": tel, "code": code, "type": "5"};
      var keys = p.keys.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      String raw = "AndroidVersionCode=92&AndroidVersionName=V2.9.2&dateTime=$ts&" + keys.map((k) => "$k=${p[k]}").join("&") + "&$ts&$_realSalt&292";
      String sign = sha256.convert(utf8.encode(raw)).toString();
      String body = "tel=$tel&code=$code&type=5&AndroidVersionName=V2.9.2&AndroidVersionCode=92&sign=$sign&dateTime=$ts";
      final socket = await SecureSocket.connect(_domain, 443, supportedProtocols: ['h2']);
      final transport = ClientTransportConnection.viaSocket(socket);
      final stream = transport.makeRequest([
        Header.ascii(':method', 'POST'), Header.ascii(':authority', _domain),
        Header.ascii(':path', "/ue/app/user/register"), Header.ascii(':scheme', 'https'),
        Header.ascii('content-type', 'application/x-www-form-urlencoded'),
        Header.ascii('content-length', utf8.encode(body).length.toString()),
        Header.ascii('user-agent', 'okhttp/4.9.0'),
        Header.ascii('accept-encoding', 'gzip'),
      ], endStream: false);
      stream.sendData(utf8.encode(body), endStream: true);
      List<int> resData = [];
      Map<String, String> resHeaders = {};
      await for (var msg in stream.incomingMessages) { 
        if (msg is HeadersStreamMessage) { 
          for (var h in msg.headers) resHeaders[utf8.decode(h.name).toLowerCase()] = utf8.decode(h.value);
        } else if (msg is DataStreamMessage) {
          resData.addAll(msg.bytes);
        }
      }
      await transport.finish();
      String decoded = (resHeaders['content-encoding'] == 'gzip') ? utf8.decode(gzip.decode(resData)) : utf8.decode(resData);
      final res = jsonDecode(decoded);
      if (res != null && (res["code"] == 0 || res["code"] == "0")) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString("userPhone", tel); 
        await prefs.setString("token", res["data"]["token"]); 
        await prefs.setString("userId", res["data"]["userId"]);
        setState(() { _token = res["data"]["token"]; _userId = res["data"]["userId"]; _userPhone = tel; });
        _silentTokenGuard(); 
        _fetchUserInfo(); 
        _loadDeviceList();
      } else { 
        _appToast("登录失败");
      }
    } catch (e) { _appToast("登录异常"); }
    finally { setState(() => _isRequesting = false);
    }
  }

  Future<void> syncBalance() async {
    final res = await _http2Post("user/queryUserWalletInfo", {});
    if (res != null && (res["code"] == 0 || res["code"] == "0")) {
      setState(() => _balance = res["data"]["uBalance"].toString());
      _checkLowBalance(_balance);
      _appToast("余额已同步");
    }
  }

  Future<void> startWater({bool force = false}) async {
    if (_selectedDeviceId.isEmpty) { _appToast("请先选择设备"); return; }
    
    var device = _deviceList.firstWhere((d) => d["deviceInfId"].toString() == _selectedDeviceId, orElse: () => _deviceList[0]);
    String targetDeviceId = device["deviceInfId"].toString();
    String targetBillType = device["billType"].toString();
    
    if (!force && targetBillType == "2") {
      DateTime now = DateTime.now();
      int currentMinutes = now.hour * 60 + now.minute;
      
      bool inSlot1 = currentMinutes >= 6 * 60 && currentMinutes <= 9 * 60 + 30;  
      bool inSlot2 = currentMinutes >= 11 * 60 + 30 && currentMinutes <= 14 * 60 + 30; 
      bool inSlot3 = currentMinutes >= 18 * 60 && currentMinutes <= 23 * 60 + 50; 
      
      if (!inSlot1 && !inSlot2 && !inSlot3) {
        _showHotWaterTimeWarning(); 
        return;
      }
    }
    
    setState(() => _isRequesting = true);
    try {
      await _http2Post("device/useEquipment", {"orderWay": "1", "theConnectionMethod": "2", "deviceInfId": targetDeviceId, "billType": targetBillType, "lackBalance": "lackBalance", "type": "1"});
      await Future.delayed(const Duration(milliseconds: 550));
      var res2 = await _http2Post("device/useEquipment", {"orderWay": "1", "theConnectionMethod": "2", "deviceInfId": targetDeviceId, "billType": targetBillType, "lackBalance": "lackBalance", "type": "0"});
      if (res2 != null && (res2["code"] == 0 || res2["code"] == "0")) {
        _startTime = DateTime.now();
        setState(() { 
          _orderNum = res2["data"]["orderNum"]?.toString() ?? ""; 
          _tableName = res2["data"]["tableName"]?.toString() ?? ""; 
          _mac = res2["data"]["mac"]?.toString() ?? ""; 
        });
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('water_orderNum', _orderNum);
        await prefs.setString('water_tableName', _tableName);
        await prefs.setString('water_mac', _mac);
        await prefs.setInt('water_start_time', _startTime!.millisecondsSinceEpoch);
        await prefs.setString('water_initial_balance', _balance);
        _timer = Timer.periodic(const Duration(seconds: 1), (t) {
          final diff = DateTime.now().difference(_startTime!);
          if (mounted) setState(() => _runningTime = "${diff.inMinutes.toString().padLeft(2, '0')}:${(diff.inSeconds % 60).toString().padLeft(2, '0')}");
        });
        _appToast("已开启");
      } else { _appToast(res2?["msg"] ?? "开启失败"); }
    } finally { setState(() => _isRequesting = false);
    }
  }

  Future<void> stopWater() async {
    if (_orderNum.isEmpty) { 
      _appToast("单号丢失，无法关水");
      return; 
    }
    String finalTime = _runningTime;
    final prefs = await SharedPreferences.getInstance();
    String savedInitialBal = prefs.getString('water_initial_balance') ?? _balance;
    double before = double.tryParse(savedInitialBal) ?? 0.0;
    
    setState(() => _isRequesting = true);
    try {
      final res = await _http2Post("device/endEquipment", {"orderNum": _orderNum, "mac": _mac, "tableName": _tableName});
      if (res != null && (res["code"] == 0 || res["code"] == "0")) {
        _timer?.cancel();
        await prefs.remove('water_orderNum'); 
        await prefs.remove('water_tableName'); 
        await prefs.remove('water_mac'); 
        await prefs.remove('water_start_time');
        await prefs.remove('water_initial_balance');
        setState(() { _orderNum = ""; _tableName = ""; _mac = ""; _runningTime = "00:00"; });
        final syncRes = await _http2Post("user/queryUserWalletInfo", {});
        if (syncRes != null && (syncRes["code"] == 0 || syncRes["code"] == "0")) {
          setState(() => _balance = syncRes["data"]["uBalance"].toString());
          _checkLowBalance(_balance); 
        }
        
        double after = double.tryParse(_balance) ?? 0.0;
        double cost = before - after;
        if (cost < 0) cost = 0.0; 
        String costStr = cost.toStringAsFixed(2);
        _appToast("结算：¥$costStr，用时 $finalTime", durationMs: 4000);
        
        String currentDeviceName = "";
        try {
          var d = _deviceList.firstWhere((d) => d["deviceInfId"].toString() == _selectedDeviceId, orElse: () => _deviceList[0]);
          currentDeviceName = _customRemarks[_selectedDeviceId] ?? d["deviceInfName"].toString();
          if (currentDeviceName.contains("-")) currentDeviceName = currentDeviceName.split("-").last;
          currentDeviceName += (d["billType"] == 2 ? "热水" : "直饮");
        } catch (e) {}

        _history.insert(0, "${DateFormat('MM-dd HH:mm').format(DateTime.now())} ¥$costStr ($currentDeviceName 用时$finalTime)");
        await prefs.setStringList('water_history', _history);
      } else { 
        _appToast(res?["msg"] ?? "结算失败");
      }
    } finally { 
      setState(() => _isRequesting = false);
    }
  }

  Future<List<String>> _fetchRealHistoryData() async {
    try {
      final res = await _http2Post("bill/myBillList", {"limit": "10", "type": "bill_0", "begin": "0"});
      if (res != null && (res["code"] == 0 || res["code"] == "0") && res["data"] != null) {
        final list = res["data"]["listData"];
        if (list is List && list.isNotEmpty) {
          final Map firstBill = list[0] as Map;
          if ((firstBill["expAmountStr"] ?? "").toString().contains("未结算")) {
             String timeStr = (firstBill["payTypeStr"] ?? firstBill["createTime"] ?? "").toString();
             try { 
               _startTime = DateTime.parse(timeStr.replaceAll('/', '-').replaceFirst(' ', 'T'));
             } catch (e) {}
          }
          return list.map<String>((item) {
            final Map m = item as Map;
            
            String dName = (m["deviceName"] ?? m["deviceInfName"] ?? "").toString();
            if (dName.contains("-")) {
              dName = dName.split("-").last;
            } else {
              dName = dName.replaceAll(RegExp(r'^[12]-'), '');
            }
            
            String title = (m["title"] ?? "").toString();
            if (title.contains("洗浴") || title.contains("热水") || title.contains("设备用水")) {
              title = "热水";
            } else if (title.contains("饮")) {
              title = "直饮水";
            }
            
            String tag = dName.isNotEmpty ? "$dName$title" : title;
            if (tag.isEmpty) tag = "未知设备";

            return "${m["payTypeStr"]?.toString().substring(0, 11) ?? ''} ¥${m["expAmountStr"]?.toString().replaceAll('元', '') ?? ''} ($tag)";
          }).toList();
        }
      }
    } catch (e) {}
    return [];
  }

  void _showFloatingHistory() {
    final futureData = _fetchRealHistoryData();
    _showGlassBottomSheet(
      Column(
        mainAxisSize: MainAxisSize.min, 
        crossAxisAlignment: CrossAxisAlignment.start, 
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween, 
            children: [
              Text("用水记录", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _deepTextColor)), 
      
              GestureDetector(
                onTap: () async { 
                  (await SharedPreferences.getInstance()).remove('water_history'); 
                  setState(() => _history = []); 
                  Navigator.pop(context); 
          
                }, 
                child: const Text("清除", style: TextStyle(color: Colors.grey, fontSize: 13))
              )
            ]
          ), 
          const SizedBox(height: 16), 
          SizedBox(
          
            height: 304, 
            child: FutureBuilder<List<String>>(
              future: futureData, 
              builder: (context, snapshot) { 
                return AnimatedSwitcher(duration: const Duration(milliseconds: 300), child: _buildHistoryContent(snapshot));
              }
            )
          ), 
          const SizedBox(height: 10)
        ]
      )
    );
  }

  Widget _buildHistoryContent(AsyncSnapshot<List<String>> snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) return const SkeletonList(key: ValueKey("load"));
    List<String> list = snapshot.data ?? [];
    if (list.isEmpty) return Container(key: const ValueKey("empty"), height: 304, alignment: Alignment.center, child: const Text("暂无记录", style: TextStyle(color: Colors.grey)));
    return Column(
      key: const ValueKey("list"), 
      crossAxisAlignment: CrossAxisAlignment.start, 
      children: list.take(8).map((e) => Container(height: 38, alignment: Alignment.centerLeft, child: Text(e, style: const TextStyle(color: Color(0xFF666666), fontSize: 14)))).toList()
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7), 
      body: SafeArea(child: _token.isEmpty ? _buildLoginUI() : _buildMainUI())
    );
  }

  Widget _buildLoginUI() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40), 
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center, 
        crossAxisAlignment: CrossAxisAlignment.start, 
        children: [
          Text("Welcome", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: _deepTextColor)), 
          const SizedBox(height: 40), 
          TextField(controller: _phoneController, keyboardType: TextInputType.phone, 
            decoration: const InputDecoration(labelText: "手机号")), 
          const SizedBox(height: 20), 
          Stack(
            alignment: Alignment.centerRight, 
            children: [
              TextField(controller: _codeController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "验证码")), 
              GestureDetector(
          
                onTap: (_countdown > 0 || _isRequesting) ? null : sendCode, 
                child: _isRequesting && _countdown == 0 ?
                  const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : 
                  Text(_countdown > 0 ? "$_countdown s" : "获取验证码", style: TextStyle(color: _countdown > 0 ? Colors.grey : _deepTextColor, fontWeight: FontWeight.bold))
              )
            ]
          ), 
          const SizedBox(height: 50), 
     
          SizedBox(
            width: double.infinity, 
            height: 54, 
            child: ElevatedButton(
              onPressed: login, 
              style: ElevatedButton.styleFrom(backgroundColor: _deepTextColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), 
              child: const Text("登录", style: 
                TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
            )
          )
        ]
      )
    );
  }

  Widget _buildMainUI() {
    bool working = _orderNum.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start, 
      children: [
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, 
              children: [
                const SizedBox(height: 40), 
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28), 
                  child: Text("你好, $_userName", style: TextStyle(color: Colors.grey[600], fontSize: 15, fontWeight: FontWeight.w600))
                ), 
                const SizedBox(height: 12), 
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28), 
                  child: GestureDetector(
                    onTap: syncBalance, 
                    behavior: HitTestBehavior.opaque, 
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, 
                      children: [
                        const Text("钱包余额", style: TextStyle(color: Colors.grey, fontSize: 13)), 
                        const SizedBox(height: 2), 
                        FittedBox(child: Text("¥ $_balance", style: TextStyle(fontSize: 42, fontWeight: FontWeight.bold, color: _deepTextColor)))
                      ]
                    )
                  )
                ), 
                const SizedBox(height: 30), 
           
                _buildSmartDeviceCard(),

                Padding(
                  padding: const EdgeInsets.only(left: 43, right: 28, top: 12), 
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: _showFloatingHistory, 
                        child: const Text("用水记录 >", style: TextStyle(color: Colors.grey, fontSize: 13))
                      ),
                      if (_isAlwaysExpanded)
                        GestureDetector(
                          onTap: () {
                            setState(() => _isActionMenuCollapsed = !_isActionMenuCollapsed);
                          },
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            width: 50,
                            height: 28,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(100), 
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)]
                            ),
                            child: Icon(
                              _isActionMenuCollapsed ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                              color: Colors.grey[600],
                              size: 20,
                            ),
                          )
                        )
                      else 
                        const SizedBox(height: 28),
                    ]
                  )
                ), 
                const SizedBox(height: 20),
              ],
            ),
          )
        ),
       
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28), 
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween, 
            crossAxisAlignment: CrossAxisAlignment.end, 
            children: [
              Expanded(child: Text(_userPhone.length >= 11 ?
                "*******${_userPhone.substring(7)}" : "*******", style: const TextStyle(color: Colors.grey, fontSize: 13))), 
              GestureDetector(
                onTap: _isRequesting ? null : (working ? stopWater : () => startWater()), 
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300), 
            
                  width: 115, height: 115, 
                  decoration: ShapeDecoration(color: working ? Colors.redAccent : const Color(0xFF1660AB), shape: ContinuousRectangleBorder(borderRadius: BorderRadius.circular(50))), 
                  alignment: Alignment.center, 
                  child: _isRequesting ? 
                    
                    const ThreeDotsLoading() : 
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center, 
                      children: [
                        Text(working ? "STOP" : "OPEN", style: 
                          const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)), 
                        if (working) Text(_runningTime, style: const TextStyle(color: Colors.white70, fontSize: 13))
                      ]
                    )
                )
   
              ), 
              Expanded(
                child: Align(
                  alignment: Alignment.bottomRight, 
                  child: GestureDetector(
                  
                    onTap: _showLogoutConfirm, 
                    child: const Text("退出登录", style: TextStyle(color: Colors.grey, fontSize: 13))
                  )
                )
              )
            ]
         
          )
        ), 
        const SizedBox(height: 30)
      ]
    );
  }

  Widget _buildSmartDeviceCard() {
    Map<String, dynamic>? selectedDevice = _deviceList.isNotEmpty ?
      _deviceList.firstWhere((d) => d["deviceInfId"].toString() == _selectedDeviceId, orElse: () => _deviceList[0]) : null;
    String title = selectedDevice != null ?
      (_customRemarks[selectedDevice["deviceInfId"].toString()] ?? selectedDevice["deviceInfName"].toString().replaceAll(RegExp(r'^[12]-'), '')) : "请先添加设备";
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28), 
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350), 
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15)]), 
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18), 
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, 

            children: [
              GestureDetector(
                onTap: () {
                  if (_deviceList.isNotEmpty) {
                    if (!_isAlwaysExpanded) {
             
                      setState(() => _isDeviceExpanded = !_isDeviceExpanded);
                    }
                  } else {
                    _showCascadingAddDeviceDialog();
                  }
         
                }, 
                behavior: HitTestBehavior.opaque, 
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16), 
                  child: Row(
              
                    children: [
                      if (selectedDevice != null) ...[
                        Icon(selectedDevice["billType"] == 2 ?
                          Icons.hot_tub : Icons.water_drop, color: selectedDevice["billType"] == 2 ? Colors.orange : Colors.blue, size: 22), 
                        const SizedBox(width: 12), 
                        Expanded(child: Text(title, style: TextStyle(color: _deepTextColor, fontSize: 16, fontWeight: FontWeight.bold)))
                      ] else ...[
    
                        const Icon(Icons.add_circle, color: Colors.blue, size: 22),
                        const SizedBox(width: 12), 
                        Expanded(child: Text("添加你的第一个设备", style: TextStyle(color: _deepTextColor, fontSize: 16, fontWeight: FontWeight.bold)))
                
                      ], 
                      if (!_isAlwaysExpanded)
                        Icon(_isDeviceExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: Colors.grey)
                    ]
                  )
  
                )
              ), 
              AnimatedSize(
                duration: const Duration(milliseconds: 400), 
                curve: Curves.easeInOutCubic, 
                child: _isDeviceExpanded ?
                  Column(
                    children: [
                      Divider(height: 1, thickness: 1, color: Colors.grey[100]), 
                      ReorderableListView(
                        shrinkWrap: true, 
   
                        physics: const NeverScrollableScrollPhysics(), 
                        onReorder: (old, newIdx) { 
                          setState(() { 
                    
                            if (newIdx > old) newIdx--; 
                            final item = _deviceList.removeAt(old); 
                            _deviceList.insert(newIdx, item); 
                         
                            _saveDeviceListToLocal(); 
                          }); 
                        }, 
                        children: _deviceList.map((d) => _buildDeviceItem(d)).toList()
                 
                      ), 

                      AnimatedSize(
                        duration: const Duration(milliseconds: 300),
                     
                        curve: Curves.easeInOutCubic,
                        child: (_isAlwaysExpanded && _isActionMenuCollapsed) 
                          ? const SizedBox(width: double.infinity, height: 0)
                          : Column(
                              children: [
                                Row(
     
                                  children: [
                                    Expanded(child: _buildIconButton(Icons.refresh, "刷新", Colors.blue, () { if(!_isAlwaysExpanded) setState(() => _isDeviceExpanded = false);
                                      _refreshDeviceListFromNet(); })),
                                    Container(width: 1, height: 20, color: Colors.grey[200]),
                                    Expanded(child: _buildIconButton(Icons.delete_outline, "删除", Colors.redAccent, () {
                 
                                      if (selectedDevice != null && selectedDevice["commonlyId"] != null && selectedDevice["commonlyId"].toString().isNotEmpty) {
                                         if(!_isAlwaysExpanded) setState(() => _isDeviceExpanded = false);
                       
                                          _showDeleteConfirmDialog(selectedDevice["commonlyId"].toString(), title);
                                      } else {
                                         
                                        _appToast("无法删除此设备");
                                      }
                                    })),
                          
                                    Container(width: 1, height: 20, color: Colors.grey[200]),
                                    Expanded(child: _buildIconButton(Icons.add_circle_outline, "添加", Colors.blue, () => _showCascadingAddDeviceDialog())),
                                  ]
         
                                ),
                                
                                Padding(
           
                                  padding: const EdgeInsets.only(right: 20, bottom: 16, top: 4),
                                  child: Align(
                                   
                                    alignment: Alignment.centerRight,
                                    child: GestureDetector(
                                      onTap: () async {
                    
                                        setState(() {
                                          _isAlwaysExpanded = !_isAlwaysExpanded;
                                          if (_isAlwaysExpanded) {
                                            _isActionMenuCollapsed = true;
                                            _isDeviceExpanded = true;
                                          }
                                        });
                                        final prefs = await SharedPreferences.getInstance();
                                        await prefs.setBool('always_expanded', _isAlwaysExpanded);
                                      },
                                      child: Container(
                                        width: 94,
                                        height: 28,
                                        padding: const EdgeInsets.all(2),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[200], 
                                          borderRadius: BorderRadius.circular(100), 
                                        ),
                                        child: Stack(
                                          children: [
                                            AnimatedAlign(
                                              duration: const Duration(milliseconds: 250),
                                              curve: Curves.easeInOutCubic,
                                              alignment: _isAlwaysExpanded ? Alignment.centerRight : Alignment.centerLeft,
                                              child: Container(
                                                width: 45,
                                                height: 24,
                                                decoration: BoxDecoration(
                                                  color: Colors.white, 
                                                  borderRadius: BorderRadius.circular(100), 
                                                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2, offset: Offset(0, 1))]
                                                ),
                                              ),
                                            ),
                                            Row(
                                              children: [
                                                Expanded(child: Center(child: Text("默认", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: !_isAlwaysExpanded ? Colors.black87 : Colors.grey[600])))),
                                                Expanded(child: Center(child: Text("常驻", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isAlwaysExpanded ? Colors.black87 : Colors.grey[600])))),
                                              ]
                                            )
                                          ],
                                        ),
                                      ),
                                    ),
                                  )
                
                                )
                              ],
                            ),
                      )
    
                    ] 
                  ) : 
                  const SizedBox(width: double.infinity, height: 0)
              )
            ]
          )
     
        )
      )
    );
  }

  Widget _buildIconButton(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap, 
      behavior: HitTestBehavior.opaque, 
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14), 
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center, 
          children: [
            Icon(icon, color: color, size: 16), 

            const SizedBox(width: 4), 
            Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold))
          ]
        )
      )
    );
  }

  Widget _buildDeviceItem(Map<String, dynamic> device) {
    String id = device["deviceInfId"].toString();
    bool isSelected = id == _selectedDeviceId;
    String name = _customRemarks[id] ?? device["deviceInfName"].toString().replaceAll(RegExp(r'^[12]-'), '');
    return GestureDetector(
      key: ValueKey(id), 
      onTap: () { 
        if (_orderNum.isNotEmpty) {
          _appToast("用水中，无法切换设备");
        } else {
          setState(() { 
            _selectedDeviceId = id; 
            if (!_isAlwaysExpanded) _isDeviceExpanded = false; 
 
          }); 
        }
      }, 
      behavior: HitTestBehavior.opaque, 
      child: Container(
        color: isSelected ? Colors.grey[50] : Colors.transparent, 
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14), 
        child: Row(
          children: [
            
            Icon(Icons.drag_handle, color: Colors.grey[400], size: 20), 
            const SizedBox(width: 12), 
            Expanded(child: Text("$name (${device["billType"] == 2 ? "热水" : "直饮"})", style: TextStyle(color: isSelected ? _deepTextColor : Colors.grey[700], fontSize: 14, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal))), 
            if (isSelected) Icon(Icons.check, color: _deepTextColor, size: 18), 
            const SizedBox(width: 16), 
          
            GestureDetector(onTap: () => _showEditRemarkDialog(id, name), child: Icon(Icons.edit_note, color: Colors.grey[400], size: 22))
          ] 
        )
      )
    );
  }
}

// ==========================================
// 🌟 独立组件：TopToastWidget 全局层级滑动通知
// ==========================================
class TopToastWidget extends StatefulWidget {
  final String message;
  final int durationMs;
  const TopToastWidget({super.key, required this.message, required this.durationMs});

  @override
  State<TopToastWidget> createState() => _TopToastWidgetState();
}

class _TopToastWidgetState extends State<TopToastWidget> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400))..forward();
    Future.delayed(Duration(milliseconds: widget.durationMs - 400), () {
      if (mounted) _ctrl.reverse();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 15,
      left: 25,
      right: 25,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, -60 * (1 - Curves.easeOutQuart.transform(_ctrl.value))),
         
            child: Opacity(
              opacity: _ctrl.value,
              child: child,
            ),
          );
        },
        child: Center(
          child: Container(
            decoration: BoxDecoration(
   
              borderRadius: BorderRadius.circular(22), 
              boxShadow: [ BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 25, offset: const Offset(0, 10)) ]
            ), 
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22), 
              child: BackdropFilter(
      
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12), 
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14), 
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.85), 
   
                    borderRadius: BorderRadius.circular(22), 
                    border: Border.all(color: Colors.grey.withOpacity(0.2))
                  ), 
                  child: Material(
                    color: 
                      Colors.transparent,
                    child: Text(
                      widget.message, 
                      textAlign: TextAlign.center, 
                      style: const TextStyle(color: Color(0xFF2C2C2E), fontSize: 14, fontWeight: FontWeight.w600)
   
                    ),
                  )
                )
              )
            )
          )
        ),
     
      )
    );
  }
}

// ==========================================
// 🌟 独立组件：毛玻璃级联选择器
// ==========================================
class DeviceSelectorDialog extends StatefulWidget {
  final Future<Map<String, dynamic>?> Function(String, Map<String, String>) httpPost;
  final VoidCallback onSuccess;
  final Function(String) onToast;
  final VoidCallback onScan; 

  const DeviceSelectorDialog({
    super.key, 
    required this.httpPost, 
    required this.onSuccess, 
    required this.onToast,
    required this.onScan, 
  });

  @override
  State<DeviceSelectorDialog> createState() => _DeviceSelectorDialogState();
}

class _DeviceSelectorDialogState extends State<DeviceSelectorDialog> {
  final String mySchoolId = "27720"; 

  int _step = 0;
  bool _isLoading = true;
  String _selectedWayId = "";
  
  List<Map<String, String>> _currentList = [];
  final List<List<Map<String, String>>> _historyLists = [];
  final List<String> _titles = ["选择用水类型"];
  final List<String> _stepNames = ["选择用水类型", "选择校区", "选择楼栋", "选择楼层", "选择寝室 / 设备"];

  @override
  void initState() {
    super.initState();
    _fetchData(0, mySchoolId); 
  }

  String _extractId(Map m) {
    if (m.containsKey("deptId")) return m["deptId"].toString();
    if (m.containsKey("deviceWayId")) return m["deviceWayId"].toString();
    if (m.containsKey("deviceNum")) return m["deviceNum"].toString();
    if (m.containsKey("id")) return m["id"].toString();
    if (m.containsKey("value")) return m["value"].toString();
    if (m.containsKey("sn")) return m["sn"].toString();
    for (var key in m.keys) {
      if (key.toString().toLowerCase().contains("id")) return m[key].toString();
    }
    return "";
  }

  String _extractName(Map m) {
    if (m.containsKey("deptName")) return m["deptName"].toString();
    if (m.containsKey("wayName")) return m["wayName"].toString();
    if (m.containsKey("deviceWayName")) return m["deviceWayName"].toString();
    if (m.containsKey("name")) return m["name"].toString();
    if (m.containsKey("title")) return m["title"].toString();
    if (m.containsKey("label")) return m["label"].toString();
    for (var key in m.keys) {
      if (key.toString().toLowerCase().contains("name")) return m[key].toString();
    }
    return "未知选项";
  }

  Future<void> _fetchData(int step, String id) async {
    setState(() => _isLoading = true);
    String path = "";
    Map<String, String> params = {};

    if (step == 0) {
      path = "device/queryDeviceWay";
      params = {"schId": mySchoolId};
    } else {
      path = "school/querySchoolAddress";
      params = {"deptId": id};
    }

    var res = await widget.httpPost(path, params);
    List<Map<String, String>> parsed = [];
    if (res != null && (res["code"] == 0 || res["code"] == "0" || res["code"] == 200 || res["code"] == "200") && res["data"] != null) {
      var rawData = res["data"];
      List<dynamic> targetList = [];

      if (rawData is List) {
        targetList = rawData;
      } else if (rawData is Map) {
        for (var value in rawData.values) {
          if (value is List) {
            targetList = value;
            break; 
          }
        }
      }

      for (var item in targetList) {
        if (item is Map) {
          String extId = _extractId(item);
          String extName = _extractName(item);
          if (extId.isNotEmpty) {
            parsed.add({"id": extId, "name": extName});
          }
        }
      }
    }

    if (mounted) {
      setState(() {
        _currentList = parsed;
        _isLoading = false;
      });
    }
  }

  void _onItemTap(Map<String, String> item) async {
    if (_step == 0) {
      _selectedWayId = item["id"]!;
    }

    if (_step < 4) {
      _historyLists.add(List.from(_currentList));
      _step++;
      _titles.add(_stepNames[_step]);
      String nextId = _step == 1 ? mySchoolId : item["id"]!;
      _fetchData(_step, nextId);
    } else {
      setState(() => _isLoading = true);
      var queryRes = await widget.httpPost("device/queryDeviceInfo", {
        "deviceNum": item["id"]!,
        "schId": mySchoolId,
        "deviceWayId": _selectedWayId,
        "type": "4"
      });
      if (queryRes != null && (queryRes["code"] == 0 || queryRes["code"] == "0" || queryRes["code"] == 200)) {
        var data = queryRes["data"];
        if (data != null && data is Map) {
          String deviceInfId = data["deviceInfId"]?.toString() ??
            "";
          String deviceTypeId = data["deviceTypeId"]?.toString() ?? "";
          String finalWayId = data["deviceWayId"]?.toString() ?? _selectedWayId;
          if (deviceInfId.isNotEmpty) {
            var addRes = await widget.httpPost("device/operationDeviceCommonly", {
              "deviceTypeId": deviceTypeId,
              "deviceWayId": finalWayId,
              "deviceInfId": deviceInfId,
              "type": "1" 
            });
            if (addRes != null && (addRes["code"] == 0 || addRes["code"] == "0" || addRes["code"] == 200)) {
              widget.onToast("设备添加成功！");
              widget.onSuccess(); 
              if (mounted) Navigator.pop(context);
              return;
            } else {
              widget.onToast(addRes?["msg"] ?? "添加常用设备失败");
            }
          } else {
            widget.onToast("未能获取到设备真实ID");
          }
        } else {
          widget.onToast("设备数据解析失败");
        }
      } else {
        widget.onToast(queryRes?["msg"] ?? "该位置暂无设备或设备离线");
      }
      
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onBack() {
    if (_step > 0) {
      setState(() {
        _step--;
        _titles.removeLast();
        _currentList = _historyLists.removeLast(); 
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
         
              _step > 0 
                ? GestureDetector(onTap: _onBack, child: const Icon(Icons.arrow_back_ios_new, size: 20, color: Color(0xFF2C2C2E))) 
                : const SizedBox(width: 20),
              Text(_titles.last, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF2C2C2E))),
              GestureDetector(onTap: widget.onScan, child: const Icon(Icons.qr_code_scanner, size: 22, color: Color(0xFF2C2C2E))),
 
            ]
          ),
          
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(5, (index) {
     
              bool isActive = index <= _step;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: index < 4 ? 8.0 : 0),
                  child: Column(
                    children: [
                
                      Text("${index + 1}", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isActive ? const Color(0xFF34C759) : Colors.grey[400])),
                      const SizedBox(height: 8),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 800), 
      
                        curve: Curves.easeInOutCubic, 
                        height: 8, 
                        decoration: BoxDecoration(
                          color: isActive ? 
                            const Color(0xFF34C759) : Colors.grey[200], 
                          borderRadius: BorderRadius.circular(100)
                        ),
                      ),
                    ],
   
                  ),
                )
              );
            }),
          ),
          const SizedBox(height: 24),

          Container(
            height: 320,
            alignment: Alignment.topCenter, 
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
           
              layoutBuilder: (currentChild, previousChildren) => Stack(alignment: Alignment.topCenter, children: <Widget>[...previousChildren, if (currentChild != null) currentChild]),
              child: _isLoading 
                ? const SkeletonList() 
                : _currentList.isEmpty
                  ? const Padding(padding: EdgeInsets.only(top: 40), child: Text("暂无数据", style: TextStyle(color: Colors.grey)))
      
                  : ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: _currentList.length,
                      itemBuilder: (c, i) => ListTile(
               
                        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                        title: Text(_currentList[i]["name"]!, style: const TextStyle(fontSize: 15, color: Color(0xFF2C2C2E))),
                        trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
                        onTap: 
                          () => _onItemTap(_currentList[i]),
                      )
                    )
            )
          )
        ]
      )
    );
  }
}

// ==========================================
// 辅助动画组件
// ==========================================
class SkeletonList extends StatefulWidget { 
  const SkeletonList({super.key}); 
  @override 
  State<SkeletonList> createState() => _SkeletonListState();
}

class _SkeletonListState extends State<SkeletonList> with SingleTickerProviderStateMixin { 
  late AnimationController _controller;
  @override 
  void initState() { 
    super.initState(); 
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat();
  } 
  
  @override 
  void dispose() { 
    _controller.dispose(); 
    super.dispose();
  } 
  
  @override 
  Widget build(BuildContext context) { 
    return Column(
      children: List.generate(8, (i) => Container(
        height: 38, 
        alignment: Alignment.centerLeft, 
        child: AnimatedBuilder(
          animation: _controller, 
          builder: (context, child) { 
            return ShaderMask(
     
              shaderCallback: (rect) { 
                return LinearGradient(
                  begin: Alignment.centerLeft, 
                  end: Alignment.centerRight, 
                  colors: [Colors.grey[200]!, Colors.grey[50]!, Colors.grey[200]!], 
         
                  stops: [_controller.value - 0.3, _controller.value, _controller.value + 0.3]
                ).createShader(rect); 
              }, 
              child: Container(
                height: 14, 
                width: i % 
                  2 == 0 ? 130 : 100, 
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(7))
              )
            );
          }
        )
      ))
    );
  } 
}

class ThreeDotsLoading extends StatefulWidget { 
  final Color color; 
  const ThreeDotsLoading({super.key, this.color = Colors.white});
  @override 
  State<ThreeDotsLoading> createState() => _ThreeDotsLoadingState(); 
}

class _ThreeDotsLoadingState extends State<ThreeDotsLoading> with TickerProviderStateMixin { 
  late AnimationController _controller;
  @override 
  void initState() { 
    super.initState(); 
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat();
  } 
  
  @override 
  void dispose() { 
    _controller.dispose(); 
    super.dispose();
  } 
  
  @override 
  Widget build(BuildContext context) { 
    return Row(
      mainAxisSize: MainAxisSize.min, 
      children: List.generate(3, (index) { 
        return AnimatedBuilder(
          animation: _controller, 
          builder: (context, child) { 
            double v = (sin((_controller.value * 2 * pi) - (index * 0.2 * 2 * pi)) + 1) 
              / 2; 
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2.5), 
              width: 7, 
              height: 7, 
              decoration: BoxDecoration(color: widget.color.withOpacity(0.4 + (v * 0.6)), shape: BoxShape.circle)
            ); 

          }
        ); 
      })
    );
  } 
}

class QRScannerPage extends StatelessWidget {
  const QRScannerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("扫描设备二维码", style: TextStyle(color: Colors.white, fontSize: 17)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Stack(
        children: [
          MobileScanner(
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              if (barcodes.isNotEmpty) {
                final String code = barcodes.first.rawValue ?? "";
                if (code.isNotEmpty) {
                  Navigator.pop(context, code);
                }
              }
            },
          ),
          Center(
            child: Container(
              width: 250, height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white.withOpacity(0.5), width: 1),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
