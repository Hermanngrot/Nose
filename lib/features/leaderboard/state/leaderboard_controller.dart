import 'package:flutter/material.dart';

import '../../../core/models/leaderboard_entry_dto.dart';
import '../../../core/services/user_service.dart';

class LeaderboardController extends ChangeNotifier {
  final UserService _service = UserService();
  bool loading = false;
  List<LeaderboardEntryDto> entries = [];
  String? error;

  Future<void> loadLeaderboard() async {
    loading = true; error = null; notifyListeners();
    try {
      entries = await _service.getLeaderboard();
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false; notifyListeners();
    }
  }
}
