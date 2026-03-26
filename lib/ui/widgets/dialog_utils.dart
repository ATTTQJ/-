import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/device_provider.dart';
import '../../providers/user_provider.dart';
import 'device_selector_dialog.dart';

class DialogUtils {
  static void showGlassBottomSheet(BuildContext context, Widget child) {
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
                          padding: const EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 24),
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

  static void showEditRemarkDialog(BuildContext context, String id, String currentName) {
    final deviceProvider = context.read<DeviceProvider>();
    TextEditingController editingController = TextEditingController(text: deviceProvider.customRemarks[id] ?? currentName);
    
    showGlassBottomSheet(
      context,
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("自定义设备备注", style: TextStyle(color: Color(0xFF2C2C2E), fontSize: 18, fontWeight: FontWeight.bold)),
              if (deviceProvider.customRemarks.containsKey(id))
                GestureDetector(
                  onTap: () {
                    deviceProvider.saveDeviceRemark(id, "");
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
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2C2C2E), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: () {
                    deviceProvider.saveDeviceRemark(id, editingController.text);
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

  static void showDeleteConfirmDialog(BuildContext context, String commonlyId, String deviceName) {
    showGlassBottomSheet(
      context,
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text("移除设备", style: TextStyle(color: Color(0xFF2C2C2E), fontSize: 18, fontWeight: FontWeight.bold)),
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
                  onPressed: () async {
                    Navigator.pop(context);
                    final userProvider = context.read<UserProvider>();
                    bool success = await context.read<DeviceProvider>().deleteDevice(commonlyId, userProvider.token, userProvider.userId);
                    if (success) ToastService.show("已移除常用设备");
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
  
  static void showCascadingAddDeviceDialog(BuildContext context) {
    showGlassBottomSheet(
      context,
      const DeviceSelectorDialog()
    );
  }

  // 新增方法：显示清空历史记录确认弹窗
  static void showClearHistoryConfirmDialog(BuildContext context) {
    showGlassBottomSheet(
      context,
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text("清空记录", style: TextStyle(color: Color(0xFF2C2C2E), fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          const Text(
            "确定要清空所有用水历史记录吗？\n此操作不可恢复。", 
            style: TextStyle(color: Color(0xFF666666), fontSize: 15, height: 1.5), 
            textAlign: TextAlign.center
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context), 
                  child: const Text("取消", style: TextStyle(color: Colors.grey))
                )
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent, 
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                  ),
                  onPressed: () {
                    context.read<WaterProvider>().clearHistory();
                    Navigator.pop(context);
                    ToastService.show("历史记录已清空");
                  },
                  child: const Text("确认清空", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                )
              )
            ],
          )
        ],
      )
    );
  }
}