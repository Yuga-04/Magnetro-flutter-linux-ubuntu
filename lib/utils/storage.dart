import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class Storage {
  static const _store = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static Future<void> saveCreds(String email, String password) async {
    await _store.write(key: 'seedr_email', value: email);
    await _store.write(key: 'seedr_password', value: password);
  }

  static Future<(String?, String?)> getCreds() async {
    final email = await _store.read(key: 'seedr_email');
    final password = await _store.read(key: 'seedr_password');
    return (email, password);
  }

  static Future<void> clearCreds() async {
    await _store.delete(key: 'seedr_email');
    await _store.delete(key: 'seedr_password');
  }
}