import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/toast_service.dart';
import '../../providers/device_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/api_service.dart';
import '../pages/qr_scanner_page.dart';
import 'dialog_utils.dart';

class DeviceSelectorDialog extends StatefulWidget {
  const DeviceSelectorDialog({super.key});

  @override
  State<DeviceSelectorDialog> createState() => _DeviceSelectorDialogState();
}

class _DeviceSelectorDialogState extends State<DeviceSelectorDialog> {
  static const String _schoolId = '27720';

  int _step = 0;
  bool _isLoading = true;
  String _selectedWayId = '';
  List<Map<String, String>> _currentList = [];
  final List<List<Map<String, String>>> _historyLists = [];
  final List<String> _titles = ['选择用水类型'];
  final List<String> _stepNames = [
    '选择用水类型',
    '选择校区',
    '选择楼栋',
    '选择楼层',
    '选择寝室 / 设备',
  ];

  @override
  void initState() {
    super.initState();
    _fetchData(0, _schoolId);
  }

  String _extractId(Map source) {
    if (source.containsKey('deptId')) return source['deptId'].toString();
    if (source.containsKey('deviceWayId')) {
      return source['deviceWayId'].toString();
    }
    if (source.containsKey('deviceNum')) return source['deviceNum'].toString();
    if (source.containsKey('id')) return source['id'].toString();
    if (source.containsKey('value')) return source['value'].toString();
    if (source.containsKey('sn')) return source['sn'].toString();
    for (final key in source.keys) {
      if (key.toString().toLowerCase().contains('id')) {
        return source[key].toString();
      }
    }
    return '';
  }

  String _extractName(Map source) {
    if (source.containsKey('deptName')) return source['deptName'].toString();
    if (source.containsKey('wayName')) return source['wayName'].toString();
    if (source.containsKey('deviceWayName')) {
      return source['deviceWayName'].toString();
    }
    if (source.containsKey('name')) return source['name'].toString();
    if (source.containsKey('title')) return source['title'].toString();
    if (source.containsKey('label')) return source['label'].toString();
    for (final key in source.keys) {
      if (key.toString().toLowerCase().contains('name')) {
        return source[key].toString();
      }
    }
    return '未知选项';
  }

  Future<void> _fetchData(int step, String id) async {
    setState(() => _isLoading = true);

    final path = step == 0
        ? 'device/queryDeviceWay'
        : 'school/querySchoolAddress';
    final params = step == 0 ? {'schId': _schoolId} : {'deptId': id};
    final userProvider = context.read<UserProvider>();
    final res = await ApiService.post(
      path,
      params,
      token: userProvider.token,
      userId: userProvider.userId,
      muteToast: true,
    );

    final parsed = <Map<String, String>>[];
    if (res != null &&
        (res['code'] == 0 || res['code'] == '0' || res['code'] == 200) &&
        res['data'] != null) {
      final rawData = res['data'];
      final targetList = rawData is List
          ? rawData
          : rawData is Map
          ? rawData.values.firstWhere(
              (value) => value is List,
              orElse: () => [],
            )
          : <dynamic>[];

      for (final item in targetList) {
        if (item is Map) {
          final extId = _extractId(item);
          final extName = _extractName(item);
          if (extId.isNotEmpty) {
            parsed.add({'id': extId, 'name': extName});
          }
        }
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _currentList = parsed;
      _isLoading = false;
    });
  }

  Future<void> _onItemTap(Map<String, String> item) async {
    if (_step == 0) {
      _selectedWayId = item['id']!;
    }

    if (_step < 4) {
      _historyLists.add(List.from(_currentList));
      _step++;
      _titles.add(_stepNames[_step]);
      await _fetchData(_step, _step == 1 ? _schoolId : item['id']!);
      return;
    }

    setState(() => _isLoading = true);
    final userProvider = context.read<UserProvider>();
    final queryRes = await ApiService.post(
      'device/queryDeviceInfo',
      {
        'deviceNum': item['id']!,
        'schId': _schoolId,
        'deviceWayId': _selectedWayId,
        'type': '4',
      },
      token: userProvider.token,
      userId: userProvider.userId,
    );

    if (queryRes != null &&
        (queryRes['code'] == 0 ||
            queryRes['code'] == '0' ||
            queryRes['code'] == 200)) {
      final data = queryRes['data'];
      if (data is Map && data['deviceInfId'] != null) {
        final addRes = await ApiService.post(
          'device/operationDeviceCommonly',
          {
            'deviceTypeId': data['deviceTypeId']?.toString() ?? '',
            'deviceWayId': data['deviceWayId']?.toString() ?? _selectedWayId,
            'deviceInfId': data['deviceInfId'].toString(),
            'type': '1',
          },
          token: userProvider.token,
          userId: userProvider.userId,
        );

        if (addRes != null &&
            (addRes['code'] == 0 ||
                addRes['code'] == '0' ||
                addRes['code'] == 200)) {
          ToastService.show('设备添加成功');
          if (!mounted) {
            return;
          }
          context.read<DeviceProvider>().refreshDeviceListFromNet(
            userProvider.token,
            userProvider.userId,
          );
          Navigator.pop(context);
          return;
        }
      }
    }

    if (!mounted) {
      return;
    }
    setState(() => _isLoading = false);
  }

