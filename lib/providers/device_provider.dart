import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class DeviceProvider extends ChangeNotifier {
  List<Map<String, dynamic>> deviceList = [];
  String selectedDeviceId = "";
  Map<String, String> customRemarks = {};
  bool isAlwaysExpanded = false;
  bool isRequesting = false;

  Future<void> loadFromLocal(String token, String userId) async {
    final prefs = await SharedPreferences.getInstance();
    isAlwaysExpanded = prefs.getBool('always_expanded') ?? false;

    String? remarksStr = prefs.getString('device_remarks');
    if (remarksStr != null && remarksStr.isNotEmpty) {
      try {
        customRemarks = Map<String, String>.from(jsonDecode(remarksStr));
      } catch (e) {}
    }

    String? savedListStr = prefs.getString('saved_device_list');
    if (savedListStr != null && savedListStr.isNotEmpty) {
      try {
        List<dynamic> decoded = jsonDecode(savedListStr);
        deviceList = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
        if (deviceList.isNotEmpty && selectedDeviceId.isEmpty) {
          selectedDeviceId = deviceList[0]["deviceInfId"].toString();
        }
        notifyListeners();
      } catch (e) {}
    }
    
    if (token.isNotEmpty) {
      await refreshDeviceListFromNet(token, userId);
    }
  }

  void selectDevice(String id) {
    selectedDeviceId = id;
    notifyListeners();
  }

  void setAlwaysExpanded(bool val) async {
    isAlwaysExpanded = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('always_expanded', val);
    notifyListeners();
  }

  Future<void> saveDeviceRemark(String id, String remark) async {
    if (remark.trim().isEmpty) {
      customRemarks.remove(id);
    } else {
      customRemarks[id] = remark.trim();
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('device_remarks', jsonEncode(customRemarks));
    notifyListeners();
  }

  Future<void> refreshDeviceListFromNet(String token, String userId) async {
    final res = await ApiService.post("device/findDeviceCommonlyByUserId", {}, token: token, userId: userId, muteToast: true);
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
      
      deviceList = processedList;
      if (deviceList.isNotEmpty && !deviceList.any((d) => d["deviceInfId"].toString() == selectedDeviceId)) {
         selectedDeviceId = deviceList[0]["deviceInfId"].toString();
      } else if (deviceList.isEmpty) {
         selectedDeviceId = "";
      }
      
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_device_list', jsonEncode(deviceList));
    }
  }

  Future<bool> deleteDevice(String commonlyId, String token, String userId) async {
    isRequesting = true;
    notifyListeners();
    var res = await ApiService.post("device/operationDeviceCommonly", {
      "commonlyId": commonlyId,
      "type": "2"
    }, token: token, userId: userId);
    isRequesting = false;
    notifyListeners();

    if (res != null && (res["code"] == 0 || res["code"] == "0" || res["code"] == 200)) {
      await refreshDeviceListFromNet(token, userId);
      return true;
    }
    return false;
  }
}