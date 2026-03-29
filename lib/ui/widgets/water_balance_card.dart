import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/device_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/water_provider.dart';

class WaterBalanceCard extends StatelessWidget {
  const WaterBalanceCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer3<UserProvider, DeviceProvider, WaterProvider>(
      builder: (context, userProvider, deviceProvider, waterProvider, child) {
        final selectedDevice = _selectedDevice(deviceProvider);
        final deviceName = selectedDevice == null
            ? '\u672a\u9009\u62e9\u8bbe\u5907'
            : _deviceName(deviceProvider, selectedDevice);
        final isWorking = waterProvider.orderNum.isNotEmpty;

        return GestureDetector(
          onTap: () => userProvider.syncBalance(showToast: true),
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF2C313A).withValues(alpha: 0.92),
                  const Color(0xFF16191F).withValues(alpha: 0.98),
                ],
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x44000000),
                  blurRadius: 24,
                  offset: Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.account_balance_wallet_rounded,
                            size: 15,
                            color: Color(0xFFB5C6FF),
                          ),
                          SizedBox(width: 6),
                          Text(
                            '\u4f59\u989d',
                            style: TextStyle(
                              color: Color(0xFFC7D1F2),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF47C6FF).withValues(
                          alpha: isWorking ? 0.16 : 0.08,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        isWorking ? '\u6b63\u5728\u4f7f\u7528' : '\u70b9\u51fb\u5237\u65b0',
                        style: TextStyle(
                          color: isWorking
                              ? const Color(0xFF95ECFF)
                              : const Color(0xFFD6F7FF),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '\u00A5 ${userProvider.balance}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '\u70b9\u51fb\u5361\u7247\u53ef\u5237\u65b0\u94b1\u5305\u4f59\u989d',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.54),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _InfoCell(
                        label: '\u5f53\u524d\u8bbe\u5907',
                        value: deviceName,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _InfoCell(
                        label: '\u7528\u6c34\u72b6\u6001',
                        value: isWorking
                            ? '\u5df2\u6301\u7eed ${waterProvider.runningTime}'
                            : '\u5f53\u524d\u672a\u4f7f\u7528',
                        accent: isWorking,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static Map<String, dynamic>? _selectedDevice(DeviceProvider deviceProvider) {
    if (deviceProvider.deviceList.isEmpty) {
      return null;
    }

    for (final device in deviceProvider.deviceList) {
      if (device['deviceInfId'].toString() == deviceProvider.selectedDeviceId) {
        return device;
      }
    }

    return deviceProvider.deviceList.first;
  }

  static String _deviceName(
    DeviceProvider deviceProvider,
    Map<String, dynamic> device,
  ) {
    final id = device['deviceInfId'].toString();
    return deviceProvider.customRemarks[id] ??
        device['deviceInfName'].toString().replaceAll(RegExp(r'^[12]-'), '');
  }
}

class _InfoCell extends StatelessWidget {
  const _InfoCell({
    required this.label,
    required this.value,
    this.accent = false,
  });

  final String label;
  final String value;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent
            ? const Color(0xFF4A63FF).withValues(alpha: 0.18)
            : Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: accent
              ? const Color(0xFF6D88FF).withValues(alpha: 0.26)
              : Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.58),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
