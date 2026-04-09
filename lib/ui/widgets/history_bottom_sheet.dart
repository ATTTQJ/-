import 'dart:async';
import 'dart:ui' show FontFeature, ImageFilter;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/water_usage_history_entry.dart';
import '../../providers/user_provider.dart';
import '../../providers/water_provider.dart';

const int _historyVisibleCount = 5;
const double _historyItemExtent = 72.0;
const double _historyDividerHeight = 1.0;
const double _historyViewportHeight =
    (_historyVisibleCount * _historyItemExtent) +
    ((_historyVisibleCount - 1) * _historyDividerHeight);

class HistoryBottomSheet extends StatefulWidget {
  const HistoryBottomSheet({super.key});

  @override
  State<HistoryBottomSheet> createState() => _HistoryBottomSheetState();
}

class _HistoryBottomSheetState extends State<HistoryBottomSheet> {
  bool _isMonthSwitching = false;
  int? _pendingYear;
  int? _pendingMonth;

  Future<void> _switchHistoryMonth({
    required UserProvider userProvider,
    required WaterProvider waterProvider,
    required int year,
    required int month,
  }) async {
    final currentYear = waterProvider.selectedHistoryYear;
    final currentMonth = waterProvider.selectedHistoryMonth;
    if (year == currentYear && month == currentMonth) {
      return;
    }

    setState(() {
      _isMonthSwitching = true;
      _pendingYear = year;
      _pendingMonth = month;
    });

    await Future<void>.delayed(const Duration(milliseconds: 220));
    await waterProvider.syncHistoryMonth(
      token: userProvider.token,
      userId: userProvider.userId,
      year: year,
      month: month,
      selectAfterSync: true,
      muteToast: true,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isMonthSwitching = false;
      _pendingYear = null;
      _pendingMonth = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<UserProvider, WaterProvider>(
      builder: (context, userProvider, waterProvider, child) {
        final history = waterProvider.displayHistory;
        final isLoading = waterProvider.isHistoryLoading || _isMonthSwitching;
        final selectedYear = _pendingYear ?? waterProvider.selectedHistoryYear;
        final selectedMonth =
            _pendingMonth ?? waterProvider.selectedHistoryMonth;
        final availableYears = waterProvider.availableHistoryYears;

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Expanded(
                  child: Text(
                    '用水记录',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                _LocalRecordsTrigger(
                  count: waterProvider.localDurationRecords.length,
                  onTap: () async {
                    await showDialog<void>(
                      context: context,
                      builder: (dialogContext) => _LocalHistoryRecordsDialog(
                        records: waterProvider.localDurationRecords,
                      ),
                    );
                  },
                ),
                const SizedBox(width: 10),
                _HistoryMonthTrigger(
                  month: selectedMonth,
                  onTap: () async {
                    final result = await showDialog<_HistoryMonthSelection>(
                      context: context,
                      builder: (dialogContext) => _HistoryMonthPickerDialog(
                        initialYear: selectedYear,
                        initialMonth: selectedMonth,
                        availableYears: availableYears,
                        monthsForYear: waterProvider.availableMonthsForYear,
                      ),
                    );
                    if (result == null) {
                      return;
                    }
                    unawaited(
                      _switchHistoryMonth(
                        userProvider: userProvider,
                        waterProvider: waterProvider,
                        year: result.year,
                        month: result.month,
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              isLoading ? '同步中...' : '共 ${history.length} 条',
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: _historyViewportHeight,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                reverseDuration: const Duration(milliseconds: 520),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeOutCubic,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                  child: child,
                ),
                layoutBuilder: (currentChild, previousChildren) {
                  return currentChild ?? const SizedBox.shrink();
                },
                child: isLoading
                    ? const KeyedSubtree(
                        key: ValueKey<String>('history_loading'),
                        child: _HistorySkeletonList(),
                      )
                    : history.isEmpty
                        ? const KeyedSubtree(
                            key: ValueKey<String>('history_empty'),
                            child: Center(
                              child: Text(
                                '暂无历史记录',
                                style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          )
                        : KeyedSubtree(
                            key: ValueKey<String>(
                              'history_list_${waterProvider.selectedHistoryMonthKey}_${history.length}',
                            ),
                            child: ListView.separated(
                              padding: EdgeInsets.zero,
                              physics: history.length > _historyVisibleCount
                                  ? const BouncingScrollPhysics()
                                  : const NeverScrollableScrollPhysics(),
                              itemCount: history.length,
                              separatorBuilder: (context, index) => Divider(
                                height: _historyDividerHeight,
                                indent: 42,
                                color: Colors.white.withOpacity(0.05),
                              ),
                              itemBuilder: (context, index) {
                                return _HistoryItem(entry: history[index]);
                              },
                            ),
                          ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _HistoryMonthTrigger extends StatelessWidget {
  const _HistoryMonthTrigger({
    required this.month,
    required this.onTap,
  });

  final int month;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withOpacity(0.04),
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$month月',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 2),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 15,
              color: Colors.white60,
            ),
          ],
        ),
      ),
    );
  }
}

class _LocalRecordsTrigger extends StatelessWidget {
  const _LocalRecordsTrigger({
    required this.count,
    required this.onTap,
  });

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          '本地 $count',
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _HistoryItem extends StatelessWidget {
  const _HistoryItem({required this.entry});

  final WaterUsageHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final amount = double.tryParse(entry.formattedAmount) ?? 0.0;
    final isZero = amount == 0.0;

    return _HistoryRowFrame(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.history_rounded,
                color: Color(0xFF9B82FF),
                size: 16,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.displayDeviceName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          entry.formattedDate,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 11.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          '时长 ${entry.formattedDuration}',
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 11.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '¥${entry.formattedAmount}',
              style: TextStyle(
                color: isZero ? Colors.white38 : const Color(0xFF58D2CB),
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistorySkeletonList extends StatelessWidget {
  const _HistorySkeletonList();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _historyVisibleCount,
      separatorBuilder: (context, index) => Divider(
        height: _historyDividerHeight,
        indent: 42,
        color: Colors.white.withOpacity(0.04),
      ),
      itemBuilder: (context, index) => const _HistorySkeletonItem(),
    );
  }
}

class _HistoryRowFrame extends StatelessWidget {
  const _HistoryRowFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _historyItemExtent,
      child: child,
    );
  }
}

class _HistorySkeletonItem extends StatelessWidget {
  const _HistorySkeletonItem();

  @override
  Widget build(BuildContext context) {
    return const _HistoryRowFrame(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 11),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _SkeletonCircle(),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SkeletonBar(width: 108, height: 13),
                  SizedBox(height: 8),
                  _SkeletonBar(width: 150, height: 9),
                ],
              ),
            ),
            SizedBox(width: 12),
            _SkeletonPill(width: 54, height: 12),
          ],
        ),
      ),
    );
  }
}

