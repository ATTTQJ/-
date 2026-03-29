import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/toast_service.dart';
import '../../models/water_usage_history_entry.dart';
import '../../providers/device_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/water_provider.dart';
import 'dialog_utils.dart';

class DeviceShowcase extends StatefulWidget {
  const DeviceShowcase({super.key});

  @override
  State<DeviceShowcase> createState() => _DeviceShowcaseState();
}

class _DeviceShowcaseState extends State<DeviceShowcase> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.94);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<DeviceProvider, UserProvider, WaterProvider>(
      builder: (context, deviceProvider, userProvider, waterProvider, child) {
        final devices = deviceProvider.deviceList;
        if (devices.isEmpty) {
          return const SizedBox.shrink();
        }

        final selectedIndex = _selectedIndex(deviceProvider);
        _syncPage(selectedIndex);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 268,
              child: PageView.builder(
                controller: _pageController,
                physics: const BouncingScrollPhysics(),
                itemCount: devices.length,
                onPageChanged: (index) {
                  _selectDeviceFromPage(
                    deviceProvider: deviceProvider,
                    waterProvider: waterProvider,
                    deviceId: devices[index]['deviceInfId'].toString(),
                  );
                },
                itemBuilder: (context, index) {
                  final device = devices[index];
                  final palette = _palettes[index % _palettes.length];
                  final deviceId = device['deviceInfId'].toString();
                  final isSelected = deviceProvider.selectedDeviceId == deviceId;
                  final isRunning =
                      isSelected && waterProvider.orderNum.isNotEmpty;
                  final stats = _statsForDevice(
                    deviceProvider,
                    waterProvider,
                    device,
                  );

                  return AnimatedPadding(
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOutCubic,
                    padding: EdgeInsets.only(
                      top: isSelected ? 0 : 18,
                      bottom: isSelected ? 0 : 10,
                      right: 8,
                    ),
                    child: _DeviceCard(
                      palette: palette,
                      device: device,
                      name: _deviceName(deviceProvider, device),
                      stats: stats,
                      isSelected: isSelected,
                      isRunning: isRunning,
                      onTap: () {
                        _selectDeviceFromPage(
                          deviceProvider: deviceProvider,
                          waterProvider: waterProvider,
                          deviceId: deviceId,
                        );
                      },
                      onRename: () {
                        DialogUtils.showEditRemarkDialog(
                          context,
                          deviceId,
                          _deviceName(deviceProvider, device),
                        );
                      },
                      onDelete: () {
                        final commonlyId =
                            device['commonlyId']?.toString() ?? '';
                        if (commonlyId.isEmpty) {
                          ToastService.show(
                            '\u65e0\u6cd5\u5220\u9664\u6b64\u8bbe\u5907',
                          );
                          return;
                        }
                        DialogUtils.showDeleteConfirmDialog(
                          context,
                          commonlyId,
                          _deviceName(deviceProvider, device),
                        );
                      },
                      onToggle: () {
                        _toggleDevice(
                          context,
                          deviceProvider,
                          userProvider,
                          waterProvider,
                          device,
                        );
                      },
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            _DeviceRail(
              deviceProvider: deviceProvider,
              waterProvider: waterProvider,
              pageController: _pageController,
            ),
          ],
        );
      },
    );
  }

  void _syncPage(int selectedIndex) {
    if (!_pageController.hasClients) {
      return;
    }

    final currentPage = _pageController.page?.round();
    if (currentPage == selectedIndex) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pageController.hasClients) {
        return;
      }
      _pageController.animateToPage(
        selectedIndex,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _toggleDevice(
    BuildContext context,
    DeviceProvider deviceProvider,
    UserProvider userProvider,
    WaterProvider waterProvider,
    Map<String, dynamic> device,
  ) async {
    final deviceId = device['deviceInfId'].toString();
    final isSelected = deviceProvider.selectedDeviceId == deviceId;
    final isWorking = waterProvider.orderNum.isNotEmpty;

    if (isWorking && !isSelected) {
      ToastService.show('\u5f53\u524d\u6b63\u5728\u4f7f\u7528\u5176\u4ed6\u8bbe\u5907');
      return;
    }

    if (!isSelected) {
      deviceProvider.selectDevice(deviceId);
    }

    if (isWorking) {
      await waterProvider.stopWater(
        userProvider.token,
        userProvider.userId,
        _currentDeviceName(deviceProvider),
        currentBalance: userProvider.balance,
        onBalanceUpdated: userProvider.setBalance,
      );
      return;
    }

    await _startWater(
      context,
      userProvider,
      waterProvider,
      device,
    );
  }

  Future<void> _startWater(
    BuildContext context,
    UserProvider userProvider,
    WaterProvider waterProvider,
    Map<String, dynamic> targetDevice, {
    bool force = false,
  }) async {
    final targetBillType = targetDevice['billType']?.toString() ?? '';
    if (!force &&
        targetBillType == '2' &&
        !_isWithinHotWaterWindow(DateTime.now())) {
      DialogUtils.showHotWaterTimeWarningDialog(
        context,
        onContinue: () {
          _startWater(
            context,
            userProvider,
            waterProvider,
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

}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({
    required this.palette,
    required this.device,
    required this.name,
    required this.stats,
    required this.isSelected,
    required this.isRunning,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
    required this.onToggle,
  });

  final _DevicePalette palette;
  final Map<String, dynamic> device;
  final String name;
  final _DeviceUsageStats stats;
  final bool isSelected;
  final bool isRunning;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            gradient: palette.gradient,
            border: Border.all(
              color: isSelected
                  ? Colors.white.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.08),
            ),
            boxShadow: [
              BoxShadow(
                color: palette.shadow,
                blurRadius: isSelected ? 24 : 16,
                offset: Offset(0, isSelected ? 14 : 10),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                top: -22,
                right: -18,
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.18),
                        Colors.white.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: -28,
                left: -4,
                child: Container(
                  width: 150,
                  height: 64,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(80),
                    color: Colors.white.withValues(alpha: 0.04),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _DeviceIconChip(
                          icon: _deviceIcon(device),
                          color: palette.icon,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isSelected ? 22 : 20,
                              fontWeight: FontWeight.w800,
                              height: 1.05,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        _WaterToggle(
                          value: isRunning,
                          accent: palette.accent,
                          onChanged: (_) => onToggle(),
                        ),
                        const SizedBox(width: 2),
                        PopupMenuButton<_CardAction>(
                          tooltip: '\u66f4\u591a',
                          color: const Color(0xFF191D2B),
                          icon: Icon(
                            Icons.more_horiz_rounded,
                            color: Colors.white.withValues(alpha: 0.9),
                            size: 20,
                          ),
                          onSelected: (value) {
                            switch (value) {
                              case _CardAction.rename:
                                onRename();
                                break;
                              case _CardAction.delete:
                                onDelete();
                                break;
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              value: _CardAction.rename,
                              child: Text(
                                '\u7f16\u8f91\u540d\u79f0',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                            PopupMenuItem(
                              value: _CardAction.delete,
                              child: Text(
                                '\u5220\u9664\u8bbe\u5907',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _ChipLabel(text: _deviceTypeLabel(device)),
                        const SizedBox(width: 8),
                        _ChipLabel(
                          text: isRunning
                              ? '\u4f7f\u7528\u4e2d'
                              : (isSelected ? '\u5df2\u9009\u4e2d' : '\u53ef\u5207\u6362'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _MetricCard(
                            label: '\u4f7f\u7528\u6b21\u6570',
                            value: '${stats.count}',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _MetricCard(
                            label: '\u6700\u8fd1\u4f7f\u7528',
                            value: stats.lastUsed,
                            small: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isRunning
                                      ? '\u8be5\u8bbe\u5907\u6b63\u5728\u51fa\u6c34'
                                      : '\u70b9\u51fb\u5f00\u5173\u5373\u53ef\u7528\u6c34',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  isRunning
                                      ? '\u5f53\u524d\u4f1a\u8bdd\u6b63\u5728\u8ba1\u65f6'
                                      : '\u652f\u6301\u76f4\u63a5\u5f00\u542f\u4e0e\u5173\u95ed',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.62),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeviceRail extends StatelessWidget {
  const _DeviceRail({
    required this.deviceProvider,
    required this.waterProvider,
    required this.pageController,
  });

  final DeviceProvider deviceProvider;
  final WaterProvider waterProvider;
  final PageController pageController;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: deviceProvider.deviceList.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final device = deviceProvider.deviceList[index];
          final deviceId = device['deviceInfId'].toString();
          final isSelected = deviceProvider.selectedDeviceId == deviceId;
          return GestureDetector(
            onTap: () {
              _selectDeviceFromPage(
                deviceProvider: deviceProvider,
                waterProvider: waterProvider,
                deviceId: deviceId,
              );
              if (pageController.hasClients) {
                pageController.animateToPage(
                  index,
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                );
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF4B72FF).withValues(alpha: 0.22)
                    : Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF7F9BFF).withValues(alpha: 0.28)
                      : Colors.white.withValues(alpha: 0.06),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _deviceIcon(device),
                    size: 16,
                    color: isSelected
                        ? Colors.white
                        : const Color(0xFF94A0C7),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _deviceName(deviceProvider, device),
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFF94A0C7),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    this.small = false,
  });

  final String label;
  final String value;
  final bool small;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(18),
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
            style: TextStyle(
              color: Colors.white,
              fontSize: small ? 13 : 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _DeviceIconChip extends StatelessWidget {
  const _DeviceIconChip({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(-2, -2),
          ),
        ],
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }
}

class _ChipLabel extends StatelessWidget {
  const _ChipLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _WaterToggle extends StatelessWidget {
  const _WaterToggle({
    required this.value,
    required this.accent,
    required this.onChanged,
  });

  final bool value;
  final Color accent;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        width: 58,
        height: 34,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: value
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [accent, Color.lerp(accent, Colors.white, 0.18)!],
                )
              : const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF3A3F52), Color(0xFF222635)],
                ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.26),
              blurRadius: 10,
              offset: const Offset(3, 6),
            ),
          ],
        ),
        child: Stack(
          children: [
            AnimatedAlign(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFF8FAFF), Color(0xFFD8DDEA)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: value ? accent : const Color(0xFF8088A2),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeviceUsageStats {
  const _DeviceUsageStats({required this.count, required this.lastUsed});

  final int count;
  final String lastUsed;
}

class _DevicePalette {
  const _DevicePalette({
    required this.gradient,
    required this.shadow,
    required this.accent,
    required this.icon,
  });

  final LinearGradient gradient;
  final Color shadow;
  final Color accent;
  final Color icon;
}

const List<_DevicePalette> _palettes = [
  _DevicePalette(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF343A43), Color(0xFF1E232A)],
    ),
    shadow: Color(0x55222A34),
    accent: Color(0xFF5CC8FF),
    icon: Color(0xFFCCF0FF),
  ),
  _DevicePalette(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF433730), Color(0xFF221C19)],
    ),
    shadow: Color(0x55453B34),
    accent: Color(0xFFFFA75C),
    icon: Color(0xFFFFD7B6),
  ),
  _DevicePalette(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF2F3344), Color(0xFF1A1C25)],
    ),
    shadow: Color(0x55303645),
    accent: Color(0xFF8F8BFF),
    icon: Color(0xFFD7D6FF),
  ),
];

enum _CardAction { rename, delete }

int _selectedIndex(DeviceProvider deviceProvider) {
  final selectedId = deviceProvider.selectedDeviceId;
  final index = deviceProvider.deviceList.indexWhere(
    (item) => item['deviceInfId'].toString() == selectedId,
  );
  return index < 0 ? 0 : index;
}

void _selectDeviceFromPage({
  required DeviceProvider deviceProvider,
  required WaterProvider waterProvider,
  required String deviceId,
}) {
  if (waterProvider.orderNum.isNotEmpty &&
      deviceProvider.selectedDeviceId != deviceId) {
    ToastService.show('\u7528\u6c34\u4e2d\uff0c\u65e0\u6cd5\u5207\u6362\u8bbe\u5907');
    return;
  }
  deviceProvider.selectDevice(deviceId);
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

_DeviceUsageStats _statsForDevice(
  DeviceProvider deviceProvider,
  WaterProvider waterProvider,
  Map<String, dynamic> device,
) {
  final name = _deviceName(deviceProvider, device);
  final type = _deviceTypeLabel(device);
  final keywords = <String>{
    name.toLowerCase(),
    '$name$type'.toLowerCase(),
    type.toLowerCase(),
  };

  WaterUsageHistoryEntry? latest;
  var count = 0;

  for (final entry in waterProvider.history) {
    final current = entry.displayDeviceName.toLowerCase();
    final matched = keywords.any(
      (keyword) => current.contains(keyword) || keyword.contains(current),
    );
    if (!matched) {
      continue;
    }
    count++;
    if (latest == null || entry.createdAt.isAfter(latest.createdAt)) {
      latest = entry;
    }
  }

  return _DeviceUsageStats(
    count: count,
    lastUsed: latest == null
        ? '\u4ece\u672a\u4f7f\u7528'
        : DateFormat('MM.dd HH:mm').format(latest.createdAt),
  );
}

String _currentDeviceName(DeviceProvider deviceProvider) {
  if (deviceProvider.deviceList.isEmpty) {
    return '';
  }
  Map<String, dynamic> target = deviceProvider.deviceList.first;
  for (final item in deviceProvider.deviceList) {
    if (item['deviceInfId'].toString() == deviceProvider.selectedDeviceId) {
      target = item;
      break;
    }
  }
  return '${_deviceName(deviceProvider, target)}${_deviceTypeLabel(target)}';
}

String _deviceName(
  DeviceProvider deviceProvider,
  Map<String, dynamic> device,
) {
  final id = device['deviceInfId'].toString();
  return deviceProvider.customRemarks[id] ??
      device['deviceInfName'].toString().replaceAll(RegExp(r'^[12]-'), '');
}

String _deviceTypeLabel(Map<String, dynamic> device) {
  return device['billType'] == 2 ? '\u70ed\u6c34' : '\u76f4\u996e';
}

IconData _deviceIcon(Map<String, dynamic> device) {
  return device['billType'] == 2
      ? Icons.shower_rounded
      : Icons.water_drop_rounded;
}
