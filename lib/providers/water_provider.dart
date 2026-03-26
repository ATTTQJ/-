import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../core/toast_service.dart';

class WaterProvider extends ChangeNotifier {
  String orderNum = "";
  String tableName = "";
  String mac = "";
  bool isRequesting = false;
  List<String> history = [];
  
  DateTime? startTime;
  Timer? timer;
  String runningTime = "00:00";
  
  final MethodChannel _siriChannel = const MethodChannel('com.fakeuy.water/siri');

  Future<void> loadFromLocal() async {
    final prefs = await SharedPreferences.getInstance();
    orderNum = prefs.getString('water_orderNum') ?? "";
    tableName = prefs.getString('water_tableName') ?? "";
    mac = prefs.getString('water_mac') ?? "";
    history = prefs.getStringList('water_history') ?? [];

    int savedStartTime = prefs.getInt('water_start_time') ?? 0;
    if (orderNum.isNotEmpty && savedStartTime > 0) {
      startTime = DateTime.fromMillisecondsSinceEpoch(savedStartTime);
      timer?.cancel();
      timer = Timer.periodic(const Duration(seconds: 1), (t) {
        final diff = DateTime.now().difference(startTime!);
        runningTime = "${diff.inMinutes.toString().padLeft(2, '0')}:${(diff.inSeconds % 60).toString().padLeft(2, '0')}";
        notifyListeners();
      });
    }
    notifyListeners();
  }

  Future<void> checkPendingAction(Function(String) onSelectDevice, List<Map<String, dynamic>> deviceList, Map<String, String> customRemarks) async {
    try {
      final res = await _siriChannel.invokeMethod('getPendingAction');
      if (res != null && res is Map) {
        String action = res["action"]?.toString() ?? "";
        String targetName = res["device"]?.toString() ?? "";

        if (action.isEmpty) return;

        int retry = 0;
        while (deviceList.isEmpty && retry < 30) {
          await Future.delayed(const Duration(milliseconds: 200));
          retry++;
        }

        if (action == "start") {
          if (targetName.isNotEmpty && deviceList.isNotEmpty) {
            for (var d in deviceList) {
              String id = d["deviceInfId"].toString();
              String name = (customRemarks[id] ?? d["deviceInfName"].toString()).toLowerCase();
              String search = targetName.toLowerCase();
              if (name.contains(search) || search.contains(name)) {
                onSelectDevice(id);
                break;
              }
            }
          }
        } else if (action == "stop") {
        }
      }
    } catch (e) {}
  }

  Future<bool> startWater(String token, String userId, Map<String, dynamic> device) async {
    isRequesting = true;
    notifyListeners();

    String targetDeviceId = device["deviceInfId"].toString();
    String targetBillType = device["billType"].toString();

    try {
      await ApiService.post("device/useEquipment", {
        "orderWay": "1", "theConnectionMethod": "2", "deviceInfId": targetDeviceId, "billType": targetBillType, "lackBalance": "lackBalance", "type": "1"
      }, token: token, userId: userId, muteToast: true);
      
      await Future.delayed(const Duration(milliseconds: 550));
      
      var res2 = await ApiService.post("device/useEquipment", {
        "orderWay": "1", "theConnectionMethod": "2", "deviceInfId": targetDeviceId, "billType": targetBillType, "lackBalance": "lackBalance", "type": "0"
      }, token: token, userId: userId);

      if (res2 != null && (res2["code"] == 0 || res2["code"] == "0")) {
        startTime = DateTime.now();
        orderNum = res2["data"]["orderNum"]?.toString() ?? "";
        tableName = res2["data"]["tableName"]?.toString() ?? "";
        mac = res2["data"]["mac"]?.toString() ?? "";
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('water_orderNum', orderNum);
        await prefs.setString('water_tableName', tableName);
        await prefs.setString('water_mac', mac);
        await prefs.setInt('water_start_time', startTime!.millisecondsSinceEpoch);
        
        timer = Timer.periodic(const Duration(seconds: 1), (t) {
          final diff = DateTime.now().difference(startTime!);
          runningTime = "${diff.inMinutes.toString().padLeft(2, '0')}:${(diff.inSeconds % 60).toString().padLeft(2, '0')}";
          notifyListeners();
        });
        
        ToastService.show("已开启");
        isRequesting = false;
        notifyListeners();
        return true;
      }
    } finally {
      isRequesting = false;
      notifyListeners();
    }
    return false;
  }

  Future<void> stopWater(String token, String userId, String currentDeviceName) async {
    if (orderNum.isEmpty) return;
    
    isRequesting = true;
    notifyListeners();
    
    String finalTime = runningTime;
    
    try {
      final res = await ApiService.post("device/endEquipment", {
        "orderNum": orderNum, "mac": mac, "tableName": tableName
      }, token: token, userId: userId);

      if (res != null && (res["code"] == 0 || res["code"] == "0")) {
        timer?.cancel();
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('water_orderNum');
        await prefs.remove('water_tableName');
        await prefs.remove('water_mac');
        await prefs.remove('water_start_time');
        
        orderNum = "";
        tableName = "";
        mac = "";
        runningTime = "00:00";
        
        ToastService.show("用水已停止，用时 $finalTime", durationMs: 4000);
        
        // --- 修改部分开始 ---
        history.insert(0, "${DateFormat('MM-dd HH:mm').format(DateTime.now())} ($currentDeviceName 用时$finalTime)");
        if (history.length > 50) {
          history = history.sublist(0, 50);
        }
        await prefs.setStringList('water_history', history);
        // --- 修改部分结束 ---
      }
    } finally {
      isRequesting = false;
      notifyListeners();
    }
  }

  // --- 新增方法 ---
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
}