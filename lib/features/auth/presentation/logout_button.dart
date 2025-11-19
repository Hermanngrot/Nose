import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/auth_controller.dart';

class LogoutButton extends StatelessWidget {
  const LogoutButton({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthController>(context);
    if (auth.isLoggedIn) {
      final username = auth.username ?? 'You';
      return Padding(
        padding: const EdgeInsets.only(right: 8.0),
        child: PopupMenuButton<int>(
          tooltip: 'Account',
          offset: const Offset(0, 48),
          itemBuilder: (_) => [
            const PopupMenuItem<int>(value: 1, child: Text('Logout')),
          ],
          onSelected: (v) async {
            if (v == 1) {
              await auth.logout();
              if (!context.mounted) return;
              Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
            }
          },
          child: Row(
            children: [
              // small active dot + avatar
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircleAvatar(radius: 14, backgroundColor: Theme.of(context).primaryColor, child: Text(username.isNotEmpty ? username[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white))),
                    Positioned(
                      right: 2,
                      bottom: 2,
                      child: Container(width: 10, height: 10, decoration: BoxDecoration(color: Colors.green, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5))),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 120),
                child: Text(username, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14)),
              ),
            ],
          ),
        ),
      );
    }

    return IconButton(
      icon: const Icon(Icons.login),
      tooltip: 'Login',
      onPressed: () {
        Navigator.pushNamed(context, '/login');
      },
    );
  }
}
