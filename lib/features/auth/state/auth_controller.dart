import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/models/auth_response_dto.dart';

class AuthController extends ChangeNotifier {
  final AuthService _service = AuthService();

  bool _loading = false;
  String? _token;
  String? _username;
  String? _userId;
  String? error;

  bool get loading => _loading;
  String? get token => _token;
  String? get username => _username;
  String? get userId => _userId;
  bool get isLoggedIn => _token != null && _token!.isNotEmpty;

  AuthController() {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
    _username = prefs.getString('username');
    _userId = prefs.getString('userId');
    notifyListeners();
  }

  Future<bool> login(String username, String password) async {
    _loading = true; error = null; notifyListeners();
    try {
      final resp = await _service.login(username, password);
      final dto = AuthResponseDto.fromJson(resp);
      _token = dto.token;
      _username = dto.username;
      _userId = dto.userId;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', _token ?? '');
      await prefs.setString('username', _username ?? '');
      await prefs.setString('userId', _userId ?? '');
      _loading = false; notifyListeners();
      return true;
    } catch (e) {
      error = e.toString();
      _loading = false; notifyListeners();
      return false;
    }
  }

  Future<bool> register(String username, String email, String password) async {
    _loading = true; error = null; notifyListeners();
    try {
      final resp = await _service.register(username, email, password);
      final dto = AuthResponseDto.fromJson(resp);
      _token = dto.token;
      _username = dto.username;
      _userId = dto.userId;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', _token ?? '');
      await prefs.setString('username', _username ?? '');
      await prefs.setString('userId', _userId ?? '');
      _loading = false; notifyListeners();
      return true;
    } catch (e) {
      error = e.toString();
      _loading = false; notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('username');
    await prefs.remove('userId');
    _token = null; _username = null; _userId = null; notifyListeners();
  }
}
