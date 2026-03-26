import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class UserProvider extends ChangeNotifier {
  String token = "";
  String userId = "";
  String userPhone = "";
  String userName = "User";
  String balance = "0.00";
  bool isRequesting = false;
  bool hasShownBalanceWarning = false;

  Future<void> loadFromLocal() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString('token') ?? "";
    userId = prefs.getString('userId') ?? "";
    userPhone = prefs.getString('userPhone') ?? "";
    userName = prefs.getString('userName') ?? "User";
    balance = prefs.getString('balance') ?? "0.00";
    notifyListeners();

    if (token.isNotEmpty) {
      await silentTokenGuard();
      await fetchUserInfo();
    }
  }

  void setRequesting(bool val) {
    isRequesting = val;
    notifyListeners();
  }

  Future<void> sendCode(String tel) async {
    if (tel.length != 11) return;
    setRequesting(true);
    await ApiService.post("user/sendRegisterMsg", {"tel": tel}, muteToast: false);
    setRequesting(false);
  }

  Future<bool> login(String tel, String code) async {
    if (tel.isEmpty || code.isEmpty) return false;
    setRequesting(true);
    final res = await ApiService.post("user/register", {"tel": tel, "code": code, "type": "5"});
    setRequesting(false);

    if (res != null && (res["code"] == 0 || res["code"] == "0")) {
      final prefs = await SharedPreferences.getInstance();
      token = res["data"]["token"];
      userId = res["data"]["userId"];
      userPhone = tel;
      await prefs.setString("userPhone", tel);
      await prefs.setString("token", token);
      await prefs.setString("userId", userId);
      notifyListeners();
      await silentTokenGuard();
      await fetchUserInfo();
      return true;
    }
    return false;
  }

  Future<void> silentTokenGuard() async {
    final res = await ApiService.post("user/queryUserWalletInfo", {}, token: token, userId: userId, muteToast: true);
    if (res != null) {
      if (res["code"] == 0 || res["code"] == "0") {
        balance = res["data"]["uBalance"].toString();
        checkLowBalance();
        notifyListeners();
      } else if (res["code"] == 401 || res["code"] == "401") {
        await logout();
      }
    }
  }

  Future<void> fetchUserInfo() async {
    final res = await ApiService.post("user/queryUserInfo", {}, token: token, userId: userId, muteToast: true);
    if (res != null && (res["code"] == 0 || res["code"] == "0") && res["data"] != null) {
      userName = res["data"]["userName"] ?? res["data"]["nickname"] ?? "User";
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString("userName", userName);
      notifyListeners();
    }
  }

  Future<void> syncBalance() async {
    await silentTokenGuard();
  }

  void checkLowBalance() {
    double bal = double.tryParse(balance) ?? 0.0;
    if (bal >= 5.0) {
      hasShownBalanceWarning = false;
    } else if (bal < 5.0 && !hasShownBalanceWarning) {
      hasShownBalanceWarning = true;
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    token = "";
    userId = "";
    userPhone = "";
    userName = "User";
    balance = "0.00";
    notifyListeners();
  }
}