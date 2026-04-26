import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/toast_service.dart';
import '../../providers/device_provider.dart';
import '../../providers/user_provider.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _telCtrl = TextEditingController();
  final TextEditingController _codeCtrl = TextEditingController();

  Timer? _countdownTimer;
  int _secondsLeft = 0;

  bool get _isCountingDown => _secondsLeft > 0;

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _telCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSendCode(UserProvider userP) async {
    final tel = _telCtrl.text.trim();
    if (tel.length != 11) {
      ToastService.show('请输入11位手机号');
      return;
    }

    final ok = await userP.sendCode(tel);
    if (!mounted) {
      return;
    }
    if (ok) {
      _startCountdown();
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    setState(() {
      _secondsLeft = 60;
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsLeft <= 1) {
        timer.cancel();
        setState(() {
          _secondsLeft = 0;
        });
        return;
      }
      setState(() {
        _secondsLeft -= 1;
      });
    });
  }

  Future<void> _handleLogin(UserProvider userP) async {
    final tel = _telCtrl.text.trim();
    final code = _codeCtrl.text.trim();
    if (tel.length != 11) {
      ToastService.show('请输入11位手机号');
      return;
    }
    if (code.isEmpty) {
      ToastService.show('请输入验证码');
      return;
    }

    final ok = await userP.login(tel, code);
    if (ok) {
      if (mounted) {
        await context.read<DeviceProvider>().loadFromLocal(
          userP.token,
          userP.userId,
        );
      }
      ToastService.show('欢迎回来');
    }
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    final userP = context.watch<UserProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF0E0E11),
      body: Stack(
        children: [
          const Positioned.fill(child: _LoginBackdrop()),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 24,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1C23).withOpacity(0.9),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.08),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.28),
                          blurRadius: 30,
                          offset: const Offset(0, 18),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'WELCOME',
                          style: TextStyle(
                            color: Color(0xFF32D7D2),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2.8,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          '登录账号',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '输入手机号和验证码，继续进入你的用水控制台。',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.64),
                            fontSize: 14,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 28),
                        _LoginField(
                          controller: _telCtrl,
                          hintText: '手机号',
                          keyboardType: TextInputType.phone,
                          prefixIcon: Icons.phone_iphone_rounded,
                        ),
                        const SizedBox(height: 14),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _LoginField(
                                controller: _codeCtrl,
                                hintText: '验证码',
                                keyboardType: TextInputType.number,
                                prefixIcon: Icons.password_rounded,
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              height: 58,
                              child: TextButton(
                                onPressed: userP.isRequesting || _isCountingDown
                                    ? null
                                    : () => _handleSendCode(userP),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  backgroundColor: _isCountingDown
                                      ? Colors.white.withOpacity(0.06)
                                      : const Color(0xFF232634),
                                  disabledBackgroundColor: Colors.white
                                      .withOpacity(0.06),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                    side: BorderSide(
                                      color: _isCountingDown
                                          ? Colors.white.withOpacity(0.06)
                                          : const Color(
                                              0xFF32D7D2,
                                            ).withOpacity(0.32),
                                    ),
                                  ),
                                ),
                                child: Text(
                                  userP.isRequesting
                                      ? '发送中...'
                                      : _isCountingDown
                                      ? '${_secondsLeft}s'
                                      : '发送验证码',
                                  style: TextStyle(
                                    color: _isCountingDown
                                        ? Colors.white54
                                        : const Color(0xFF32D7D2),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: userP.isRequesting
                                ? null
                                : () => _handleLogin(userP),
                            style: ElevatedButton.styleFrom(
                              elevation: 0,
                              backgroundColor: const Color(0xFF7A58FF),
                              disabledBackgroundColor: const Color(
                                0xFF7A58FF,
                              ).withOpacity(0.45),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            child: Text(
                              userP.isRequesting ? '登录中...' : '登录',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginField extends StatelessWidget {
  const _LoginField({
    required this.controller,
    required this.hintText,
    required this.prefixIcon,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String hintText;
  final IconData prefixIcon;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 15,
        fontWeight: FontWeight.w500,
      ),
      cursorColor: const Color(0xFF32D7D2),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(
          color: Colors.white.withOpacity(0.34),
          fontSize: 15,
        ),
        prefixIcon: Icon(
          prefixIcon,
          color: Colors.white.withOpacity(0.62),
          size: 20,
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.06),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFF32D7D2)),
        ),
      ),
    );
  }
}

class _LoginBackdrop extends StatelessWidget {
  const _LoginBackdrop();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(color: const Color(0xFF111217)),
        Positioned(
          left: 14,
          right: 14,
          top: -80,
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
            child: Container(
              height: 306,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x6091EA94),
                    Color(0x5070AF56),
                    Color(0x30B46B6C),
                  ],
                  stops: [0.02, 0.58, 0.87],
                ),
                borderRadius: BorderRadius.all(Radius.elliptical(180, 130)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
