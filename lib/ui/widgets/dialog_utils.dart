import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/toast_service.dart';
import '../../providers/device_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/water_provider.dart';
import 'device_selector_dialog.dart';

class DialogUtils {
  static const Color sheetBackgroundColor = Color(0xFF171A20);
  static const Color surfaceBackgroundColor = Color(0xFF222731);
  static const Color borderColor = Color(0x24FFFFFF);
  static const Color titleColor = Colors.white;
  static const Color bodyColor = Color(0xB3FFFFFF);
  static const Color mutedColor = Color(0x80FFFFFF);
  static const Color primaryColor = Color(0xFF7C5CFF);
  static const Color dangerColor = Color(0xFFB85C6B);
  static const Color warningColor = Color(0xFFE09A3E);

  static Future<T?> showGlassDialog<T>(
    BuildContext context,
    Widget child, {
    bool barrierDismissible = true,
    double maxWidth = 420,
    EdgeInsets insetPadding = const EdgeInsets.symmetric(
      horizontal: 24,
      vertical: 32,
    ),
  }) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierLabel: 'GlassDialog',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (context, anim1, anim2) {
        final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

        return Stack(
          children: [
            GestureDetector(
              onTap: barrierDismissible ? () => Navigator.pop(context) : null,
              child: Container(color: Colors.transparent),
            ),
            Center(
              child: AnimatedPadding(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                padding: insetPadding.add(
                  EdgeInsets.only(bottom: keyboardHeight),
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      decoration: BoxDecoration(
                        color: sheetBackgroundColor,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: borderColor),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x66000000),
                            blurRadius: 28,
                            offset: Offset(0, 14),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                        child: child,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return Stack(
          children: [
            BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: 4 * curved.value,
                sigmaY: 4 * curved.value,
              ),
              child: Container(color: Colors.transparent),
            ),
            FadeTransition(
              opacity: curved,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
                child: child,
              ),
            ),
          ],
        );
      },
    );
  }

  static void showGlassBottomSheet(BuildContext context, Widget child) {
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'GlassBottomSheet',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 600),
      pageBuilder: (context, anim1, anim2) {
        final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
        final screenHeight = MediaQuery.of(context).size.height;
        var maxDialogHeight = screenHeight - keyboardHeight - 80;
        if (maxDialogHeight < 200) {
          maxDialogHeight = 200;
        }

        return Stack(
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(color: Colors.transparent),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: AnimatedPadding(
                padding: EdgeInsets.only(bottom: keyboardHeight),
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                child: Container(
                  margin: const EdgeInsets.only(
                    left: 20,
                    right: 20,
                    bottom: 20,
                  ),
                  width: double.infinity,
                  constraints: BoxConstraints(maxHeight: maxDialogHeight),
                  decoration: ShapeDecoration(
                    color: sheetBackgroundColor,
                    shape: ContinuousRectangleBorder(
                      borderRadius: BorderRadius.circular(45),
                    ),
                    shadows: const [
                      BoxShadow(
                        color: Color(0x66000000),
                        blurRadius: 28,
                        offset: Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22.5),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22.5),
                          border: Border.all(color: borderColor),
                        ),
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: child,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        final curve = Curves.easeOutCubic;
        return Stack(
          children: [
            BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: 4.5 * curve.transform(anim1.value),
                sigmaY: 4.5 * curve.transform(anim1.value),
              ),
              child: Container(color: Colors.transparent),
            ),
            SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 1),
                end: Offset.zero,
              ).animate(CurvedAnimation(parent: anim1, curve: curve)),
              child: child,
            ),
          ],
        );
      },
    );
  }

  static void showEditRemarkDialog(
    BuildContext context,
    String id,
    String currentName,
  ) {
    final deviceProvider = context.read<DeviceProvider>();
    final editingController = TextEditingController(
      text: deviceProvider.customRemarks[id] ?? currentName,
    );

    showGlassBottomSheet(
      context,
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '修改设备名称',
                style: TextStyle(
                  color: titleColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (deviceProvider.customRemarks.containsKey(id))
                GestureDetector(
                  onTap: () {
                    deviceProvider.saveDeviceRemark(id, '');
                    Navigator.pop(context);
                  },
                  child: const Text(
                    '重置',
                    style: TextStyle(
                      color: dangerColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: editingController,
            autofocus: true,
            style: const TextStyle(
              color: titleColor,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText: '例如：536宿舍热水',
              hintStyle: const TextStyle(color: mutedColor),
              filled: true,
              fillColor: surfaceBackgroundColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: primaryColor),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消', style: TextStyle(color: mutedColor)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    deviceProvider.saveDeviceRemark(id, editingController.text);
                    Navigator.pop(context);
                  },
                  child: const Text(
                    '保存',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static void showDeleteConfirmDialog(
    BuildContext context,
    String commonlyId,
    String deviceName,
  ) {
    final userProvider = context.read<UserProvider>();
    final deviceProvider = context.read<DeviceProvider>();
    showGlassBottomSheet(
      context,
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '删除设备',
            style: TextStyle(
              color: titleColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '确认将“$deviceName”从常用设备中移除？',
            style: const TextStyle(color: bodyColor, fontSize: 15, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消', style: TextStyle(color: mutedColor)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: dangerColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () async {
                    Navigator.pop(context);
                    final success = await deviceProvider.deleteDevice(
                      commonlyId,
                      userProvider.token,
                      userProvider.userId,
                    );
                    if (success) {
                      ToastService.show('设备已删除');
                    }
                  },
                  child: const Text(
                    '删除',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static void showCascadingAddDeviceDialog(BuildContext context) {
    showGlassBottomSheet(context, const DeviceSelectorDialog());
  }

  static void showClearHistoryConfirmDialog(BuildContext context) {
    showGlassBottomSheet(
      context,
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '清空记录',
            style: TextStyle(
              color: titleColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '确认清空全部用水记录？该操作无法撤销。',
            style: TextStyle(color: bodyColor, fontSize: 15, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消', style: TextStyle(color: mutedColor)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: dangerColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    context.read<WaterProvider>().clearHistory();
                    Navigator.pop(context);
                    ToastService.show('记录已清空');
                  },
                  child: const Text(
                    '清空',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static void showHotWaterTimeWarningDialog(
    BuildContext context, {
    required VoidCallback onContinue,
  }) {
    showGlassBottomSheet(
      context,
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.access_time_rounded, color: warningColor, size: 48),
          const SizedBox(height: 16),
          const Text(
            '非热水供应时段',
            style: TextStyle(
              color: titleColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '当前不在规定的热水供应时段。\n(06:00-09:30、11:30-14:30、18:00-23:50)\n\n此时开启可能只有冷水，是否继续？',
            style: TextStyle(color: bodyColor, fontSize: 14, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    '取消',
                    style: TextStyle(
                      color: mutedColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: warningColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    onContinue();
                  },
                  child: const Text(
                    '继续使用',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
