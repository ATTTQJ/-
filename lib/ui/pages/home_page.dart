import 'package:flutter/material.dart';
import '../widgets/user_info_panel.dart';
import '../widgets/device_card.dart';
import '../widgets/bottom_action_panel.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    SizedBox(height: 40),
                    UserInfoPanel(),
                    SizedBox(height: 30),
                    DeviceCard(),
                    SizedBox(height: 20),
                  ],
                ),
              )
            ),
            const BottomActionPanel(),
            const SizedBox(height: 30)
          ]
        )
      )
    );
  }
}