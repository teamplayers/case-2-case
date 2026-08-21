import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';

class AuthState extends ChangeNotifier {
  AuthState(this.api);

  final Api api;
  Map<String, dynamic>? user;
  bool loading = true;

  bool get isLoggedIn => user != null;
  bool get mustChange => user?['mustChangePassword'] == true;
  String get username => user?['username'] as String? ?? '';
  String get name => user?['name'] as String? ?? '';
  String get email => user?['email'] as String? ?? '';
  String get id => user?['id'] as String? ?? '';
  String? get appRole => user?['appRole'] as String?;
  String get status => user?['status'] as String? ?? '';
  bool get isDuperAdmin => appRole == 'duperadmin';
  bool get isSuperAdmin => appRole == 'duperadmin' || appRole == 'superadmin';
  bool get isAppOperator => isSuperAdmin;

  // Legacy helpers used across screens
  bool get isAdmin => isAppOperator;
  bool get isStaff => isAppOperator;

  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    api.token = prefs.getString('c2c_token');
    if (api.token == null) {
      loading = false;
      notifyListeners();
      return;
    }
    try {
      user = Map<String, dynamic>.from(await api.get('/api/auth/me'));
    } catch (_) {
      api.token = null;
      await prefs.remove('c2c_token');
      user = null;
    }
    loading = false;
    notifyListeners();
  }

  Future<void> _store(Map<String, dynamic> payload) async {
    api.token = payload['token'] as String;
    user = Map<String, dynamic>.from(payload['user'] as Map);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('c2c_token', api.token!);
    notifyListeners();
  }

  Future<void> login(String username, String password) async {
    await _store(await api.post('/api/auth/login', {'username': username, 'password': password}));
  }

  Future<Map<String, dynamic>> register({
    required String username,
    required String name,
    required String email,
    required String password,
  }) async {
    return Map<String, dynamic>.from(await api.post('/api/auth/register', {
      'username': username,
      'name': name,
      'email': email,
      'password': password,
    }));
  }

  Future<void> changePassword(String current, String next) async {
    await api.post('/api/auth/change-password', {
      'current_password': current,
      'new_password': next,
    });
    if (user != null) {
      user = {...user!, 'mustChangePassword': false};
      notifyListeners();
    }
  }

  Future<void> logout() async {
    try {
      await api.post('/api/auth/logout');
    } catch (_) {}
    api.token = null;
    user = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('c2c_token');
    notifyListeners();
  }
}
