import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/toast_service.dart';
import '../../providers/device_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/water_provider.dart';
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
          const Text(
            'Logout',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2C2C2E),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '\u786e\u5b9a\u8981\u9000\u51fa\u5f53\u524d\u8d26\u53f7\u5417\uff1f',
            style: TextStyle(color: Color(0xFF666666), fontSize: 15),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    '\u53d6\u6d88',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ),
              ),
              Expanded(
                child: TextButton(
                  onPressed: () {
                    context.read<UserProvider>().logout();
                    Navigator.pop(context);
                  },
                  child: const Text(
                    '\u9000\u51fa\u767b\u5f55',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontSize: 16,
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

  bool _isWithinHotWaterWindow(DateTime now) {
    final currentMinutes = now.hour * 60 + now.minute;
    final inSlot1 = currentMinutes >= 6 * 60 && currentMinutes <= 9 * 60 + 30;
    final inSlot2 =
        currentMinutes >= 11 * 60 + 30 && currentMinutes <= 14 * 60 + 30;
    final inSlot3 =
        currentMinutes >= 18 * 60 && currentMinutes <= 23 * 60 + 50;
    return inSlot1 || inSlot2 || inSlot3;
  }

  Future<void> _startWater(
    BuildContext context,
    UserProvider userProvider,
    WaterProvider waterProvider,
    DeviceProvider deviceProvider,
    Map<String, dynamic> targetDevice, {
    bool force = false,
  }) async {
    final targetBillType = targetDevice['billType']?.toString() ?? '';
    if (!force && targetBillType == '2' && !_isWithinHotWaterWindow(DateTime.now())) {
      DialogUtils.showHotWaterTimeWarningDialog(
        context,
        onContinue: () {
          _startWater(
            context,
            userProvider,
            waterProvider,
            deviceProvider,
            targetDevice,
            force: true,
          );
        },
      );
      return;
    }

    await waterProvider.startWater(
      userProvider.token,
      userProvider.userId,
      targetDevice,
      currentBalance: userProvider.balance,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<UserProvider, WaterProvider, DeviceProvider>(
      builder: (context, userProvider, waterProvider, deviceProvider, child) {
        final working = waterProvider.orderNum.isNotEmpty;
        final phoneDisplay = userProvider.userPhone.length >= 11
            ? '*******${userProvider.userPhone.substring(7)}'
            : '*******';

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  phoneDisplay,
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ),
              GestureDetector(
                onTap: () async {
                  if (waterProvider.isRequesting) {
                    return;
                  }

                  if (working) {
                    Map<String, dynamic>? selectedDevice;
                    try {
                      selectedDevice = deviceProvider.deviceList.firstWhere(
                        (d) =>
                            d['deviceInfId'].toString() ==
                            deviceProvider.selectedDeviceId,
                      );
                    } catch (_) {}

                    var currentDeviceName = '';
                    if (selectedDevice != null) {
                      currentDeviceName =
                          deviceProvider.customRemarks[
                              deviceProvider.selectedDeviceId] ??
                              selectedDevice['deviceInfName'].toString();
                      if (currentDeviceName.contains('-')) {
                        currentDeviceName = currentDeviceName.split('-').last;
                      }
                      currentDeviceName +=
                          (selectedDevice['billType'] == 2 ? '\u70ed\u6c34' : '\u76f4\u996e');
                    }

                    await waterProvider.stopWater(
                      userProvider.token,
                      userProvider.userId,
                      currentDeviceName,
                      currentBalance: userProvider.balance,
                      onBalanceUpdated: userProvider.setBalance,
                    );
                    return;
                  }

                  if (deviceProvider.selectedDeviceId.isEmpty) {
                    ToastService.show('\u8bf7\u5148\u9009\u62e9\u8bbe\u5907');
                    return;
                  }

                  final targetDevice = deviceProvider.deviceList.firstWhere(
                    (d) =>
                        d['deviceInfId'].toString() ==
                        deviceProvider.selectedDeviceId,
                    orElse: () => deviceProvider.deviceList[0],
                  );

                  await _startWater(
                    context,
                    userProvider,
                    waterProvider,
                    deviceProvider,
                    targetDevice,
                  );
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 115,
                  height: 115,
                  decoration: ShapeDecoration(
                    color: working ? Colors.redAccent : const Color(0xFF1660AB),
                    shape: ContinuousRectangleBorder(
                      borderRadius: BorderRadius.circular(50),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: waterProvider.isRequesting
                      ? const ThreeDotsLoading()
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              working ? 'STOP' : 'OPEN',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (working)
                              Text(
                                waterProvider.runningTime,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                          ],
                        ),
                ),
              ),
              Expanded(
                child: Align(
                  alignment: Alignment.bottomRight,
                  child: GestureDetector(
                    onTap: () => _showLogoutConfirm(context),
                    child: const Text(
                      '\u9000\u51fa\u767b\u5f55',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class ThreeDotsLoading extends StatefulWidget {
  final Color color;

  const ThreeDotsLoading({super.key, this.color = Colors.white});

  @override
  State<ThreeDotsLoading> createState() => _ThreeDotsLoadingState();
}

class _ThreeDotsLoadingState extends State<ThreeDotsLoading>
    with TickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat();
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
            final value =
                (sin((_controller.value * 2 * pi) - (index * 0.2 * 2 * pi)) +
                        1) /
                    2;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2.5),
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: widget.color.withOpacity(0.4 + (value * 0.6)),
                shape: BoxShape.circle,
              ),
            );
          },
        );
      }),
    );
  }
}
