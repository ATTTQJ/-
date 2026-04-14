import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/toast_service.dart';
import '../services/api_service.dart';

class UserProvider extends ChangeNotifier {
  final ImagePicker _imagePicker = ImagePicker();

  String token = "";
  String userId = "";
  String userPhone = "";
  String userName = "User";
  String balance = "0.00";
  String avatarUrl = "";
  String maskedPhone = "";
  String schoolName = "";
  String campusName = "";
  String buildingName = "";
  String floorName = "";
  String roomName = "";
  String addressInfo = "";
  String studentNo = "";
  String grade = "";
  bool isRealName = false;
  bool isRequesting = false;
  bool isUploadingAvatar = false;
  bool hasShownBalanceWarning = false;

  Future<void> loadFromLocal() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString('token') ?? "";
    userId = prefs.getString('userId') ?? "";
    userPhone = prefs.getString('userPhone') ?? "";
    userName = prefs.getString('userName') ?? "User";
    balance = prefs.getString('balance') ?? "0.00";
    avatarUrl = prefs.getString('avatarUrl') ?? "";
    maskedPhone = prefs.getString('maskedPhone') ?? "";
    schoolName = prefs.getString('schoolName') ?? "";
    campusName = prefs.getString('campusName') ?? "";
    buildingName = prefs.getString('buildingName') ?? "";
    floorName = prefs.getString('floorName') ?? "";
    roomName = prefs.getString('roomName') ?? "";
    addressInfo = prefs.getString('addressInfo') ?? "";
    studentNo = prefs.getString('studentNo') ?? "";
    grade = prefs.getString('grade') ?? "";
    isRealName = prefs.getBool('isRealName') ?? false;
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
    await ApiService.post("user/sendRegisterMsg", {
      "tel": tel,
    }, muteToast: false);
    setRequesting(false);
  }

  Future<bool> login(String tel, String code) async {
    if (tel.isEmpty || code.isEmpty) return false;
    setRequesting(true);
    final res = await ApiService.post("user/register", {
      "tel": tel,
      "code": code,
      "type": "5",
    });
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

  Future<bool> silentTokenGuard({bool showSuccessToast = false}) async {
    final res = await ApiService.post(
      "user/queryUserWalletInfo",
      {},
      token: token,
      userId: userId,
      muteToast: true,
    );
    if (res != null) {
      if (res["code"] == 0 || res["code"] == "0") {
        balance = res["data"]["uBalance"].toString();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString("balance", balance);
        checkLowBalance();
        notifyListeners();
        if (showSuccessToast) {
          ToastService.show('\u4f59\u989d\u5df2\u5237\u65b0');
        }
        return true;
      } else if (res["code"] == 401 || res["code"] == "401") {
        await logout();
      }
    }
    return false;
  }

  Future<void> fetchUserInfo() async {
    final res = await ApiService.post(
      "user/queryUserInfo",
      {},
      token: token,
      userId: userId,
      muteToast: true,
    );
    if (res != null &&
        (res["code"] == 0 || res["code"] == "0") &&
        res["data"] != null) {
      final data = Map<String, dynamic>.from(res["data"] as Map);
      _applyUserInfoData(data);
      final prefs = await SharedPreferences.getInstance();
      await _persistProfile(prefs);
      notifyListeners();
    }
  }

  Future<bool> pickAndUploadAvatar() async {
    if (token.trim().isEmpty || userId.trim().isEmpty || isUploadingAvatar) {
      return false;
    }

    final pickedFile = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 95,
    );
    if (pickedFile == null) {
      return false;
    }

    try {
      isUploadingAvatar = true;
      notifyListeners();

      final croppedFile = await ImageCropper().cropImage(
        sourcePath: pickedFile.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        maxWidth: 500,
        maxHeight: 500,
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 92,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: '裁剪头像',
            toolbarColor: const Color(0xFF111318),
            toolbarWidgetColor: Colors.white,
            backgroundColor: const Color(0xFF111318),
            activeControlsWidgetColor: const Color(0xFF7C5CFF),
            dimmedLayerColor: const Color(0xCC000000),
            cropFrameColor: Colors.white,
            cropGridColor: Colors.white24,
            hideBottomControls: true,
            lockAspectRatio: true,
            initAspectRatio: CropAspectRatioPreset.square,
          ),
          IOSUiSettings(
            title: '裁剪头像',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
            aspectRatioPickerButtonHidden: true,
            rotateButtonsHidden: true,
            rotateClockwiseButtonHidden: true,
            doneButtonTitle: '完成',
            cancelButtonTitle: '取消',
          ),
        ],
      );
      if (croppedFile == null) {
        return false;
      }

      final croppedBytes = await croppedFile.readAsBytes();
      final fileName = _buildAvatarFileName();

      final success = await ApiService.uploadUserAvatar(
        token: token,
        userId: userId,
        fileBytes: croppedBytes,
        fileName: fileName,
      );

      if (success) {
        await fetchUserInfo();
        ToastService.show('头像已更新');
      }

      return success;
    } catch (_) {
      ToastService.show('头像处理失败，请重试');
      return false;
    } finally {
      isUploadingAvatar = false;
      notifyListeners();
    }
  }

  Future<void> syncBalance({bool showToast = false}) async {
    await silentTokenGuard(showSuccessToast: showToast);
  }

  Future<void> setBalance(String newBalance) async {
    balance = newBalance;
    checkLowBalance();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("balance", balance);
    notifyListeners();
  }

  void checkLowBalance() {
    final bal = double.tryParse(balance) ?? 0.0;
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
    avatarUrl = "";
    maskedPhone = "";
    schoolName = "";
    campusName = "";
    buildingName = "";
    floorName = "";
    roomName = "";
    addressInfo = "";
    studentNo = "";
    grade = "";
    isRealName = false;
    isUploadingAvatar = false;
    notifyListeners();
  }

  Future<void> _persistProfile(SharedPreferences prefs) async {
    await prefs.setString("userPhone", userPhone);
    await prefs.setString("userName", userName);
    await prefs.setString("avatarUrl", avatarUrl);
    await prefs.setString("maskedPhone", maskedPhone);
    await prefs.setString("schoolName", schoolName);
    await prefs.setString("campusName", campusName);
    await prefs.setString("buildingName", buildingName);
    await prefs.setString("floorName", floorName);
    await prefs.setString("roomName", roomName);
    await prefs.setString("addressInfo", addressInfo);
    await prefs.setString("studentNo", studentNo);
    await prefs.setString("grade", grade);
    await prefs.setBool("isRealName", isRealName);
  }

  void _applyUserInfoData(Map<String, dynamic> data) {
    userPhone = _pickFirstNonEmpty([
      data["uPhone"]?.toString(),
      userPhone,
    ], fallback: "");
    userName = _pickFirstNonEmpty([
      data["uName"]?.toString(),
      data["userName"]?.toString(),
      data["nickName"]?.toString(),
      userName,
    ], fallback: "User");
    avatarUrl = _normalizeAvatarUrl(
      _pickFirstNonEmpty([
        data["uPicture_new"]?.toString(),
        data["uPicture"]?.toString(),
        avatarUrl,
      ], fallback: ""),
    );
    maskedPhone = _pickFirstNonEmpty([
      data["home_top_title"]?.toString(),
      _maskPhone(userPhone),
      maskedPhone,
    ], fallback: "");
    schoolName = data["schoolName"]?.toString() ?? "";
    campusName = data["arName"]?.toString() ?? "";
    buildingName = data["buName"]?.toString() ?? "";
    floorName = data["flName"]?.toString() ?? "";
    roomName = data["rnName"]?.toString() ?? "";
    addressInfo = data["addressInfo"]?.toString() ?? "";
    studentNo = data["uStuNum"]?.toString() ?? "";
    grade = data["grade"]?.toString() ?? "";

    final realNameValue = data["isRealName"] ?? data["isRealNmeFlag"];
    isRealName =
        realNameValue == true || realNameValue == 1 || realNameValue == "1";
  }

  String _pickFirstNonEmpty(List<String?> values, {required String fallback}) {
    for (final value in values) {
      if (value != null && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return fallback;
  }

  String _maskPhone(String phone) {
    if (phone.length < 11) {
      return phone;
    }
    return '${phone.substring(0, 3)}********';
  }

  String _normalizeAvatarUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return "";
    }
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    return 'https://h5.uyxy.xin:9000$trimmed';
  }

  String _buildAvatarFileName() {
    final now = DateTime.now();
    final date =
        now.year.toString().padLeft(4, '0') +
        now.month.toString().padLeft(2, '0') +
        now.day.toString().padLeft(2, '0');
    final time =
        now.hour.toString().padLeft(2, '0') +
        now.minute.toString().padLeft(2, '0') +
        now.second.toString().padLeft(2, '0');
    return 'IMG_${date}_${time}_CROP.jpg';
  }
}
