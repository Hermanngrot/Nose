import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/auth_controller.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _usernameCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthController>(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Color(0xFF1E3C72), Color(0xFF2A5298)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircleAvatar(
                        radius: 36,
                        backgroundColor: Color(0xFF50E3C2),
                        child: Icon(Icons.school, size: 36, color: Colors.white),
                      ),
                      const SizedBox(height: 12),
                      Text('Profesores y Matones', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 8),
                      Text('Sign in to continue', style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _usernameCtrl,
                        decoration: const InputDecoration(prefixIcon: Icon(Icons.person), labelText: 'Username'),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _passwordCtrl,
                        decoration: const InputDecoration(prefixIcon: Icon(Icons.lock), labelText: 'Password'),
                        obscureText: true,
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: auth.loading
                            ? const Center(child: CircularProgressIndicator())
                            : ElevatedButton(
                                onPressed: () async {
                                  final ok = await auth.login(_usernameCtrl.text.trim(), _passwordCtrl.text);
                                  if (ok) {
                                    if (!mounted) return;
                                    Navigator.pushReplacementNamed(context, '/lobby');
                                  } else {
                                    final msg = auth.error ?? 'Login failed';
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                                  }
                                },
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  child: Text('Login', style: TextStyle(fontSize: 16)),
                                ),
                              ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Don\'t have an account? '),
                          TextButton(onPressed: () => Navigator.pushNamed(context, '/register'), child: const Text('Register')),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
