import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/user_provider.dart';
import '../../providers/water_provider.dart';
import 'dialog_utils.dart';
import 'history_bottom_sheet.dart';

class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, child) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: const Text(
                      'SMART WATER',
                      style: TextStyle(
                        color: Color(0xFF9AA3C1),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '\u4f60\u597d\uff0c${userProvider.userName}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      height: 1.06,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _maskedPhone(userProvider.userPhone),
                    style: const TextStyle(
                      color: Color(0xFF8E97B5),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Column(
              children: [
                _HeaderIconButton(
                  icon: Icons.receipt_long_rounded,
                  onTap: () {
                    DialogUtils.showGlassBottomSheet(
                      context,
                      const HistoryBottomSheet(),
                    );
                    unawaited(
                      context.read<WaterProvider>().syncHistoryFromServer(
                        token: userProvider.token,
                        userId: userProvider.userId,
                        muteToast: true,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
                _HeaderIconButton(
                  icon: Icons.logout_rounded,
                  onTap: () => _showLogoutConfirm(context),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  static String _maskedPhone(String phone) {
    if (phone.length < 11) {
      return '\u672a\u7ed1\u5b9a\u624b\u673a\u53f7';
    }
    return '${phone.substring(0, 3)} **** ${phone.substring(7)}';
  }

  static void _showLogoutConfirm(BuildContext context) {
    DialogUtils.showGlassBottomSheet(
      context,
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '\u9000\u51fa\u767b\u5f55',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2C2C2E),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '\u786e\u5b9a\u8981\u9000\u51fa\u5f53\u524d\u8d26\u53f7\u5417\uff1f',
            style: TextStyle(color: Color(0xFF666666), fontSize: 15),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    '\u53d6\u6d88',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ),
              ),
              Expanded(
                child: TextButton(
                  onPressed: () {
                    context.read<UserProvider>().logout();
                    Navigator.pop(context);
                  },
                  child: const Text(
                    '\u9000\u51fa\u767b\u5f55',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
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

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Icon(icon, size: 20, color: Colors.white),
        ),
      ),
    );
  }
}
