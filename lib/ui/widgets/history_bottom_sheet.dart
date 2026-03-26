import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/water_provider.dart';
import 'dialog_utils.dart';

class HistoryBottomSheet extends StatelessWidget {
  const HistoryBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<WaterProvider>(
      builder: (context, waterProvider, child) {
        final history = waterProvider.history;

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("用水记录", style: TextStyle(color: Color(0xFF2C2C2E), fontSize: 18, fontWeight: FontWeight.bold)),
                if (history.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      DialogUtils.showClearHistoryConfirmDialog(context);
                    },
                    child: Row(
                      children: [
                        Text("共 ${history.length} 条", style: const TextStyle(color: Colors.grey, fontSize: 13)),
                        const SizedBox(width: 8),
                        const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                      ],
                    ),
                  )
                else
                  const Text("共 0 条", style: TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 16),
            if (history.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: Text("暂无历史记录", style: TextStyle(color: Colors.grey, fontSize: 14))),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  itemCount: history.length,
                  separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey[100]),
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), shape: BoxShape.circle),
                            child: const Icon(Icons.history, color: Colors.blue, size: 16),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              history[index],
                              style: const TextStyle(color: Color(0xFF2C2C2E), fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      }
    );
  }
}