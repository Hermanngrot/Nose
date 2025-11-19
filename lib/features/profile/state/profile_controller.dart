import 'package:flutter/material.dart';

import '../../../core/services/user_service.dart';

class ProfileController extends ChangeNotifier {
  final UserService _service = UserService();
  bool loading = false;
  Map<String, dynamic>? profile;
  String? error;

  Future<void> loadProfile() async {
    loading = true; error = null; notifyListeners();
    try {
      profile = await _service.getMe();
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false; notifyListeners();
    }
  }
}
