import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';

class SecureStorageService {
  static final SecureStorageService instance = SecureStorageService._init();
  
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );
  
  final LocalAuthentication _localAuth = LocalAuthentication();

  SecureStorageService._init();

  // Check if biometric authentication is available
  Future<bool> isBiometricAvailable() async {
    try {
      return await _localAuth.canCheckBiometrics;
    } catch (e) {
      print('Error checking biometric availability: $e');
      return false;
    }
  }

  // Get available biometric types
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      print('Error getting available biometrics: $e');
      return [];
    }
  }

  // Authenticate with biometrics or device credentials
  Future<bool> authenticate({String reason = 'Please authenticate to access secure notes'}) async {
    try {
      return await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false, // Allow PIN/pattern fallback
        ),
      );
    } on PlatformException catch (e) {
      print('Authentication error: $e');
      return false;
    }
  }

  // Store encrypted note content
  Future<void> storeSecureNote(String noteId, String content) async {
    try {
      await _storage.write(
        key: 'secure_note_$noteId',
        value: content,
      );
    } catch (e) {
      print('Error storing secure note: $e');
      rethrow;
    }
  }

  // Retrieve encrypted note content
  Future<String?> getSecureNote(String noteId) async {
    try {
      return await _storage.read(key: 'secure_note_$noteId');
    } catch (e) {
      print('Error reading secure note: $e');
      return null;
    }
  }

  // Delete encrypted note content
  Future<void> deleteSecureNote(String noteId) async {
    try {
      await _storage.delete(key: 'secure_note_$noteId');
    } catch (e) {
      print('Error deleting secure note: $e');
    }
  }

  // Check if secure vault has been set up
  Future<bool> isVaultSetup() async {
    try {
      final setup = await _storage.read(key: 'vault_setup');
      return setup == 'true';
    } catch (e) {
      return false;
    }
  }

  // Mark vault as set up
  Future<void> setupVault() async {
    await _storage.write(key: 'vault_setup', value: 'true');
  }

  // Clear all secure storage (use with caution!)
  Future<void> clearAllSecureData() async {
    try {
      await _storage.deleteAll();
    } catch (e) {
      print('Error clearing secure data: $e');
    }
  }

  // Store last access time for auto-lock
  Future<void> updateLastAccessTime() async {
    await _storage.write(
      key: 'last_vault_access',
      value: DateTime.now().millisecondsSinceEpoch.toString(),
    );
  }

  // Get last access time
  Future<DateTime?> getLastAccessTime() async {
    try {
      final timestamp = await _storage.read(key: 'last_vault_access');
      if (timestamp != null) {
        return DateTime.fromMillisecondsSinceEpoch(int.parse(timestamp));
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Check if vault should be locked (5 minutes timeout)
  Future<bool> shouldLock() async {
    final lastAccess = await getLastAccessTime();
    if (lastAccess == null) return true;
    
    final diff = DateTime.now().difference(lastAccess);
    return diff.inMinutes >= 5; // Auto-lock after 5 minutes
  }
}
