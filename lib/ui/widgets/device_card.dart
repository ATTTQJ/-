import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/device_provider.dart';
import '../../providers/water_provider.dart';
import '../../providers/user_provider.dart';
import '../../core/toast_service.dart';
import 'dialog_utils.dart';

class DeviceCard extends StatefulWidget {
  const DeviceCard({super.key});

  @override
  State<DeviceCard> createState() => _DeviceCardState();
}

class _DeviceCardState extends State<DeviceCard> {
  bool _isDeviceExpanded = false;
  bool _isActionMenuCollapsed = false;

  @override
  Widget build(BuildContext context) {
    return Consumer2<DeviceProvider, WaterProvider>(
      builder: (context, deviceProvider, waterProvider, child) {
        Map<String, dynamic>? selectedDevice = deviceProvider.deviceList.isNotEmpty ?
            deviceProvider.deviceList.firstWhere(
              (d) => d["deviceInfId"].toString() == deviceProvider.selectedDeviceId, 
              orElse: () => deviceProvider.deviceList[0]
            ) : null;
        
        String title = selectedDevice != null ?
            (deviceProvider.customRemarks[selectedDevice["deviceInfId"].toString()] ?? 
             selectedDevice["deviceInfName"].toString().replaceAll(RegExp(r'^[12]-'), '')) : "请先添加设备";

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            decoration: BoxDecoration(
              color: Colors.white, 
              borderRadius: BorderRadius.circular(18), 
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15)]
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () {
                      if (deviceProvider.deviceList.isNotEmpty) {
                        if (!deviceProvider.isAlwaysExpanded) {
                          setState(() => _isDeviceExpanded = !_isDeviceExpanded);
                        }
                      } else {
                        DialogUtils.showCascadingAddDeviceDialog(context);
                      }
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      child: Row(
                        children: [
                          if (selectedDevice != null) ...[
                            Icon(
                              selectedDevice["billType"] == 2 ? Icons.hot_tub : Icons.water_drop, 
                              color: selectedDevice["billType"] == 2 ? Colors.orange : Colors.blue, 
                              size: 22
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: Text(title, style: const TextStyle(color: Color(0xFF2C2C2E), fontSize: 16, fontWeight: FontWeight.bold)))
                          ] else ...[
                            const Icon(Icons.add_circle, color: Colors.blue, size: 22),
                            const SizedBox(width: 12),
                            Expanded(child: Text("添加你的第一个设备", style: const TextStyle(color: Color(0xFF2C2C2E), fontSize: 16, fontWeight: FontWeight.bold)))
                          ],
                          if (!deviceProvider.isAlwaysExpanded)
                            Icon(_isDeviceExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: Colors.grey)
                        ]
                      )
                    )
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeInOutCubic,
                    child: (_isDeviceExpanded || deviceProvider.isAlwaysExpanded) ?
                      Column(
                        children: [
                          Divider(height: 1, thickness: 1, color: Colors.grey[100]),
                          ReorderableListView(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            onReorder: (oldIdx, newIdx) {
                              if (newIdx > oldIdx) newIdx--;
                              final item = deviceProvider.deviceList.removeAt(oldIdx);
                              deviceProvider.deviceList.insert(newIdx, item);
                            },
                            children: deviceProvider.deviceList.map((d) => _buildDeviceItem(context, d, deviceProvider, waterProvider)).toList()
                          ),
                          AnimatedSize(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOutCubic,
                            child: (deviceProvider.isAlwaysExpanded && _isActionMenuCollapsed)
                              ? const SizedBox(width: double.infinity, height: 0)
                              : Column(
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(child: _buildIconButton(Icons.refresh, "刷新", Colors.blue, () { 
                                          if(!deviceProvider.isAlwaysExpanded) setState(() => _isDeviceExpanded = false);
                                          final userP = context.read<UserProvider>();
                                          deviceProvider.refreshDeviceListFromNet(userP.token, userP.userId);
                                        })),
                                        Container(width: 1, height: 20, color: Colors.grey[200]),
                                        Expanded(child: _buildIconButton(Icons.delete_outline, "删除", Colors.redAccent, () {
                                          if (selectedDevice != null && selectedDevice["commonlyId"] != null && selectedDevice["commonlyId"].toString().isNotEmpty) {
                                            if(!deviceProvider.isAlwaysExpanded) setState(() => _isDeviceExpanded = false);
                                            DialogUtils.showDeleteConfirmDialog(context, selectedDevice["commonlyId"].toString(), title);
                                          } else {
                                            ToastService.show("无法删除此设备");
                                          }
                                        })),
                                        Container(width: 1, height: 20, color: Colors.grey[200]),
                                        Expanded(child: _buildIconButton(Icons.add_circle_outline, "添加", Colors.blue, () {
                                          DialogUtils.showCascadingAddDeviceDialog(context);
                                        })),
                                      ]
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(right: 20, bottom: 16, top: 4),
                                      child: Align(
                                        alignment: Alignment.centerRight,
                                        child: GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              bool nextState = !deviceProvider.isAlwaysExpanded;
                                              deviceProvider.setAlwaysExpanded(nextState);
                                              if (nextState) {
                                                _isActionMenuCollapsed = true;
                                                _isDeviceExpanded = true;
                                              }
                                            });
                                          },
                                          child: Container(
                                            width: 94,
                                            height: 28,
                                            padding: const EdgeInsets.all(2),
                                            decoration: BoxDecoration(
                                              color: Colors.grey[200],
                                              borderRadius: BorderRadius.circular(100),
                                            ),
                                            child: Stack(
                                              children: [
                                                AnimatedAlign(
                                                  duration: const Duration(milliseconds: 250),
                                                  curve: Curves.easeInOutCubic,
                                                  alignment: deviceProvider.isAlwaysExpanded ? Alignment.centerRight : Alignment.centerLeft,
                                                  child: Container(
                                                    width: 45,
                                                    height: 24,
                                                    decoration: BoxDecoration(
                                                      color: Colors.white,
                                                      borderRadius: BorderRadius.circular(100),
                                                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2, offset: Offset(0, 1))]
                                                    ),
                                                  ),
                                                ),
                                                Row(
                                                  children: [
                                                    Expanded(child: Center(child: Text("默认", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: !deviceProvider.isAlwaysExpanded ? Colors.black87 : Colors.grey[600])))),
                                                    Expanded(child: Center(child: Text("常驻", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: deviceProvider.isAlwaysExpanded ? Colors.black87 : Colors.grey[600])))),
                                                  ]
                                                )
                                              ],
                                            ),
                                          ),
                                        ),
                                      )
                                    )
                                  ],
                                ),
                          )
                        ]
                      ) : const SizedBox(width: double.infinity, height: 0)
                  )
                ]
              )
            )
          )
        );
      }
    );
  }

  Widget _buildIconButton(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold))
          ]
        )
      )
    );
  }

  Widget _buildDeviceItem(BuildContext context, Map<String, dynamic> device, DeviceProvider deviceProvider, WaterProvider waterProvider) {
    String id = device["deviceInfId"].toString();
    bool isSelected = id == deviceProvider.selectedDeviceId;
    String name = deviceProvider.customRemarks[id] ?? device["deviceInfName"].toString().replaceAll(RegExp(r'^[12]-'), '');
    
    return GestureDetector(
      key: ValueKey(id),
      onTap: () {
        if (waterProvider.orderNum.isNotEmpty) {
          ToastService.show("用水中，无法切换设备");
        } else {
          deviceProvider.selectDevice(id);
          if (!deviceProvider.isAlwaysExpanded) {
            setState(() => _isDeviceExpanded = false);
          }
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        color: isSelected ? Colors.grey[50] : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(Icons.drag_handle, color: Colors.grey[400], size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text("$name (${device["billType"] == 2 ? "热水" : "直饮"})", style: TextStyle(color: isSelected ? const Color(0xFF2C2C2E) : Colors.grey[700], fontSize: 14, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal))),
            if (isSelected) const Icon(Icons.check, color: Color(0xFF2C2C2E), size: 18),
            const SizedBox(width: 16),
            GestureDetector(
              onTap: () {
                DialogUtils.showEditRemarkDialog(context, id, name);
              },
              child: Icon(Icons.edit_note, color: Colors.grey[400], size: 22)
            )
          ]
        )
      )
    );
  }
}