import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../core/toast_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _telCtrl = TextEditingController();
  final TextEditingController _codeCtrl = TextEditingController();

  @override
  void dispose() {
    _telCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userP = context.watch<UserProvider>();

    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("UY Water", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
            const SizedBox(height: 60),
            TextField(
              controller: _telCtrl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                hintText: "手机号", 
                filled: true, 
                fillColor: Colors.grey[100], 
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _codeCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: "验证码", 
                      filled: true, 
                      fillColor: Colors.grey[100], 
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: userP.isRequesting ? null : () => userP.sendCode(_telCtrl.text),
                  child: Text(userP.isRequesting ? "发送中..." : "获取验证码"),
                )
              ],
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1660AB), 
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                ),
                onPressed: userP.isRequesting ? null : () async {
                  bool ok = await userP.login(_telCtrl.text, _codeCtrl.text);
                  if (ok) ToastService.show("欢迎回来");
                },
                child: const Text("登录", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}