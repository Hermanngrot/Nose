import 'package:flutter/material.dart';

import '../../auth/presentation/logout_button.dart';

class LeaderboardPage extends StatelessWidget {
  const LeaderboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Leaderboard'), actions: const [LogoutButton()]),
      body: const Center(child: Text('Leaderboard placeholder')),
    );
  }
}
