import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../core/toast_service.dart';
import '../../providers/user_provider.dart';
import '../../providers/device_provider.dart';
import '../pages/qr_scanner_page.dart';

class DeviceSelectorDialog extends StatefulWidget {
  const DeviceSelectorDialog({super.key});
  @override
  State<DeviceSelectorDialog> createState() => _DeviceSelectorDialogState();
}

class _DeviceSelectorDialogState extends State<DeviceSelectorDialog> {
  final String mySchoolId = "27720";
  int _step = 0;
  bool _isLoading = true;
  String _selectedWayId = "";
  List<Map<String, String>> _currentList = [];
  final List<List<Map<String, String>>> _historyLists = [];
  final List<String> _titles = ["选择用水类型"];
  final List<String> _stepNames = ["选择用水类型", "选择校区", "选择楼栋", "选择楼层", "选择寝室 / 设备"];

  @override
  void initState() {
    super.initState();
    _fetchData(0, mySchoolId);
  }

  String _extractId(Map m) {
    if (m.containsKey("deptId")) return m["deptId"].toString();
    if (m.containsKey("deviceWayId")) return m["deviceWayId"].toString();
    if (m.containsKey("deviceNum")) return m["deviceNum"].toString();
    if (m.containsKey("id")) return m["id"].toString();
    if (m.containsKey("value")) return m["value"].toString();
    if (m.containsKey("sn")) return m["sn"].toString();
    for (var key in m.keys) {
      if (key.toString().toLowerCase().contains("id")) return m[key].toString();
    }
    return "";
  }

  String _extractName(Map m) {
    if (m.containsKey("deptName")) return m["deptName"].toString();
    if (m.containsKey("wayName")) return m["wayName"].toString();
    if (m.containsKey("deviceWayName")) return m["deviceWayName"].toString();
    if (m.containsKey("name")) return m["name"].toString();
    if (m.containsKey("title")) return m["title"].toString();
    if (m.containsKey("label")) return m["label"].toString();
    for (var key in m.keys) {
      if (key.toString().toLowerCase().contains("name")) return m[key].toString();
    }
    return "未知选项";
  }

  Future<void> _fetchData(int step, String id) async {
    setState(() => _isLoading = true);
    String path = step == 0 ? "device/queryDeviceWay" : "school/querySchoolAddress";
    Map<String, String> params = step == 0 ? {"schId": mySchoolId} : {"deptId": id};

    final userProvider = context.read<UserProvider>();
    var res = await ApiService.post(path, params, token: userProvider.token, userId: userProvider.userId, muteToast: true);
    
    List<Map<String, String>> parsed = [];
    if (res != null && (res["code"] == 0 || res["code"] == "0" || res["code"] == 200) && res["data"] != null) {
      var rawData = res["data"];
      List<dynamic> targetList = (rawData is List) ? rawData : (rawData is Map ? rawData.values.firstWhere((v) => v is List, orElse: () => []) : []);
      for (var item in targetList) {
        if (item is Map) {
          String extId = _extractId(item);
          String extName = _extractName(item);
          if (extId.isNotEmpty) parsed.add({"id": extId, "name": extName});
        }
      }
    }
    if (mounted) setState(() { _currentList = parsed; _isLoading = false; });
  }

