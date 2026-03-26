import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import 'dialog_utils.dart';
import 'history_bottom_sheet.dart';

class UserInfoPanel extends StatelessWidget {
  const UserInfoPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "你好, ${userProvider.userName}",
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 15,
                      fontWeight: FontWeight.w600
                    )
                  ),
                  GestureDetector(
                    onTap: () {
                      DialogUtils.showGlassBottomSheet(context, const HistoryBottomSheet());
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(100)
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.receipt_long, size: 14, color: Colors.grey[700]),
                          const SizedBox(width: 4),
                          Text("历史", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[700]))
                        ],
                      )
                    )
                  )
                ],
              )
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: GestureDetector(
                onTap: () => userProvider.syncBalance(),
                behavior: HitTestBehavior.opaque,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "钱包余额",
                      style: TextStyle(color: Colors.grey, fontSize: 13)
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      child: Text(
                        "¥ ${userProvider.balance}",
                        style: const TextStyle(
                          fontSize: 42,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2C2C2E)
                        )
                      )
                    )
                  ]
                )
              )
            ),
          ],
        );
      }
    );
  }
}