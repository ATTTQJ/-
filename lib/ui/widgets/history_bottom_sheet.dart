import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/water_usage_history_entry.dart';
import '../../providers/user_provider.dart';
import '../../providers/water_provider.dart';

const int _historyVisibleCount = 5;
const double _historyItemExtent = 76.0;
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
        final selectedMonth = _pendingMonth ?? waterProvider.selectedHistoryMonth;
        final availableYears = waterProvider.availableHistoryYears;

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '\u7528\u6c34\u8bb0\u5f55',
                  style: TextStyle(
                    color: Color(0xFF2C2C2E),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
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
                    unawaited(_switchHistoryMonth(
                      userProvider: userProvider,
                      waterProvider: waterProvider,
                      year: result.year,
                      month: result.month,
                    ));
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              isLoading ? '\u540c\u6b65\u4e2d...' : '\u5171 ${history.length} \u6761',
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: _historyViewportHeight,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 320),
                reverseDuration: const Duration(milliseconds: 560),
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
                                '\u6682\u65e0\u5386\u53f2\u8bb0\u5f55',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
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
                              separatorBuilder: (context, index) =>
                                  Divider(
                                    height: _historyDividerHeight,
                                    color: Colors.grey[100],
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
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$month\u6708',
              style: const TextStyle(
                color: Color(0xFF2C2C2E),
                fontSize: 15,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
            const SizedBox(width: 2),
            const Padding(
              padding: EdgeInsets.only(top: 1),
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: Color(0xFF2C2C2E),
              ),
            ),
          ],
        ),
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
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '\u9009\u62e9\u67e5\u8be2\u6708\u4efd',
              style: TextStyle(
                color: Color(0xFF2C2C2E),
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              '\u5e74\u4efd',
              style: TextStyle(
                color: Color(0xFF8E8E93),
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
                      label: '$year\u5e74',
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
            const SizedBox(height: 18),
            const Text(
              '\u6708\u4efd',
              style: TextStyle(
                color: Color(0xFF8E8E93),
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
                      label: '$month\u6708',
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
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('\u53d6\u6d88'),
              ),
            ),
          ],
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF2C2C2E) : const Color(0xFFF4F5F7),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : const Color(0xFF2C2C2E),
          ),
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
        color: Colors.grey[100],
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
        padding: EdgeInsets.symmetric(vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SkeletonCircle(),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SkeletonBar(width: 116, height: 14),
                  SizedBox(height: 8),
                  _SkeletonBar(width: 84, height: 11),
                  SizedBox(height: 8),
                  _SkeletonBar(width: 140, height: 11),
                ],
              ),
            ),
            SizedBox(width: 12),
            _SkeletonPill(width: 68, height: 32),
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
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: const Color(0xFFF2F3F7),
        borderRadius: BorderRadius.circular(14),
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
        color: const Color(0xFFF2F3F7),
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
        color: const Color(0xFFFFF1E5),
        borderRadius: BorderRadius.circular(14),
      ),
    );
  }
}

class _HistoryItem extends StatelessWidget {
  const _HistoryItem({required this.entry});

  final WaterUsageHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    return _HistoryRowFrame(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 2),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.history, color: Colors.blue, size: 16),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.displayDeviceName,
                    style: const TextStyle(
                      color: Color(0xFF2C2C2E),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    entry.formattedDate,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '\u7528\u6c34\u65f6\u957f\uff1a${entry.formattedDuration}',
                    style: TextStyle(color: Colors.grey[700], fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF4EA),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                '\u00A5${entry.formattedAmount}',
                style: const TextStyle(
                  color: Color(0xFFD85B00),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