  void _onItemTap(Map<String, String> item) async {
    if (_step == 0) _selectedWayId = item["id"]!;

    if (_step < 4) {
      _historyLists.add(List.from(_currentList));
      _step++;
      _titles.add(_stepNames[_step]);
      _fetchData(_step, _step == 1 ? mySchoolId : item["id"]!);
    } else {
      setState(() => _isLoading = true);
      final userProvider = context.read<UserProvider>();
      var queryRes = await ApiService.post("device/queryDeviceInfo", {
        "deviceNum": item["id"]!, "schId": mySchoolId, "deviceWayId": _selectedWayId, "type": "4"
      }, token: userProvider.token, userId: userProvider.userId);

      if (queryRes != null && (queryRes["code"] == 0 || queryRes["code"] == "0" || queryRes["code"] == 200)) {
        var data = queryRes["data"];
        if (data != null && data is Map && data["deviceInfId"] != null) {
          var addRes = await ApiService.post("device/operationDeviceCommonly", {
            "deviceTypeId": data["deviceTypeId"]?.toString() ?? "",
            "deviceWayId": data["deviceWayId"]?.toString() ?? _selectedWayId,
            "deviceInfId": data["deviceInfId"].toString(),
            "type": "1"
          }, token: userProvider.token, userId: userProvider.userId);
          
          if (addRes != null && (addRes["code"] == 0 || addRes["code"] == "0" || addRes["code"] == 200)) {
            ToastService.show("设备添加成功！");
            if (mounted) {
              context.read<DeviceProvider>().refreshDeviceListFromNet(userProvider.token, userProvider.userId);
              Navigator.pop(context);
            }
            return;
          }
        }
      }
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onBack() {
    if (_step > 0) {
      setState(() {
        _step--;
        _titles.removeLast();
        _currentList = _historyLists.removeLast();
      });
    }
  }

  void _openScanner() async {
    Navigator.pop(context); // Close dialog first
    final String? result = await Navigator.push(context, MaterialPageRoute(builder: (context) => const QRScannerPage()));
    if (result != null && result.isNotEmpty && mounted) {
      final userProvider = context.read<UserProvider>();
      final res = await ApiService.post("device/scanTheCode", {"deviceWayId": "0", "qrCode": result}, token: userProvider.token, userId: userProvider.userId);
      if (res != null && (res["code"] == 0 || res["code"] == "0" || res["code"] == 200)) {
        ToastService.show("设备绑定成功！");
        context.read<DeviceProvider>().refreshDeviceListFromNet(userProvider.token, userProvider.userId);
      }
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
              _step > 0 ? GestureDetector(onTap: _onBack, child: const Icon(Icons.arrow_back_ios_new, size: 20, color: Color(0xFF2C2C2E))) : const SizedBox(width: 20),
              Text(_titles.last, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF2C2C2E))),
              GestureDetector(onTap: _openScanner, child: const Icon(Icons.qr_code_scanner, size: 22, color: Color(0xFF2C2C2E))),
            ]
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(5, (index) {
              bool isActive = index <= _step;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: index < 4 ? 8.0 : 0),
                  child: Column(
                    children: [
                      Text("${index + 1}", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isActive ? const Color(0xFF34C759) : Colors.grey[400])),
                      const SizedBox(height: 8),
                      AnimatedContainer(duration: const Duration(milliseconds: 800), height: 8, decoration: BoxDecoration(color: isActive ? const Color(0xFF34C759) : Colors.grey[200], borderRadius: BorderRadius.circular(100))),
                    ],
                  ),
                )
              );
            }),
          ),
          const SizedBox(height: 24),
          Container(
            height: 320,
            alignment: Alignment.topCenter,
            child: _isLoading ? const _SkeletonList() : _currentList.isEmpty ? const Padding(padding: EdgeInsets.only(top: 40), child: Text("暂无数据", style: TextStyle(color: Colors.grey))) : ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: _currentList.length,
              itemBuilder: (c, i) => ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                title: Text(_currentList[i]["name"]!, style: const TextStyle(fontSize: 15, color: Color(0xFF2C2C2E))),
                trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
                onTap: () => _onItemTap(_currentList[i]),
              )
            )
          )
        ]
      )
    );
  }
}

class _SkeletonList extends StatefulWidget {
  const _SkeletonList();
  @override
  State<_SkeletonList> createState() => _SkeletonListState();
}

class _SkeletonListState extends State<_SkeletonList> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() { super.initState(); _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(); }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return Column(children: List.generate(8, (i) => Container(height: 38, alignment: Alignment.centerLeft, child: AnimatedBuilder(animation: _ctrl, builder: (context, child) {
      return ShaderMask(
        shaderCallback: (rect) => LinearGradient(begin: Alignment.centerLeft, end: Alignment.centerRight, colors: [Colors.grey[200]!, Colors.grey[50]!, Colors.grey[200]!], stops: [_ctrl.value - 0.3, _ctrl.value, _ctrl.value + 0.3]).createShader(rect),
        child: Container(height: 14, width: i % 2 == 0 ? 130 : 100, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(7)))
      );
    }))));
  }
}