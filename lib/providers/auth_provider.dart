import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../services/api_service.dart';

enum AuthStatus { initial, loading, authenticated, error }

class AuthProvider extends ChangeNotifier {
  AuthStatus _status = AuthStatus.initial;
  String? _token;
  AppUser? _user;
  String? _errorMessage;

  AuthStatus get status => _status;
  String? get token => _token;
  AppUser? get user => _user;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  Future<void> login(String username, String password) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      _token = await ApiService.login(username, password);
      debugPrint('Token received: $_token');

      _user = await ApiService.getUser(1);
      debugPrint('User fetched: ${_user?.username}');

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', _token!);

      _status = AuthStatus.authenticated;
    } catch (e) {
      debugPrint('Login error: $e');
      _errorMessage = e.toString();
      _status = AuthStatus.error;
    }
    notifyListeners();
  }

  Future<void> tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final savedToken = prefs.getString('token');
    if (savedToken != null) {
      _token = savedToken;
      try {
        _user = await ApiService.getUser(1);
        _status = AuthStatus.authenticated;
      } catch (e) {
        debugPrint('Auto-login error: $e');
        await prefs.remove('token');
        _status = AuthStatus.initial;
      }
      notifyListeners();
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    _token = null;
    _user = null;
    _status = AuthStatus.initial;
    notifyListeners();
  }
}