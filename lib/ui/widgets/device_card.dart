import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/toast_service.dart';
import '../../providers/device_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/water_provider.dart';
import 'dialog_utils.dart';

class DeviceCard extends StatefulWidget {
  const DeviceCard({super.key});

  @override
  State<DeviceCard> createState() => _DeviceCardState();
}

class _DeviceCardState extends State<DeviceCard> {
  bool _isDeviceExpanded = false;
  bool _isActionMenuCollapsed = true;
  String? _draggingDeviceId;
  int? _dragTargetIndex;

  @override
  Widget build(BuildContext context) {
    return Consumer2<DeviceProvider, WaterProvider>(
      builder: (context, deviceProvider, waterProvider, child) {
        final selectedDevice = _selectedDevice(deviceProvider);
        final title = selectedDevice == null
            ? '\u8bf7\u5148\u6dfb\u52a0\u8bbe\u5907'
            : _deviceDisplayName(deviceProvider, selectedDevice);
        final shouldShowContent =
            _isDeviceExpanded || deviceProvider.isAlwaysExpanded;
        final shouldShowActionBar =
            !deviceProvider.isAlwaysExpanded || !_isActionMenuCollapsed;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.fastOutSlowIn,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 15,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () {
                      if (deviceProvider.deviceList.isEmpty) {
                        DialogUtils.showCascadingAddDeviceDialog(context);
                        return;
                      }
                      if (!deviceProvider.isAlwaysExpanded) {
                        setState(() {
                          _isDeviceExpanded = !_isDeviceExpanded;
                        });
                      }
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      child: Row(
                        children: [
                          if (selectedDevice != null) ...[
                            Icon(
                              selectedDevice['billType'] == 2
                                  ? Icons.hot_tub
                                  : Icons.water_drop,
                              color: selectedDevice['billType'] == 2
                                  ? Colors.orange
                                  : Colors.blue,
                              size: 22,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                title,
                                style: const TextStyle(
                                  color: Color(0xFF2C2C2E),
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ] else ...[
                            const Icon(
                              Icons.add_circle,
                              color: Colors.blue,
                              size: 22,
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                '\u6dfb\u52a0\u4f60\u7684\u7b2c\u4e00\u4e2a\u8bbe\u5907',
                                style: TextStyle(
                                  color: Color(0xFF2C2C2E),
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                          if (deviceProvider.deviceList.isNotEmpty &&
                              deviceProvider.isAlwaysExpanded)
                            Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () {
                                  setState(() {
                                    _isActionMenuCollapsed =
                                        !_isActionMenuCollapsed;
                                  });
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(6),
                                  child: Icon(
                                    _isActionMenuCollapsed
                                        ? Icons.tune_rounded
                                        : Icons.close_rounded,
                                    color: Colors.grey[700],
                                    size: 18,
                                  ),
                                ),
                              ),
                            ),
                          if (!deviceProvider.isAlwaysExpanded)
                            Icon(
                              _isDeviceExpanded
                                  ? Icons.keyboard_arrow_up
                                  : Icons.keyboard_arrow_down,
                              color: Colors.grey,
                            ),
                        ],
                      ),
                    ),
                  ),
                  ClipRect(
                    child: AnimatedSize(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.fastOutSlowIn,
                      alignment: Alignment.topCenter,
                      child: shouldShowContent
                          ? SizedBox(
                              width: double.infinity,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(height: 1, color: Colors.grey[100]),
                                  _buildDeviceList(
                                    context,
                                    deviceProvider,
                                    waterProvider,
                                  ),
                                  AnimatedSize(
                                    duration: const Duration(milliseconds: 350),
                                    curve: Curves.fastOutSlowIn,
                                    alignment: Alignment.topCenter,
                                    child: shouldShowActionBar
                                        ? SizedBox(
                                            width: double.infinity,
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: _buildIconButton(
                                                        Icons.refresh,
                                                        '\u5237\u65b0',
                                                        Colors.blue,
                                                        () {
                                                          if (!deviceProvider
                                                              .isAlwaysExpanded) {
                                                            setState(() {
                                                              _isDeviceExpanded =
                                                                  false;
                                                            });
                                                          }
                                                          final userProvider =
                                                              context.read<
                                                                  UserProvider>();
                                                          deviceProvider
                                                              .refreshDeviceListFromNet(
                                                            userProvider.token,
                                                            userProvider.userId,
                                                          );
                                                        },
                                                      ),
                                                    ),
                                                    Container(
                                                      width: 1,
                                                      height: 20,
                                                      color: Colors.grey[200],
                                                    ),
                                                    Expanded(
                                                      child: _buildIconButton(
                                                        Icons.delete_outline,
                                                        '\u5220\u9664',
                                                        Colors.redAccent,
                                                        () {
                                                          if (selectedDevice !=
                                                                  null &&
                                                              selectedDevice['commonlyId'] !=
                                                                  null &&
                                                              selectedDevice['commonlyId']
                                                                  .toString()
                                                                  .isNotEmpty) {
                                                            if (!deviceProvider
                                                                .isAlwaysExpanded) {
                                                              setState(() {
                                                                _isDeviceExpanded =
                                                                    false;
                                                              });
                                                            }
                                                            DialogUtils.showDeleteConfirmDialog(
                                                              context,
                                                              selectedDevice['commonlyId']
                                                                  .toString(),
                                                              title,
                                                            );
                                                          } else {
                                                            ToastService.show(
                                                              '\u65e0\u6cd5\u5220\u9664\u6b64\u8bbe\u5907',
                                                            );
                                                          }
                                                        },
                                                      ),
                                                    ),
                                                    Container(
                                                      width: 1,
                                                      height: 20,
                                                      color: Colors.grey[200],
                                                    ),
                                                    Expanded(
                                                      child: _buildIconButton(
                                                        Icons.add_circle_outline,
                                                        '\u6dfb\u52a0',
                                                        Colors.blue,
                                                        () {
                                                          DialogUtils.showCascadingAddDeviceDialog(
                                                            context,
                                                          );
                                                        },
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                Padding(
                                                  padding: const EdgeInsets.only(
                                                    right: 20,
                                                    bottom: 16,
                                                    top: 4,
                                                  ),
                                                  child: Align(
                                                    alignment:
                                                        Alignment.centerRight,
                                                    child: GestureDetector(
                                                      onTap: () {
                                                        setState(() {
                                                          final nextState =
                                                              !deviceProvider
                                                                  .isAlwaysExpanded;
                                                          deviceProvider
                                                              .setAlwaysExpanded(
                                                            nextState,
                                                          );
                                                          if (nextState) {
                                                            _isActionMenuCollapsed =
                                                                true;
                                                            _isDeviceExpanded =
                                                                true;
                                                          } else {
                                                            _isActionMenuCollapsed =
                                                                false;
                                                          }
                                                        });
                                                      },
                                                      child: Container(
                                                        width: 94,
                                                        height: 28,
                                                        padding:
                                                            const EdgeInsets.all(
                                                          2,
                                                        ),
                                                        decoration: BoxDecoration(
                                                          color: Colors.grey[200],
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                            100,
                                                          ),
                                                        ),
                                                        child: Stack(
                                                          children: [
                                                            AnimatedAlign(
                                                              duration:
                                                                  const Duration(
                                                                milliseconds:
                                                                    250,
                                                              ),
                                                              curve: Curves
                                                                  .easeInOutCubic,
                                                              alignment: deviceProvider
                                                                      .isAlwaysExpanded
                                                                  ? Alignment
                                                                      .centerRight
                                                                  : Alignment
                                                                      .centerLeft,
                                                              child: Container(
                                                                width: 45,
                                                                height: 24,
                                                                decoration: BoxDecoration(
                                                                  color: Colors
                                                                      .white,
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                    100,
                                                                  ),
                                                                  boxShadow: const [
                                                                    BoxShadow(
                                                                      color: Colors
                                                                          .black12,
                                                                      blurRadius:
                                                                          2,
                                                                      offset:
                                                                          Offset(
                                                                        0,
                                                                        1,
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                            ),
                                                            Row(
                                                              children: [
                                                                Expanded(
                                                                  child: Center(
                                                                    child: Text(
                                                                      '\u9ed8\u8ba4',
                                                                      style:
                                                                          TextStyle(
                                                                        fontSize:
                                                                            11,
                                                                        fontWeight:
                                                                            FontWeight.bold,
                                                                        color: !deviceProvider
                                                                                .isAlwaysExpanded
                                                                            ? Colors.black87
                                                                            : Colors.grey[600],
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ),
                                                                Expanded(
                                                                  child: Center(
                                                                    child: Text(
                                                                      '\u5e38\u9a7b',
                                                                      style:
                                                                          TextStyle(
                                                                        fontSize:
                                                                            11,
                                                                        fontWeight:
                                                                            FontWeight.bold,
                                                                        color: deviceProvider
                                                                                .isAlwaysExpanded
                                                                            ? Colors.black87
                                                                            : Colors.grey[600],
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          )
                                        : const SizedBox(
                                            width: double.infinity,
                                            height: 0,
                                          ),
                                  ),
                                ],
                              ),
                            )
                          : const SizedBox(width: double.infinity, height: 0),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDeviceList(
    BuildContext context,
    DeviceProvider deviceProvider,
    WaterProvider waterProvider,
  ) {
    final children = <Widget>[];
    for (var index = 0; index <= deviceProvider.deviceList.length; index++) {
      children.add(_buildDropTarget(deviceProvider, index));
      if (index < deviceProvider.deviceList.length) {
        children.add(
          _buildDraggableDeviceItem(
            context,
            deviceProvider.deviceList[index],
            deviceProvider,
            waterProvider,
            index,
          ),
        );
      }
    }
    return Column(mainAxisSize: MainAxisSize.min, children: children);
  }

  Widget _buildDropTarget(DeviceProvider deviceProvider, int index) {
    final isActive = _draggingDeviceId != null && _dragTargetIndex == index;
    return DragTarget<String>(
      onWillAcceptWithDetails: (details) {
        setState(() {
          _dragTargetIndex = index;
        });
        return details.data != null;
      },
      onAcceptWithDetails: (details) {
        _reorderDevices(deviceProvider, details.data, index);
      },
      onLeave: (_) {
        if (_dragTargetIndex == index) {
          setState(() {
            _dragTargetIndex = null;
          });
        }
      },
      builder: (context, candidateData, rejectedData) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: isActive ? 12 : 0,
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: isActive ? 0.18 : 0),
            borderRadius: BorderRadius.circular(999),
          ),
        );
      },
    );
  }

  void _reorderDevices(
    DeviceProvider deviceProvider,
    String draggedDeviceId,
    int targetIndex,
  ) {
    final oldIndex = deviceProvider.deviceList.indexWhere(
      (device) => device['deviceInfId'].toString() == draggedDeviceId,
    );
    if (oldIndex < 0) {
      _clearDragState();
      return;
    }

    var newIndex = targetIndex;
    if (newIndex > oldIndex) {
      newIndex--;
    }

    setState(() {
      final item = deviceProvider.deviceList.removeAt(oldIndex);
      final safeIndex = newIndex.clamp(0, deviceProvider.deviceList.length);
      deviceProvider.deviceList.insert(safeIndex, item);
      _clearDragState();
    });
  }

  void _clearDragState() {
    _draggingDeviceId = null;
    _dragTargetIndex = null;
  }

  Widget _buildDraggableDeviceItem(
    BuildContext context,
    Map<String, dynamic> device,
    DeviceProvider deviceProvider,
    WaterProvider waterProvider,
    int index,
  ) {
    final id = device['deviceInfId'].toString();
    final width = MediaQuery.of(context).size.width - 56;

    return LongPressDraggable<String>(
      data: id,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      onDragStarted: () {
        setState(() {
          _draggingDeviceId = id;
          _dragTargetIndex = index;
        });
      },
      onDraggableCanceled: (_, __) => setState(_clearDragState),
      onDragEnd: (_) => setState(_clearDragState),
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: width,
          child: _buildDeviceItemBody(
            context,
            device,
            deviceProvider,
            waterProvider,
            dragging: true,
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.22,
        child: _buildDeviceItemBody(
          context,
          device,
          deviceProvider,
          waterProvider,
        ),
      ),
      child: _buildDeviceItemBody(
        context,
        device,
        deviceProvider,
        waterProvider,
      ),
    );
  }

  Map<String, dynamic>? _selectedDevice(DeviceProvider deviceProvider) {
    if (deviceProvider.deviceList.isEmpty) {
      return null;
    }

    return deviceProvider.deviceList.firstWhere(
      (device) =>
          device['deviceInfId'].toString() == deviceProvider.selectedDeviceId,
      orElse: () => deviceProvider.deviceList.first,
    );
  }

  String _deviceDisplayName(
    DeviceProvider deviceProvider,
    Map<String, dynamic> device,
  ) {
    final id = device['deviceInfId'].toString();
    return deviceProvider.customRemarks[id] ??
        device['deviceInfName'].toString().replaceAll(RegExp(r'^[12]-'), '');
  }

  Widget _buildIconButton(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
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
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceItemBody(
    BuildContext context,
    Map<String, dynamic> device,
    DeviceProvider deviceProvider,
    WaterProvider waterProvider, {
    bool dragging = false,
  }) {
    final id = device['deviceInfId'].toString();
    final isSelected = id == deviceProvider.selectedDeviceId;
    final name =
        deviceProvider.customRemarks[id] ??
        device['deviceInfName'].toString().replaceAll(RegExp(r'^[12]-'), '');

    return Material(
      key: ValueKey(id),
      color: Colors.transparent,
      child: GestureDetector(
        onTap: () {
          if (dragging) {
            return;
          }
          if (waterProvider.orderNum.isNotEmpty) {
            ToastService.show('\u7528\u6c34\u4e2d\uff0c\u65e0\u6cd5\u5207\u6362\u8bbe\u5907');
            return;
          }

          deviceProvider.selectDevice(id);
          if (!deviceProvider.isAlwaysExpanded) {
            setState(() {
              _isDeviceExpanded = false;
            });
          }
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          color: dragging
              ? Colors.white.withValues(alpha: 0.96)
              : isSelected
                  ? Colors.grey[50]
                  : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Container(
                color: Colors.transparent,
                padding: const EdgeInsets.only(right: 12, top: 4, bottom: 4),
                child: const Icon(
                  Icons.drag_handle,
                  color: Colors.grey,
                  size: 20,
                ),
              ),
              Expanded(
                child: Text(
                  '$name (${device['billType'] == 2 ? '\u70ed\u6c34' : '\u76f4\u996e'})',
                  style: TextStyle(
                    color: isSelected
                        ? const Color(0xFF2C2C2E)
                        : Colors.grey[700],
                    fontSize: 14,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
              if (isSelected)
                const Icon(Icons.check, color: Color(0xFF2C2C2E), size: 18),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: dragging
                    ? null
                    : () {
                        DialogUtils.showEditRemarkDialog(context, id, name);
                      },
                child: Icon(Icons.edit_note, color: Colors.grey[400], size: 22),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
