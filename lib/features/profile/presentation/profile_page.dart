import 'package:flutter/material.dart';

import '../../auth/presentation/logout_button.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile'), actions: const [LogoutButton()]),
      body: const Center(child: Text('Profile placeholder')),
    );
  }
}
