import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

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

  @override
  Widget build(BuildContext context) {
    // 状态栏全透明，亮色图标
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    return Consumer3<UserProvider, WaterProvider, DeviceProvider>(
      builder: (context, userProvider, waterProvider, deviceProvider, child) {
        // 保证 4 张卡片，如果少于4张则补齐虚位卡片
        final List<Map<String, dynamic>> displayDevices = 
            List<Map<String, dynamic>>.from(deviceProvider.deviceList);
        while (displayDevices.length < 4) {
          displayDevices.add({
            'isAddCard': true,
            'deviceInfId': 'add_${displayDevices.length}',
            'deviceInfName': 'Add Device',
            'billType': -1,
          });
        }

        final selectedId = deviceProvider.selectedDeviceId;
        final working = waterProvider.orderNum.isNotEmpty;

        return Scaffold(
          backgroundColor: const Color(0xFF0E0E11),
          // 🌟 彻底抛弃外层滚动，真正的一页满铺
          body: Stack(
            children: [
              const Positioned.fill(child: _BackdropLayer()),
              
              SafeArea(
                bottom: false, 
                child: Stack(
                  children: [
                    Positioned(
                      top: 12, 
                      left: 0,
                      right: 0,
                      child: _TopButtons(
                        onProfile: () => _showLogoutConfirm(context),
                        onHistory: () {
                          unawaited(
                            context.read<WaterProvider>().syncHistoryFromServer(
                                  token: userProvider.token,
                                  userId: userProvider.userId,
                                ),
                          );
                          DialogUtils.showGlassBottomSheet(
                            context,
                            const HistoryBottomSheet(),
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
                            "Monitor and control your devices",
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
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
                        onActionTap: () {
                          DialogUtils.showCascadingAddDeviceDialog(context);
                        },
                      ),
                    ),

                    // 🌟 核心：设备甲板区域。固定上边界，下边界贴底，内部可独立滑动
                    Positioned(
                      top: 340, 
                      left: 19,
                      right: 19,
                      bottom: 0, 
                      child: _DeviceDeck(
                        devices: displayDevices,
                        selectedId: selectedId,
                        expandedId: _expandedId,
                        historyCount: waterProvider.history.length,
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

  String _deviceName(
    DeviceProvider provider,
    Map<String, dynamic> device,
  ) {
    if (device['isAddCard'] == true) return 'Add Device';
    
    final id = device['deviceInfId'].toString();
    final remark = provider.customRemarks[id];
    if (remark != null && remark.trim().isNotEmpty) {
      return remark.trim();
    }
    return device['deviceInfName'].toString().replaceFirst(RegExp(r'^[12]-'), '');
  }

  void _showLogoutConfirm(BuildContext context) {
    DialogUtils.showGlassBottomSheet(
      context,
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Log out',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2C2C2E),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Do you want to log out of this account?',
            style: TextStyle(color: Color(0xFF666666), fontSize: 15),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              Expanded(
                child: TextButton(
                  onPressed: () {
                    context.read<UserProvider>().logout();
                    Navigator.pop(context);
                  },
                  child: const Text(
                    'Log out',
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
    required this.onActionTap,
  });

  final String balance;
  final bool working;
  final String runningTime;
  final int activeDevicesCount;
  final int totalDevicesCount;
  final VoidCallback onActionTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                children: [
                  const Icon(
                    Icons.thermostat_rounded, 
                    color: Color(0xFF32D7D2), 
                    size: 28,
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '¥$balance',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22, 
                          fontWeight: FontWeight.bold,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Wallet Balance',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Row(
                children: [
                  Icon(
                    working ? Icons.waves_rounded : Icons.important_devices_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        working ? runningTime : '$activeDevicesCount/$totalDevicesCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        working ? 'Running' : 'Active Device',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: onActionTap,
            child: Container(
              height: 48, 
              decoration: BoxDecoration(
                color: const Color(0xFF7A58FF), 
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.add_circle_outline_rounded, 
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Add New Device',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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
          _GlassCircleButton(icon: Icons.notifications_none_rounded, onTap: onHistory), 
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
    required this.expandedId,
    required this.historyCount,
    required this.nameOf,
    required this.onTapCard,
  });

  final List<Map<String, dynamic>> devices;
  final String selectedId;
  final String? expandedId;
  final int historyCount;
  final String Function(Map<String, dynamic>) nameOf;
  final ValueChanged<Map<String, dynamic>> onTapCard;

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

    // 🌟 精确计算内部 Stack 的总高度，支持 5+ 台设备自动触发滚动
    double maxStackHeight = 0;
    
    final stackChildren = ordered.map((entry) {
      final index = entry.key;
      final device = entry.value;
      final isAddCard = device['isAddCard'] == true;
      final id = device['deviceInfId'].toString();
      
      final expanded = isAddCard ? false : expandedId == id;
      final selected = selectedId == id;
      
      double top = 0.0;
      if (expandedIndex == null) {
        top = index * 100.0; 
      } else {
        if (index < expandedIndex) {
          top = index * 55.0; 
        } else if (index == expandedIndex) {
          top = index * 55.0; 
        } else {
          // 展开高度降为 240，下一张卡片被推到 240 + 10 = 250 的位置
          top = expandedIndex * 55.0 + 250.0 + (index - expandedIndex - 1) * 60.0; 
        }
      }

      final double cardHeight = expanded ? 240.0 : 180.0;
      if (top + cardHeight > maxStackHeight) {
        maxStackHeight = top + cardHeight;
      }

      return AnimatedPositioned(
        key: ValueKey(id),
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic, 
        top: top,
        left: 4,
        right: 4,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 380),
          scale: expanded ? 1.02 : 1, 
          child: isAddCard 
            ? _AddDeviceCard(onTap: () => onTapCard(device))
            : _DeckCard(
                palette: _paletteFor(index, device['billType'] == 2),
                title: nameOf(device),
                count: math.max(1, historyCount ~/ (index + 1)),
                selected: selected,
                expanded: expanded,
                onTap: () => onTapCard(device),
              ),
        ),
      );
    }).toList();

    // 🌟 将卡片区域包裹在独立的滚动视图中，完美支持 5台+ 设备
    return SingleChildScrollView(
      physics: devices.length > 4 
          ? const BouncingScrollPhysics() // 设备超过 4 台，开启弹性滑动
          : const BouncingScrollPhysics(), // 少于 4 台时高度未溢出，本身就不需要滑（保持原生回弹手感）
      padding: const EdgeInsets.only(bottom: 60), // 底部多留点空间避免被 Home 条遮挡
      clipBehavior: Clip.none,
      child: SizedBox(
        height: maxStackHeight,
        child: Stack(
          clipBehavior: Clip.none,
          children: stackChildren,
        ),
      ),
    );
  }
}

// “添加设备”卡片
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
                    'Tap to add new device', 
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
    required this.expanded,
    required this.onTap,
  });

  final _CardPalette palette;
  final String title;
  final int count;
  final bool selected;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer( 
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
        // 🌟 优化：展开高度降低到了 240，刚好完美展示完下方的 Usage
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
                          // 🌟 优化：图标放大了 1 个 size (26 -> 28)
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
                              // 🌟 优化：字体放大了 1 个 size (16 -> 18)
                              fontSize: 18, 
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                              height: 1.1,
                            ),
                          ),
                        ),
                      ),
                      _VerticalSlideSwitch(
                        // 🌟 优化：开关彻底解绑，不会随着卡片展开而激活
                        active: false, 
                        foreground: palette.foreground,
                        rail: palette.switchRail,
                      ),
                    ],
                  ),
                  if (expanded) ...[
                    const SizedBox(height: 24),
                    Text(
                      'Today usage',
                      style: TextStyle(
                        color: palette.secondaryText,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: '$count',
                            style: TextStyle(
                              color: palette.foreground,
                              fontSize: 48,
                              fontWeight: FontWeight.w900,
                              height: 1,
                            ),
                          ),
                          TextSpan(
                            text: ' uses',
                            style: TextStyle(
                              color: palette.secondaryText,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
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

class _CornerLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      // 🌟 优化：极度提亮左上角的白线透明度，可读性更强
      ..color = Colors.white.withOpacity(0.85) 
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round; 

    final path = Path();
    const double radius = 28.0; 
    
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
    required this.foreground,
    required this.rail,
  });

  final bool active;
  final Color foreground;
  final Color rail;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36, 
      height: 64, 
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: rail,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Align(
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
          child: Icon(
            Icons.power_settings_new_rounded,
            color: active ? const Color(0xFF4CAF50) : Colors.white, 
            size: 16, 
          ),
        ),
      ),
    );
  }
}