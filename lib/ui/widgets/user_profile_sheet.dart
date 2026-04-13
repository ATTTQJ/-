import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/user_provider.dart';

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
            Center(
              child: _AvatarButton(userProvider: userProvider),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                _displayName(userProvider),
                style: const TextStyle(
                  color: Color(0xFF1F232B),
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: Text(
                _phoneText(userProvider),
                style: const TextStyle(
                  color: Color(0xFF7B8190),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: Text(
                userProvider.isUploadingAvatar ? '头像上传中...' : '点击头像更换',
                style: const TextStyle(
                  color: Color(0xFF9AA1B1),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 24),
            _InfoTile(
              label: '学校',
              value: _fallback(userProvider.schoolName),
            ),
            _InfoTile(
              label: '校区',
              value: _fallback(userProvider.campusName),
            ),
            _InfoTile(
              label: '楼栋',
              value: _fallback(userProvider.buildingName),
            ),
            _InfoTile(
              label: '楼层 / 房间',
              value: _floorAndRoom(userProvider),
            ),
            _InfoTile(
              label: '详细地址',
              value: _fallback(userProvider.addressInfo),
            ),
            _InfoTile(
              label: '学号',
              value: _fallback(userProvider.studentNo),
            ),
            _InfoTile(
              label: '年级',
              value: _fallback(userProvider.grade),
            ),
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
                        color: Color(0xFF7B8190),
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
                      backgroundColor: const Color(0xFF1F232B),
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
    return '${name}同学';
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
    return GestureDetector(
      onTap: userProvider.isUploadingAvatar
          ? null
          : () => userProvider.pickAndUploadAvatar(),
      child: SizedBox(
        width: 108,
        height: 108,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF1F232B).withOpacity(0.08),
                ),
              ),
              child: ClipOval(
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    color: Color(0xFFE9EDF4),
                  ),
                  child: _buildAvatarImage(),
                ),
              ),
            ),
            Positioned(
              right: 2,
              bottom: 12,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: const Color(0xFF1F232B),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: userProvider.isUploadingAvatar
                    ? const Padding(
                        padding: EdgeInsets.all(7),
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Icon(
                        Icons.photo_camera_outlined,
                        color: Colors.white,
                        size: 16,
                      ),
              ),
            ),
          ],
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
          color: Color(0xFF7B8190),
          size: 44,
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
            color: Color(0xFF7B8190),
            size: 44,
          ),
        );
      },
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          return child;
        }
        return const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.2),
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
            : const Border(
                bottom: BorderSide(
                  color: Color(0x11000000),
                ),
              ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 78,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF8C92A2),
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
                color: Color(0xFF1F232B),
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