  void _onBack() {
    if (_step <= 0) {
      return;
    }

    setState(() {
      _step--;
      _titles.removeLast();
      _currentList = _historyLists.removeLast();
    });
  }

  Future<void> _openScanner() async {
    final navigator = Navigator.of(context);
    navigator.pop();
    final result = await navigator.push<String>(
      MaterialPageRoute(builder: (context) => const QRScannerPage()),
    );

    if (!mounted || result == null || result.isEmpty) {
      return;
    }

    final userProvider = context.read<UserProvider>();
    final res = await ApiService.post(
      'device/scanTheCode',
      {'deviceWayId': '0', 'qrCode': result},
      token: userProvider.token,
      userId: userProvider.userId,
    );

    if (!mounted) {
      return;
    }

    if (res != null &&
        (res['code'] == 0 || res['code'] == '0' || res['code'] == 200)) {
      ToastService.show('设备绑定成功');
      context.read<DeviceProvider>().refreshDeviceListFromNet(
        userProvider.token,
        userProvider.userId,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _step > 0
                  ? GestureDetector(
                      onTap: _onBack,
                      child: const Icon(
                        Icons.arrow_back_ios_new,
                        size: 20,
                        color: DialogUtils.titleColor,
                      ),
                    )
                  : const SizedBox(width: 20),
              Text(
                _titles.last,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: DialogUtils.titleColor,
                ),
              ),
              GestureDetector(
                onTap: _openScanner,
                child: const Icon(
                  Icons.qr_code_scanner,
                  size: 22,
                  color: DialogUtils.titleColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(5, (index) {
              final isActive = index <= _step;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: index < 4 ? 8 : 0),
                  child: Column(
                    children: [
                      Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isActive
                              ? const Color(0xFF34C759)
                              : DialogUtils.mutedColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 800),
                        height: 8,
                        decoration: BoxDecoration(
                          color: isActive
                              ? const Color(0xFF34C759)
                              : DialogUtils.surfaceBackgroundColor,
                          borderRadius: BorderRadius.circular(100),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 320,
            child: _isLoading
                ? const _SkeletonList()
                : _currentList.isEmpty
                ? const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: Center(
                      child: Text(
                        '暂无数据',
                        style: TextStyle(color: DialogUtils.mutedColor),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: _currentList.length,
                    itemBuilder: (context, index) => ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 0,
                      ),
                      title: Text(
                        _currentList[index]['name']!,
                        style: const TextStyle(
                          fontSize: 15,
                          color: DialogUtils.titleColor,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.chevron_right,
                        color: DialogUtils.mutedColor,
                        size: 20,
                      ),
                      onTap: () => _onItemTap(_currentList[index]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonList extends StatefulWidget {
  const _SkeletonList();

  @override
  State<_SkeletonList> createState() => _SkeletonListState();
}

class _SkeletonListState extends State<_SkeletonList>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        8,
        (index) => Container(
          height: 38,
          alignment: Alignment.centerLeft,
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (context, child) {
              return ShaderMask(
                shaderCallback: (rect) {
                  return LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      DialogUtils.surfaceBackgroundColor,
                      const Color(0xFF2A303A),
                      DialogUtils.surfaceBackgroundColor,
                    ],
                    stops: [_ctrl.value - 0.3, _ctrl.value, _ctrl.value + 0.3],
                  ).createShader(rect);
                },
                child: Container(
                  height: 14,
                  width: index.isEven ? 130 : 100,
                  decoration: BoxDecoration(
                    color: DialogUtils.surfaceBackgroundColor,
                    borderRadius: BorderRadius.circular(7),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
