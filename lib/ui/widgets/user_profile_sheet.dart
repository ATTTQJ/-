import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/user_provider.dart';
import 'dialog_utils.dart';

class UserProfileSheet extends StatelessWidget {
  const UserProfileSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, child) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _AvatarButton(userProvider: userProvider),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _displayName(userProvider),
                        style: const TextStyle(
                          color: DialogUtils.titleColor,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _phoneText(userProvider),
                        style: const TextStyle(
                          color: DialogUtils.mutedColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _InfoTile(label: '学校', value: _fallback(userProvider.schoolName)),
            _InfoTile(label: '校区', value: _fallback(userProvider.campusName)),
            _InfoTile(label: '楼栋', value: _fallback(userProvider.buildingName)),
            _InfoTile(label: '楼层 / 房间', value: _floorAndRoom(userProvider)),
            _InfoTile(
              label: '详细地址',
              value: _fallback(userProvider.addressInfo),
            ),
            _InfoTile(label: '学号', value: _fallback(userProvider.studentNo)),
            _InfoTile(label: '年级', value: _fallback(userProvider.grade)),
            _InfoTile(
              label: '实名认证',
              value: userProvider.isRealName ? '已实名' : '未实名',
              isLast: true,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      '关闭',
                      style: TextStyle(
                        color: DialogUtils.mutedColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      context.read<UserProvider>().logout();
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: DialogUtils.primaryColor,
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      '退出登录',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  static String _displayName(UserProvider userProvider) {
    final name = userProvider.userName.trim();
    if (name.isEmpty || name == 'User') {
      return '同学';
    }
    return '$name同学';
  }

  static String _phoneText(UserProvider userProvider) {
    final masked = userProvider.maskedPhone.trim();
    if (masked.isNotEmpty) {
      return masked;
    }
    final phone = userProvider.userPhone.trim();
    if (phone.isNotEmpty) {
      return phone;
    }
    return '未获取手机号';
  }

  static String _floorAndRoom(UserProvider userProvider) {
    final floor = userProvider.floorName.trim();
    final room = userProvider.roomName.trim();
    if (floor.isEmpty && room.isEmpty) {
      return '未获取';
    }
    if (floor.isEmpty) {
      return room;
    }
    if (room.isEmpty) {
      return floor;
    }
    return '$floor / $room';
  }

  static String _fallback(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? '未获取' : trimmed;
  }
}

class _AvatarButton extends StatelessWidget {
  const _AvatarButton({required this.userProvider});

  final UserProvider userProvider;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 76,
      height: 76,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: DialogUtils.borderColor),
        ),
        child: ClipOval(
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: DialogUtils.surfaceBackgroundColor,
            ),
            child: _buildAvatarImage(),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarImage() {
    final avatarUrl = userProvider.avatarUrl.trim();
    if (avatarUrl.isEmpty) {
      return const Center(
        child: Icon(
          Icons.person_rounded,
          color: DialogUtils.mutedColor,
          size: 34,
        ),
      );
    }

    return Image.network(
      avatarUrl,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return const Center(
          child: Icon(
            Icons.person_rounded,
            color: DialogUtils.mutedColor,
            size: 34,
          ),
        );
      },
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          return child;
        }
        return const Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        );
      },
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: DialogUtils.borderColor)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 78,
            child: Text(
              label,
              style: const TextStyle(
                color: DialogUtils.mutedColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: DialogUtils.titleColor,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
