import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/water_usage_history_entry.dart';
import '../../providers/water_provider.dart';

class HistoryBottomSheet extends StatelessWidget {
  const HistoryBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<WaterProvider>(
      builder: (context, waterProvider, child) {
        final history = waterProvider.displayHistory;
        final isLoading = waterProvider.isHistoryLoading;

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '\u7528\u6c34\u8bb0\u5f55',
                  style: TextStyle(
                    color: Color(0xFF2C2C2E),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  isLoading
                      ? '\u540c\u6b65\u4e2d...'
                      : '\u5171 ${history.length} \u6761',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (isLoading)
              const _HistorySkeletonList()
            else if (history.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Text(
                    '\u6682\u65e0\u5386\u53f2\u8bb0\u5f55',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.5,
                ),
                child: ListView.separated(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  itemCount: history.length,
                  separatorBuilder: (context, index) =>
                      Divider(height: 1, color: Colors.grey[100]),
                  itemBuilder: (context, index) {
                    return _HistoryItem(entry: history[index]);
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

class _HistorySkeletonList extends StatelessWidget {
  const _HistorySkeletonList();

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.5,
      ),
      child: ListView.separated(
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 5,
        separatorBuilder: (context, index) =>
            Divider(height: 1, color: Colors.grey[100]),
        itemBuilder: (context, index) => const _HistorySkeletonItem(),
      ),
    );
  }
}

class _HistorySkeletonItem extends StatelessWidget {
  const _HistorySkeletonItem();

  @override
  Widget build(BuildContext context) {
    return const Padding(
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
    return Padding(
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
    );
  }
}