class _SkeletonCircle extends StatelessWidget {
  const _SkeletonCircle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _SkeletonBar extends StatelessWidget {
  const _SkeletonBar({
    required this.width,
    required this.height,
  });

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(height / 2),
      ),
    );
  }
}

class _SkeletonPill extends StatelessWidget {
  const _SkeletonPill({
    required this.width,
    required this.height,
  });

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}

class _HistoryMonthSelection {
  const _HistoryMonthSelection({
    required this.year,
    required this.month,
  });

  final int year;
  final int month;
}

class _HistoryMonthPickerDialog extends StatefulWidget {
  const _HistoryMonthPickerDialog({
    required this.initialYear,
    required this.initialMonth,
    required this.availableYears,
    required this.monthsForYear,
  });

  final int initialYear;
  final int initialMonth;
  final List<int> availableYears;
  final List<int> Function(int year) monthsForYear;

  @override
  State<_HistoryMonthPickerDialog> createState() =>
      _HistoryMonthPickerDialogState();
}

class _HistoryMonthPickerDialogState extends State<_HistoryMonthPickerDialog> {
  late int _selectedYear;
  late int _selectedMonth;

  @override
  void initState() {
    super.initState();
    _selectedYear = widget.initialYear;
    _selectedMonth = widget.initialMonth;
  }

  @override
  Widget build(BuildContext context) {
    final months = widget.monthsForYear(_selectedYear);
    if (!months.contains(_selectedMonth)) {
      _selectedMonth = months.last;
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xF1171A20),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: Colors.white.withOpacity(0.06), width: 0.6),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.24),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '选择查询月份',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    '年份',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: widget.availableYears
                        .map(
                          (year) => _PickerChip(
                            label: '$year年',
                            selected: year == _selectedYear,
                            onTap: () {
                              setState(() {
                                _selectedYear = year;
                                final yearMonths = widget.monthsForYear(year);
                                if (!yearMonths.contains(_selectedMonth)) {
                                  _selectedMonth = yearMonths.last;
                                }
                              });
                            },
                          ),
                        )
                        .toList(growable: false),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    '月份',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: months
                        .map(
                          (month) => _PickerChip(
                            label: '$month月',
                            selected: month == _selectedMonth,
                            onTap: () {
                              Navigator.of(context).pop(
                                _HistoryMonthSelection(
                                  year: _selectedYear,
                                  month: month,
                                ),
                              );
                            },
                          ),
                        )
                        .toList(growable: false),
                  ),
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white70,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text(
                        '取消',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
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

class _PickerChip extends StatelessWidget {
  const _PickerChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF7162FF)
              : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? Colors.transparent
                : Colors.white.withOpacity(0.04),
            width: 0.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : Colors.white70,
          ),
        ),
      ),
    );
  }
}

class _LocalHistoryRecordsDialog extends StatelessWidget {
  const _LocalHistoryRecordsDialog({
    required this.records,
  });

  final List<WaterUsageHistoryEntry> records;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xF1171A20),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: Colors.white.withOpacity(0.06), width: 0.6),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.24),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '本地记录 (${records.length})',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '用于核对本地是否写入了用水时长补丁',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 12.5,
                    ),
                  ),
                  const SizedBox(height: 18),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 420),
                    child: records.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 32),
                              child: Text(
                                '暂无本地记录',
                                style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            physics: const BouncingScrollPhysics(),
                            itemCount: records.length,
                            separatorBuilder: (context, index) => Divider(
                              height: 1,
                              color: Colors.white.withOpacity(0.05),
                            ),
                            itemBuilder: (context, index) => _LocalHistoryRecordItem(
                              entry: records[index],
                            ),
                          ),
                  ),
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white70,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text(
                        '关闭',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
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

class _LocalHistoryRecordItem extends StatelessWidget {
  const _LocalHistoryRecordItem({
    required this.entry,
  });

  final WaterUsageHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final orderNum = entry.orderNum.trim().isEmpty ? '无' : entry.orderNum.trim();
    final deviceId =
        (entry.deviceId?.trim().isEmpty ?? true) ? '无' : entry.deviceId!.trim();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            entry.displayDeviceName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            '${entry.formattedDate}  |  时长 ${entry.formattedDuration}  |  ¥${entry.formattedAmount}',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'orderNum: $orderNum',
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 11,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'deviceId: $deviceId',
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 11,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}
