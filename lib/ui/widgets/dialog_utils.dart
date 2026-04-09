import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/toast_service.dart';
import '../../providers/device_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/water_provider.dart';
import 'device_selector_dialog.dart';

class DialogUtils {
  static void showGlassBottomSheet(BuildContext context, Widget child) {
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'GlassBottomSheet',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 560),
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
              child: Container(color: const Color(0x72090B10)),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: AnimatedPadding(
                padding: EdgeInsets.only(bottom: keyboardHeight),
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                child: Container(
                  margin: const EdgeInsets.only(
                    left: 18,
                    right: 18,
                    bottom: 20,
                  ),
                  width: double.infinity,
                  constraints: BoxConstraints(maxHeight: maxDialogHeight),
                  decoration: ShapeDecoration(
                    color: const Color(0xF2171A20),
                    shape: ContinuousRectangleBorder(
                      borderRadius: BorderRadius.circular(36),
                      side: BorderSide(
                        color: Colors.white.withOpacity(0.06),
                        width: 0.6,
                      ),
                    ),
                    shadows: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.28),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Padding(
                            padding: const EdgeInsets.all(22),
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
        final animation = CurvedAnimation(
          parent: anim1,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInOutCubic,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.16),
            end: Offset.zero,
          ).animate(animation),
          child: child,
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
                'Edit Device Name',
                style: TextStyle(
                  color: Colors.white,
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
                    'Reset',
                    style: TextStyle(
                      color: Colors.redAccent,
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
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'For example: My Shower or Dorm 536',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: Colors.white.withOpacity(0.08),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
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
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7A58FF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    deviceProvider.saveDeviceRemark(id, editingController.text);
                    Navigator.pop(context);
                  },
                  child: const Text(
                    'Save',
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
            'Remove Device',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Remove "$deviceName" from your saved devices?',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 15,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
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
                      ToastService.show('Device removed');
                    }
                  },
                  child: const Text(
                    'Remove',
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
            'Clear History',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Clear all water usage history? This action cannot be undone.',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 15,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    context.read<WaterProvider>().clearHistory();
                    Navigator.pop(context);
                    ToastService.show('History cleared');
                  },
                  child: const Text(
                    'Clear',
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
          Icon(Icons.access_time_rounded, color: Colors.orange[400], size: 48),
          const SizedBox(height: 16),
          const Text(
            '\u975e\u70ed\u6c34\u4f9b\u5e94\u65f6\u6bb5',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '\u5f53\u524d\u4e0d\u5728\u89c4\u5b9a\u7684\u70ed\u6c34\u4f9b\u5e94\u65f6\u6bb5\u3002\n(06:00-09:30\u300111:30-14:30\u300118:00-23:50)\n\n\u6b64\u65f6\u5f00\u542f\u53ef\u80fd\u53ea\u6709\u51b7\u6c34\uff0c\u662f\u5426\u7ee7\u7eed\uff1f',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    '\u53d6\u6d88',
                    style: TextStyle(
                      color: Colors.white54,
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
                    backgroundColor: Colors.orange,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    onContinue();
                  },
                  child: const Text(
                    '\u7ee7\u7eed\u4f7f\u7528',
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
