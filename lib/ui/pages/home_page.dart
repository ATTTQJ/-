import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/toast_service.dart';
import '../../providers/device_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/water_provider.dart';
import '../widgets/dialog_utils.dart';
import '../widgets/history_bottom_sheet.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? _expandedId;
  String? _historySyncKey;

  static const Duration _switchMotionDuration = Duration(milliseconds: 320);

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    return Consumer3<UserProvider, WaterProvider, DeviceProvider>(
      builder: (context, userProvider, waterProvider, deviceProvider, child) {
        final List<Map<String, dynamic>> displayDevices = 
            List<Map<String, dynamic>>.from(deviceProvider.deviceList);
        while (displayDevices.length < 4) {
          displayDevices.add({
            'isAddCard': true,
            'deviceInfId': 'add_${displayDevices.length}',
            'deviceInfName': '添加设备',
            'billType': -1,
          });
        }

        final selectedId = deviceProvider.selectedDeviceId;
        final working = waterProvider.orderNum.isNotEmpty;
        final activeId = waterProvider.activeDeviceId;
        Map<String, dynamic>? activeDevice;
        final usageCounts = _buildUsageCounts(
          deviceProvider: deviceProvider,
          history: waterProvider.history,
        );
        final predictedDevice = _resolvePredictedDevice(
          deviceProvider: deviceProvider,
          usageCounts: usageCounts,
        );

        String currentActiveName = '设备';
        if (working && activeId.isNotEmpty) {
          for (final d in deviceProvider.deviceList) {
            if (d['deviceInfId']?.toString() == activeId) {
              activeDevice = d;
              currentActiveName = _deviceName(deviceProvider, d);
              break;
            }
          }
        }
        final dashboardDevice = working ? activeDevice : predictedDevice;

        _scheduleHistorySync(
          userProvider: userProvider,
          waterProvider: waterProvider,
          deviceProvider: deviceProvider,
        );

        return Scaffold(
          backgroundColor: const Color(0xFF0E0E11),
          body: Stack(
            children: [
              const Positioned.fill(child: _BackdropLayer()),
              
              SafeArea(
                bottom: false, 
                child: Stack(
                  children: [
                    Positioned(
                      top: 7, 
                      left: 0,
                      right: 0,
                      child: _TopButtons(
                        onProfile: () => _showLogoutConfirm(context),
                        onHistory: () {
                          DialogUtils.showGlassBottomSheet(
                            context,
                            const HistoryBottomSheet(),
                          );
                          unawaited(
                            context.read<WaterProvider>().syncHistoryMonth(
                                  token: userProvider.token,
                                  userId: userProvider.userId,
                                  year: waterProvider.selectedHistoryYear,
                                  month: waterProvider.selectedHistoryMonth,
                                  muteToast: true,
                                ),
                          );
                        },
                      ),
                    ),
                    
                    const Positioned(
                      top: 78, 
                      left: 30,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "John's Home", 
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Monitor and control your devices',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 🌟 核心修复 1：把列表容器横向铺满(left/right 为0)，防止卡片左右边缘阴影被异常截断
                    // 同时物理边界死死卡在 top: 314（深色面板底边缘）
                    Positioned(
                      top: 314, 
                      left: 0,
                      right: 0,
                      bottom: 0, 
                      child: _DeviceDeck(
                        devices: displayDevices,
                        selectedId: selectedId,
                        activeId: activeId,
                        expandedId: _expandedId,
                        working: working,
                        loading: waterProvider.isRequesting,
                        usageCounts: usageCounts,
                        nameOf: (device) => _deviceName(deviceProvider, device),
                        onTapCard: (device) {
                          if (device['isAddCard'] == true) {
                            DialogUtils.showCascadingAddDeviceDialog(context);
                            return;
                          }
                          final id = device['deviceInfId'].toString();
                          deviceProvider.selectDevice(id);
                          setState(() {
                            _expandedId = _expandedId == id ? null : id;
                          });
                        },
                        onTogglePower: (device) =>
                            _handleDevicePowerTap(
                          context,
                          device,
                          userProvider,
                          waterProvider,
                          deviceProvider,
                        ),
                        onMove: (device) => _showMoveDeviceDialog(
                          context,
                          device,
                          deviceProvider,
                        ),
                        onRename: (device) => DialogUtils.showEditRemarkDialog(
                          context,
                          device['deviceInfId'].toString(),
                          _deviceName(deviceProvider, device),
                        ),
                        onDelete: (device) {
                          final commonlyId =
                              (device['commonlyId'] ?? '').toString();
                          if (commonlyId.isEmpty) {
                            ToastService.show(
                              '无法删除该设备',
                            );
                            return;
                          }
                          DialogUtils.showDeleteConfirmDialog(
                            context,
                            commonlyId,
                            _deviceName(deviceProvider, device),
                          );
                        },
                      ),
                    ),

                    Positioned(
                      top: 172, 
                      left: 20,
                      right: 20,
                      child: _DashboardCard(
                        balance: userProvider.balance,
                        working: working,
                        runningTime: waterProvider.runningTime,
                        activeDevicesCount: working ? 1 : 0,
                        totalDevicesCount: deviceProvider.deviceList.length,
                        activeDeviceName: currentActiveName, 
                        onStatusTap: working
                            ? null
                            : () => DialogUtils.showCascadingAddDeviceDialog(
                                  context,
                                ),
                        lastUsedDeviceName: predictedDevice == null
                            ? '暂无可用设备'
                            : _deviceName(deviceProvider, predictedDevice),
                        onActionTap: dashboardDevice == null ||
                                waterProvider.isRequesting
                            ? null
                            : () => _handleDevicePowerTap(
                                  context,
                                  dashboardDevice,
                                  userProvider,
                                  waterProvider,
                                  deviceProvider,
                                ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _scheduleHistorySync({
    required UserProvider userProvider,
    required WaterProvider waterProvider,
    required DeviceProvider deviceProvider,
  }) {
    if (userProvider.token.trim().isEmpty ||
        userProvider.userId.trim().isEmpty ||
        deviceProvider.deviceList.isEmpty) {
      return;
    }

    final syncKey =
        '${userProvider.userId}:${deviceProvider.deviceList.length}:${deviceProvider.deviceList.map((e) => e['deviceInfId']).join(',')}';
    if (_historySyncKey == syncKey) {
      return;
    }
    _historySyncKey = syncKey;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(() async {
        await waterProvider.syncHistoryFromServer(
          token: userProvider.token,
          userId: userProvider.userId,
          muteToast: true,
        );
        await waterProvider.backfillHistoryIfNeeded(
          token: userProvider.token,
          userId: userProvider.userId,
        );
      }());
    });
  }

  String _deviceName(
    DeviceProvider provider,
    Map<String, dynamic> device,
  ) {
    if (device['isAddCard'] == true) return '添加设备';
    
    final id = device['deviceInfId'].toString();
    final remark = provider.customRemarks[id];
    if (remark != null && remark.trim().isNotEmpty) {
      return remark.trim();
    }
    return device['deviceInfName'].toString().replaceFirst(RegExp(r'^[12]-'), '');
  }

  String _historyDeviceName(Map<String, dynamic> device, DeviceProvider provider) {
    final suffix = device['billType'] == 2 ? '\u70ed\u6c34' : '\u76f4\u996e';
    return '${_deviceName(provider, device)}$suffix';
  }

  Set<String> _historyAliases(
    DeviceProvider provider,
    Map<String, dynamic> device,
  ) {
    final suffix = device['billType'] == 2 ? '\u70ed\u6c34' : '\u76f4\u996e';
    final rawName = device['deviceInfName']?.toString() ?? '';
    final strippedRaw = rawName.replaceFirst(RegExp(r'^[12]-'), '');
    final aliases = <String>{
      _normalizeUsageHistoryDeviceName('${_deviceName(provider, device)}$suffix'),
      _normalizeUsageHistoryDeviceName('$strippedRaw$suffix'),
      _normalizeUsageHistoryDeviceName('$rawName$suffix'),
    }..removeWhere((value) => value.isEmpty);
    return aliases;
  }

  Map<String, int> _buildUsageCounts({
    required DeviceProvider deviceProvider,
    required List<dynamic> history,
  }) {
    final counts = <String, int>{};
    for (final device in deviceProvider.deviceList) {
      counts[device['deviceInfId'].toString()] = 0;
    }

    for (final entry in history) {
      final directDeviceId = entry.deviceId?.trim() ?? '';
      if (directDeviceId.isNotEmpty && counts.containsKey(directDeviceId)) {
        counts[directDeviceId] = (counts[directDeviceId] ?? 0) + 1;
        continue;
      }

      final matchedId = _resolveUsageHistoryDeviceId(
        deviceProvider: deviceProvider,
        entryName: entry.deviceName.toString(),
      );
      if (matchedId == null) {
        continue;
      }
      counts[matchedId] = (counts[matchedId] ?? 0) + 1;
    }
    return counts;
  }

  Map<String, dynamic>? _resolveLastUsedDevice({
    required DeviceProvider deviceProvider,
    required List<dynamic> history,
  }) {
    if (history.isEmpty || deviceProvider.deviceList.isEmpty) {
      return null;
    }

    final matchedId = _resolveUsageHistoryDeviceId(
      deviceProvider: deviceProvider,
      entryName: history.first.deviceName.toString(),
    );
    for (final device in deviceProvider.deviceList) {
      if (device['deviceInfId']?.toString() == matchedId) {
        return device;
      }
    }

    return deviceProvider.deviceList.first;
  }

  Map<String, dynamic>? _resolvePredictedDevice({
    required DeviceProvider deviceProvider,
    required Map<String, int> usageCounts,
  }) {
    final realDevices = deviceProvider.deviceList
        .where((device) => device['isAddCard'] != true)
        .toList(growable: false);
    if (realDevices.isEmpty) {
      return null;
    }

    final preferHotWater = _isDormHotWaterAvailable(DateTime.now());

    final preferredDevices = realDevices
        .where(
          (device) => preferHotWater
              ? (int.tryParse((device['billType'] ?? '').toString()) ?? 1) == 2
              : (int.tryParse((device['billType'] ?? '').toString()) ?? 1) != 2,
        )
        .toList(growable: false);

    final pool = preferredDevices.isNotEmpty ? preferredDevices : realDevices;
    pool.sort((a, b) {
      final aId = a['deviceInfId'].toString();
      final bId = b['deviceInfId'].toString();
      final countCompare =
          (usageCounts[bId] ?? 0).compareTo(usageCounts[aId] ?? 0);
      if (countCompare != 0) {
        return countCompare;
      }
      return realDevices.indexOf(a).compareTo(realDevices.indexOf(b));
    });

    return pool.first;
  }

  bool _isDormHotWaterAvailable(DateTime now) {
    final minuteOfDay = now.hour * 60 + now.minute;
    return _isWithinRange(minuteOfDay, 6 * 60, 9 * 60 + 30) ||
        _isWithinRange(minuteOfDay, 11 * 60 + 30, 14 * 60 + 30) ||
        _isWithinRange(minuteOfDay, 18 * 60, 23 * 60 + 50);
  }

  bool _isWithinRange(int minuteOfDay, int startMinute, int endMinute) {
    return minuteOfDay >= startMinute && minuteOfDay <= endMinute;
  }

  String? _resolveUsageHistoryDeviceId({
    required DeviceProvider deviceProvider,
    required String entryName,
  }) {
    final normalizedEntry = _normalizeUsageHistoryDeviceName(entryName);
    if (normalizedEntry.isEmpty) {
      return null;
    }

    for (final device in deviceProvider.deviceList) {
      final deviceId = device['deviceInfId'].toString();
      if (_historyAliases(deviceProvider, device).contains(normalizedEntry)) {
        return deviceId;
      }
    }

    return null;
  }

  String _normalizeUsageHistoryDeviceName(String name) {
    return name
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll('\u70ed\u6c34', 'hot')
        .replaceAll('\u76f4\u996e\u6c34', 'cold')
        .replaceAll('\u76f4\u996e', 'cold')
        .replaceAll('\u8bbe\u5907\u7528\u6c34', 'hot')
        .replaceAll('\u6d17\u6d74', 'hot')
        .replaceAll('drink', 'cold')
        .replaceAll('adddevice', '');
  }

  String _normalizeHistoryDeviceName(String name) {
    return _normalizeUsageHistoryDeviceName(name);
  }

  Future<void> _handleDevicePowerTap(
    BuildContext context,
    Map<String, dynamic> device,
    UserProvider userProvider,
    WaterProvider waterProvider,
    DeviceProvider deviceProvider,
  ) async {
    if (device['isAddCard'] == true || waterProvider.isRequesting) {
      return;
    }

    final deviceId = device['deviceInfId'].toString();

    if (waterProvider.orderNum.isNotEmpty) {
      Map<String, dynamic>? activeDevice;
      if (waterProvider.activeDeviceId.isNotEmpty) {
        for (final item in deviceProvider.deviceList) {
          if (item['deviceInfId']?.toString() == waterProvider.activeDeviceId) {
            activeDevice = item;
            break;
          }
        }
      }
      final stopTarget = activeDevice ?? device;
      if (waterProvider.activeDeviceId.isNotEmpty &&
          stopTarget['deviceInfId']?.toString() != deviceId) {
        ToastService.show(
          '请先关闭当前正在用水的设备',
        );
        return;
      }
      await waterProvider.stopWater(
        userProvider.token,
        userProvider.userId,
        _historyDeviceName(stopTarget, deviceProvider),
        currentBalance: userProvider.balance,
        onBalanceUpdated: userProvider.setBalance,
      );
      return;
    }

    deviceProvider.selectDevice(deviceId);
    await waterProvider.startWater(
      userProvider.token,
      userProvider.userId,
      device,
      currentBalance: userProvider.balance,
    );
  }

  void _showMoveDeviceDialog(
    BuildContext context,
    Map<String, dynamic> device,
    DeviceProvider deviceProvider,
  ) {
    final controller = TextEditingController();
    final maxPosition = deviceProvider.deviceList.length;

    DialogUtils.showGlassBottomSheet(
      context,
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '移动设备',
            style: TextStyle(
              color: Color(0xFF2C2C2E),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '请输入 1 到 $maxPosition 之间的位置。',
            style: const TextStyle(
              color: Color(0xFF666666),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: '位置',
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
              ),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2C2C2E),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () async {
                    final parsed = int.tryParse(controller.text.trim());
                    if (parsed == null || parsed < 1 || parsed > maxPosition) {
                      ToastService.show('位置无效');
                      return;
                    }
                    await deviceProvider.moveDeviceToPosition(
                      device['deviceInfId'].toString(),
                      parsed - 1,
                    );
                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                  },
                  child: const Text(
                    '保存',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showLogoutConfirm(BuildContext context) {
    DialogUtils.showGlassBottomSheet(
      context,
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '退出登录',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2C2C2E),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '确定要退出当前账号吗？',
            style: TextStyle(color: Color(0xFF666666), fontSize: 15),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
              ),
              Expanded(
                child: TextButton(
                  onPressed: () {
                    context.read<UserProvider>().logout();
                    Navigator.pop(context);
                  },
                  child: const Text(
                    '退出登录',
                    style: TextStyle(color: Colors.redAccent),
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

class _DashboardCard extends StatelessWidget {
  const _DashboardCard({
    required this.balance,
    required this.working,
    required this.runningTime,
    required this.activeDevicesCount,
    required this.totalDevicesCount,
    required this.onStatusTap,
    required this.lastUsedDeviceName,
    required this.activeDeviceName,
    required this.onActionTap,
  });

  final String balance;
  final bool working;
  final String runningTime;
  final int activeDevicesCount;
  final int totalDevicesCount;
  final VoidCallback? onStatusTap;
  final String lastUsedDeviceName;
  final String activeDeviceName;
  final VoidCallback? onActionTap;

  @override
  Widget build(BuildContext context) {
    final isDimmed = onActionTap == null && !working;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1F2A),
        borderRadius: BorderRadius.circular(32),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.account_balance_wallet_rounded,
                    color: Color(0xFF32D7D2),
                    size: 28,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '¥$balance',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: onStatusTap,
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  width: 116,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 800),
                    switchInCurve:
                        const Interval(0.5, 1.0, curve: Curves.easeInOutCubic),
                    switchOutCurve:
                        const Interval(0.5, 1.0, curve: Curves.easeInOutCubic),
                    transitionBuilder: (child, animation) =>
                        FadeTransition(opacity: animation, child: child),
                    child: Row(
                      key: ValueKey<bool>(working),
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(
                          working
                              ? Icons.waves_rounded
                              : Icons.important_devices_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                        const SizedBox(width: 10),
                        working
                            ? _RollingTimeText(timeStr: runningTime)
                            : Text(
                                '$activeDevicesCount/$totalDevicesCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  height: 1.1,
                                ),
                              ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: onActionTap,
            behavior: HitTestBehavior.opaque,
            child: Transform.translate(
              offset: const Offset(0, 6),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 48,
                decoration: BoxDecoration(
                  color: working
                      ? const Color(0xFFFF453A)
                      : isDimmed
                          ? const Color(0xFF7A58FF).withOpacity(0.45)
                          : const Color(0xFF7A58FF),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      working
                          ? Icons.waves_rounded
                          : Icons.auto_awesome_rounded,
                      color: isDimmed ? Colors.white54 : Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        working
                            ? '$activeDeviceName 使用中'
                            : lastUsedDeviceName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isDimmed ? Colors.white54 : Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RollingTimeText extends StatelessWidget {
  final String timeStr;
  const _RollingTimeText({required this.timeStr});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: timeStr.split('').asMap().entries.map((entry) {
        final int index = entry.key;
        final String char = entry.value;
        if (char == ':') {
          return const Text(
            ':',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              height: 1.1,
            ),
          );
        }
        return _RollingDigit(char: char, index: index);
      }).toList(),
    );
  }
}

class _RollingDigit extends StatelessWidget {
  final String char;
  final int index;
  const _RollingDigit({required this.char, required this.index});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (Widget child, Animation<double> animation) {
        final isEntering = (child.key as ValueKey<String>).value == '${index}_$char';
        final offsetTween = isEntering
            ? Tween<Offset>(begin: const Offset(0.0, 0.5), end: Offset.zero)
            : Tween<Offset>(begin: const Offset(0.0, -0.5), end: Offset.zero);

        return SlideTransition(
          position: offsetTween.animate(animation),
          child: FadeTransition(opacity: animation, child: child),
        );
      },
      layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
        return Stack(
          alignment: Alignment.center,
          children: <Widget>[
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
        );
      },
      child: Text(
        char,
        key: ValueKey<String>('${index}_$char'),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.bold,
          height: 1.1,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _BackdropLayer extends StatelessWidget {
  const _BackdropLayer();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(color: const Color(0xFF111217)), 
        Positioned(
          left: 14,
          right: 14,
          top: -80,
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
            child: Container(
              height: 306,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x6091EA94),
                    Color(0x5070AF56),
                    Color(0x30B46B6C),
                  ],
                  stops: [0.02, 0.58, 0.87],
                ),
                borderRadius: BorderRadius.all(Radius.elliptical(180, 130)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TopButtons extends StatelessWidget {
  const _TopButtons({
    required this.onProfile,
    required this.onHistory,
  });

  final VoidCallback onProfile;
  final VoidCallback onHistory;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24), 
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _GlassCircleButton(icon: Icons.person_outline_rounded, onTap: onProfile),
          _GlassCircleButton(icon: Icons.history_rounded, onTap: onHistory), 
        ],
      ),
    );
  }
}

class _GlassCircleButton extends StatelessWidget {
  const _GlassCircleButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
          child: Container(
            width: 46, 
            height: 46,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0x22FFFFFF),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }
}

class _DeviceDeck extends StatelessWidget {
  const _DeviceDeck({
    required this.devices,
    required this.selectedId,
    required this.activeId,
    required this.expandedId,
    required this.working,
    required this.loading,
    required this.usageCounts,
    required this.nameOf,
    required this.onTapCard,
    required this.onTogglePower,
    required this.onMove,
    required this.onRename,
    required this.onDelete,
  });

  final List<Map<String, dynamic>> devices;
  final String selectedId;
  final String activeId;
  final String? expandedId;
  final bool working;
  final bool loading;
  final Map<String, int> usageCounts;
  final String Function(Map<String, dynamic>) nameOf;
  final ValueChanged<Map<String, dynamic>> onTapCard;
  final ValueChanged<Map<String, dynamic>> onTogglePower;
  final ValueChanged<Map<String, dynamic>> onMove;
  final ValueChanged<Map<String, dynamic>> onRename;
  final ValueChanged<Map<String, dynamic>> onDelete;

  @override
  Widget build(BuildContext context) {
    if (devices.isEmpty) return const SizedBox.shrink();

    int? expandedIndex;
    if (expandedId != null) {
      expandedIndex = devices.indexWhere((d) => d['deviceInfId'].toString() == expandedId);
      if (expandedIndex == -1) expandedIndex = null;
    }

    final ordered = List.generate(devices.length, (i) => MapEntry(i, devices[i]));
    
    ordered.sort((a, b) {
      final ae = expandedId == a.value['deviceInfId'].toString();
      final be = expandedId == b.value['deviceInfId'].toString();
      if (ae == be) {
        return a.key.compareTo(b.key); 
      }
      return ae ? 1 : -1; 
    });

    double maxStackHeight = 0;
    
    final stackChildren = ordered.map((entry) {
      final index = entry.key;
      final device = entry.value;
      final isAddCard = device['isAddCard'] == true;
      final id = device['deviceInfId'].toString();
      
      final expanded = isAddCard ? false : expandedId == id;
      final selected = selectedId == id;
      final active = activeId == id;
      
      double top = 0.0;
      if (expandedIndex == null) {
        top = index * 100.0; 
      } else {
        if (index < expandedIndex) {
          top = index * 55.0; 
        } else if (index == expandedIndex) {
          top = index * 55.0; 
        } else {
          top = expandedIndex * 55.0 + 250.0 + (index - expandedIndex - 1) * 60.0; 
        }
      }

      final double cardHeight = expanded ? 240.0 : 180.0;
      if (top + cardHeight > maxStackHeight) {
        maxStackHeight = top + cardHeight;
      }

      // 🌟 核心修复：还原正确的卡片左右边距。
      // 因为 _DeviceDeck 在外层已经铺满屏幕 (left: 0, right: 0)，
      // 为了让卡片尺寸跟原来一样，同时让阴影有向外延展的空间，这里的 left 和 right 要设为 23！
      return AnimatedPositioned(
        key: ValueKey(id),
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic, 
        top: top,
        left: 23, // 🌟 修改为 23
        right: 23, // 🌟 修改为 23
        child: AnimatedScale(
          duration: const Duration(milliseconds: 380),
          scale: expanded ? 1.02 : 1, 
          child: isAddCard 
            ? _AddDeviceCard(onTap: () => onTapCard(device))
            : _DeckCard(
                palette: _paletteFor(index, device['billType'] == 2),
                title: nameOf(device),
                count: usageCounts[id] ?? 0,
                selected: selected,
                active: active,
                loading: loading && (working ? active : selected),
                expanded: expanded,
                onTap: () => onTapCard(device),
                onTogglePower: () => onTogglePower(device),
                onMove: () => onMove(device),
                onRename: () => onRename(device),
                onDelete: () => onDelete(device),
              ),
        ),
      );
    }).toList();

    return SingleChildScrollView(
      // 🌟 修复 2：全面拥回苹果原生的 BouncingScrollPhysics 弹性！
      physics: const BouncingScrollPhysics(), 
      // 🌟 修复 3：移除巨大 paddingTop hack，给个 26 让它顶部预留刚好钻出的缝隙
      padding: const EdgeInsets.only(top: 26.0, bottom: 60.0), 
      // 🌟 修复 4：启用硬裁剪 (Clip.hardEdge)！死死拦截住卡片，绝对不准溢出遮挡深色面板！
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        height: maxStackHeight,
        child: Stack(
          // 内部 Stack 不裁切左右的阴影
          clipBehavior: Clip.none,
          children: stackChildren,
        ),
      ),
    );
  }
}

class _AddDeviceCard extends StatelessWidget {
  final VoidCallback onTap;
  const _AddDeviceCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(40),
          border: Border.all(color: Colors.white.withOpacity(0.08), width: 2),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(40),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_circle_outline_rounded, color: Colors.white38, size: 42),
                  SizedBox(height: 12),
                  Text(
                    '点击添加新设备',
                    style: TextStyle(
                      color: Colors.white38, 
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DeckCard extends StatelessWidget {
  const _DeckCard({
    required this.palette,
    required this.title,
    required this.count,
    required this.selected,
    required this.active,
    required this.loading,
    required this.expanded,
    required this.onTap,
    required this.onTogglePower,
    required this.onMove,
    required this.onRename,
    required this.onDelete,
  });

  final _CardPalette palette;
  final String title;
  final int count;
  final bool selected;
  final bool active;
  final bool loading;
  final bool expanded;
  final VoidCallback onTap;
  final VoidCallback onTogglePower;
  final VoidCallback onMove;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer( 
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
        height: expanded ? 240 : 180, 
        decoration: BoxDecoration(
          gradient: palette.gradient,
          borderRadius: BorderRadius.circular(40), 
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 30,
              offset: const Offset(0, -5),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 20,
              offset: const Offset(0, 15),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              top: 12,
              left: 12,
              child: CustomPaint(
                size: const Size(45, 45),
                painter: _CornerLinePainter(),
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 20, 22, 22), 
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 12), 
                        child: Icon(
                          palette.icon,
                          color: palette.foreground,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 8), 
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 15),
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: palette.foreground,
                              fontSize: 18, 
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                              height: 1.1,
                            ),
                          ),
                        ),
                      ),
                      _VerticalSlideSwitch(
                        active: active,
                        loading: loading,
                        foreground: palette.foreground,
                        rail: palette.switchRail,
                        onTap: onTogglePower,
                      ),
                    ],
                  ),
                  if (expanded) ...[
                    const SizedBox(height: 8),
                    Text(
                      '已使用', 
                      style: TextStyle(
                        color: palette.secondaryText,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: '$count',
                            style: TextStyle(
                              color: palette.foreground,
                              fontSize: 44,
                              fontWeight: FontWeight.w900,
                              height: 1,
                            ),
                          ),
                          TextSpan(
                            text: ' 次', 
                            style: TextStyle(
                              color: palette.secondaryText,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(), 
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _CardActionButton(
                          icon: Icons.swap_vert_rounded, 
                          label: '位置',
                          color: palette.foreground,
                          bgColor: Colors.black.withOpacity(0.06),
                          onTap: onMove,
                        ),
                        const SizedBox(width: 8), 
                        _CardActionButton(
                          icon: Icons.edit_rounded,
                          label: '重命名',
                          color: palette.foreground,
                          bgColor: Colors.black.withOpacity(0.06),
                          onTap: onRename,
                        ),
                        const SizedBox(width: 8),
                        _CardActionButton(
                          icon: Icons.delete_outline_rounded, 
                          label: '删除',
                          color: const Color(0xFFE53935), 
                          bgColor: const Color(0xFFE53935).withOpacity(0.12), 
                          onTap: onDelete,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color bgColor;
  final VoidCallback onTap;

  const _CardActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.bgColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(18), 
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label, 
              style: TextStyle(
                fontSize: 13, 
                fontWeight: FontWeight.w600, 
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 🌟 修复编译错误：绝对不能用 const double radius = radius!
class _CornerLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.85) 
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round; 

    final path = Path();
    const double radius = 28.0; // 🌟 精确设为 28.0
    
    path.moveTo(0, 42);
    path.lineTo(0, radius);
    path.arcToPoint(
      const Offset(radius, 0),
      radius: const Radius.circular(radius),
      clockwise: true,
    );
    path.lineTo(42, 0);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CardPalette {
  const _CardPalette({
    required this.gradient,
    required this.badgeColor,
    required this.foreground,
    required this.secondaryText,
    required this.switchRail,
    required this.icon,
  });

  final Gradient gradient;
  final Color badgeColor;
  final Color foreground;
  final Color secondaryText;
  final Color switchRail;
  final IconData icon;
}

_CardPalette _paletteFor(int index, bool hotWater) {
  const textColor = Color(0xFF333333);
  const secondaryTextColor = Color(0x99333333);

  final palettes = [
    const _CardPalette(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFE2F57A), Color(0xFFC4D857)], 
      ),
      badgeColor: Color(0x19000000),
      foreground: textColor, 
      secondaryText: secondaryTextColor,
      switchRail: Color(0x1A000000),
      icon: Icons.water_drop_rounded, 
    ),
    const _CardPalette(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFA7739), Color(0xFFE35A1E)], 
      ),
      badgeColor: Color(0x22FFFFFF),
      foreground: textColor, 
      secondaryText: secondaryTextColor,
      switchRail: Color(0x1A000000),
      icon: Icons.water_drop_rounded,
    ),
    const _CardPalette(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFBA87D), Color(0xFFE58F63)], 
      ),
      badgeColor: Color(0x22FFFFFF),
      foreground: textColor,
      secondaryText: secondaryTextColor,
      switchRail: Color(0x1A000000),
      icon: Icons.water_drop_rounded,
    ),
    const _CardPalette(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFA17DFB), Color(0xFF8661E1)], 
      ),
      badgeColor: Color(0x22FFFFFF),
      foreground: textColor, 
      secondaryText: secondaryTextColor,
      switchRail: Color(0x22000000),
      icon: Icons.water_drop_rounded,
    ),
  ];
  final base = palettes[index % palettes.length];
  
  return _CardPalette(
    gradient: base.gradient,
    badgeColor: base.badgeColor,
    foreground: base.foreground,
    secondaryText: base.secondaryText,
    switchRail: base.switchRail,
    icon: hotWater ? Icons.local_fire_department_rounded : Icons.water_drop_rounded,
  );
}

class _VerticalSlideSwitch extends StatelessWidget {
  const _VerticalSlideSwitch({
    required this.active,
    required this.loading,
    required this.foreground,
    required this.rail,
    required this.onTap,
  });

  final bool active;
  final bool loading;
  final Color foreground;
  final Color rail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: _HomePageState._switchMotionDuration,
        width: 36, 
        height: 64, 
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: active ? const Color(0x664CAF50) : rail,
          borderRadius: BorderRadius.circular(24),
        ),
        child: AnimatedAlign(
          duration: _HomePageState._switchMotionDuration,
          curve: Curves.easeInOutCubic,
          alignment: active ? Alignment.bottomCenter : Alignment.topCenter,
          child: Container(
            width: 28, 
            height: 28,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.92),
              shape: BoxShape.circle,
              boxShadow: const [
                BoxShadow(
                  color: Color(0x40000000),
                  blurRadius: 10,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: loading
                  ? const Padding(
                      key: ValueKey('loading'),
                      padding: EdgeInsets.all(6),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Icon(
                      Icons.power_settings_new_rounded,
                      key: ValueKey<bool>(active),
                      color: active ? const Color(0xFF4CAF50) : Colors.white, 
                      size: 16, 
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
