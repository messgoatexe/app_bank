import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  UserModel? _user;

  UserModel? get user => _user;
  bool get isAuthenticated => _user != null;

  Future<bool> signIn(String email, String password) async {
    final u = await AuthService.instance.signIn(email: email, password: password);
    if (u != null) {
      _user = u;
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<bool> signUp(String email, String password, {String? displayName}) async {
    final u = await AuthService.instance.signUp(email: email, password: password, displayName: displayName);
    if (u != null) {
      _user = u;
      notifyListeners();
      return true;
    }
    return false;
  }

  void signOut() {
    _user = null;
    notifyListeners();
  }

  Future<bool> updateProfile({String? displayName}) async {
    if (_user == null) return false;
    final ok = await AuthService.instance.updateProfile(id: _user!.id, displayName: displayName);
    if (ok) {
      _user = UserModel(
        id: _user!.id,
        email: _user!.email,
        hashedPassword: _user!.hashedPassword,
        displayName: displayName,
      );
      notifyListeners();
    }
    return ok;
  }
}
