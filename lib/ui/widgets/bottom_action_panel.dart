import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/water_provider.dart';
import '../../providers/device_provider.dart';
import '../../core/toast_service.dart';
import 'dialog_utils.dart';

class BottomActionPanel extends StatelessWidget {
  const BottomActionPanel({super.key});

  void _showLogoutConfirm(BuildContext context) {
    DialogUtils.showGlassBottomSheet(
      context,
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Logout", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2C2C2E))),
          const SizedBox(height: 16),
          const Text("确定要退出当前账号吗？", style: TextStyle(color: Color(0xFF666666), fontSize: 15)),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context), 
                  child: const Text("取消", style: TextStyle(color: Colors.grey, fontSize: 16))
                )
              ),
              Expanded(
                child: TextButton(
                  onPressed: () {
                    context.read<UserProvider>().logout();
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

  @override
  Widget build(BuildContext context) {
    return Consumer3<UserProvider, WaterProvider, DeviceProvider>(
      builder: (context, userProvider, waterProvider, deviceProvider, child) {
        bool working = waterProvider.orderNum.isNotEmpty;
        String phoneDisplay = userProvider.userPhone.length >= 11 
            ? "*******${userProvider.userPhone.substring(7)}" 
            : "*******";

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(phoneDisplay, style: const TextStyle(color: Colors.grey, fontSize: 13))
              ),
              GestureDetector(
                onTap: () async {
                  if (waterProvider.isRequesting) return;
                  
                  if (working) {
                    Map<String, dynamic>? selectedDevice;
                    try {
                      selectedDevice = deviceProvider.deviceList.firstWhere(
                        (d) => d["deviceInfId"].toString() == deviceProvider.selectedDeviceId
                      );
                    } catch (e) {}
                    
                    String currentDeviceName = "";
                    if (selectedDevice != null) {
                      currentDeviceName = deviceProvider.customRemarks[deviceProvider.selectedDeviceId] 
                          ?? selectedDevice["deviceInfName"].toString();
                      if (currentDeviceName.contains("-")) {
                        currentDeviceName = currentDeviceName.split("-").last;
                      }
                      currentDeviceName += (selectedDevice["billType"] == 2 ? "热水" : "直饮");
                    }
                    
                    waterProvider.stopWater(userProvider.token, userProvider.userId, currentDeviceName);
                  } else {
                    if (deviceProvider.selectedDeviceId.isEmpty) {
                      ToastService.show("请先选择设备");
                      return;
                    }
                    
                    Map<String, dynamic> targetDevice = deviceProvider.deviceList.firstWhere(
                      (d) => d["deviceInfId"].toString() == deviceProvider.selectedDeviceId, 
                      orElse: () => deviceProvider.deviceList[0]
                    );
                    
                    waterProvider.startWater(userProvider.token, userProvider.userId, targetDevice);
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 115, 
                  height: 115,
                  decoration: ShapeDecoration(
                    color: working ? Colors.redAccent : const Color(0xFF1660AB), 
                    shape: ContinuousRectangleBorder(borderRadius: BorderRadius.circular(50))
                  ),
                  alignment: Alignment.center,
                  child: waterProvider.isRequesting 
                    ? const ThreeDotsLoading() 
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(working ? "STOP" : "OPEN", style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                          if (working) Text(waterProvider.runningTime, style: const TextStyle(color: Colors.white70, fontSize: 13))
                        ]
                      )
                )
              ),
              Expanded(
                child: Align(
                  alignment: Alignment.bottomRight,
                  child: GestureDetector(
                    onTap: () => _showLogoutConfirm(context),
                    child: const Text("退出登录", style: TextStyle(color: Colors.grey, fontSize: 13))
                  )
                )
              )
            ]
          )
        );
      }
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
            double v = (sin((_controller.value * 2 * pi) - (index * 0.2 * 2 * pi)) + 1) / 2;
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