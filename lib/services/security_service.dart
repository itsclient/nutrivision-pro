import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:local_auth/local_auth.dart';
import 'api_config.dart';
import 'auth_service.dart';

class SecurityService {
  static final SecurityService instance = SecurityService._init();
  SecurityService._init();

  static const String _encryptionKeyKey = 'encryption_key';
  static const String _twoFactorEnabledKey = 'two_factor_enabled';
  static const String _biometricEnabledKey = 'biometric_enabled';
  static const String _sessionTimeoutKey = 'session_timeout';
  static const String _failedAttemptsKey = 'failed_attempts';
  static const String _lockoutUntilKey = 'lockout_until';

  String? _encryptionKey;
  bool _twoFactorEnabled = false;
  bool _biometricEnabled = false;
  Duration _sessionTimeout = const Duration(hours: 24);
  int _failedAttempts = 0;
  DateTime? _lockoutUntil;
  DateTime? _lastActivity;

  // Getters
  bool get twoFactorEnabled => _twoFactorEnabled;
  bool get biometricEnabled => _biometricEnabled;
  Duration get sessionTimeout => _sessionTimeout;
  int get failedAttempts => _failedAttempts;
  DateTime? get lockoutUntil => _lockoutUntil;
  bool get isLockedOut => _lockoutUntil != null && DateTime.now().isBefore(_lockoutUntil!);

  // Initialize security service
  Future<void> initialize() async {
    await _loadSecuritySettings();
    await _initializeEncryption();
    await _checkBiometricAvailability();
    _lastActivity = DateTime.now();
  }

  // Load security settings
  Future<void> _loadSecuritySettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    _twoFactorEnabled = prefs.getBool(_twoFactorEnabledKey) ?? false;
    _biometricEnabled = prefs.getBool(_biometricEnabledKey) ?? false;
    
    final timeoutMinutes = prefs.getInt(_sessionTimeoutKey) ?? 1440; // 24 hours default
    _sessionTimeout = Duration(minutes: timeoutMinutes);
    
    _failedAttempts = prefs.getInt(_failedAttemptsKey) ?? 0;
    
    final lockoutTimestamp = prefs.getString(_lockoutUntilKey);
    if (lockoutTimestamp != null) {
      _lockoutUntil = DateTime.parse(lockoutTimestamp);
    }
  }

  // Save security settings
  Future<void> _saveSecuritySettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.setBool(_twoFactorEnabledKey, _twoFactorEnabled);
    await prefs.setBool(_biometricEnabledKey, _biometricEnabled);
    await prefs.setInt(_sessionTimeoutKey, _sessionTimeout.inMinutes);
    await prefs.setInt(_failedAttemptsKey, _failedAttempts);
    await prefs.setString(_lockoutUntilKey, _lockoutUntil?.toIso8601String() ?? '');
  }

  // Initialize encryption
  Future<void> _initializeEncryption() async {
    final prefs = await SharedPreferences.getInstance();
    final storedKey = prefs.getString(_encryptionKeyKey);
    
    if (storedKey != null) {
      _encryptionKey = storedKey;
    } else {
      // Generate new encryption key
      _encryptionKey = _generateEncryptionKey();
      await prefs.setString(_encryptionKeyKey, _encryptionKey!);
    }
  }

  // Generate encryption key
  String _generateEncryptionKey() {
    final key = Key.fromSecureRandom(32);
    return key.base64;
  }

  // Check biometric availability
  Future<void> _checkBiometricAvailability() async {
    try {
      final LocalAuthentication localAuth = LocalAuthentication();
      final isAvailable = await localAuth.canCheckBiometrics;
      
      if (!isAvailable) {
        _biometricEnabled = false;
        await _saveSecuritySettings();
      }
    } catch (e) {
      print('Error checking biometric availability: $e');
      _biometricEnabled = false;
    }
  }

  // Enable/disable 2FA
  Future<bool> toggleTwoFactorAuth(bool enable) async {
    try {
      final currentUser = AuthService.instance.currentUser;
      if (currentUser == null) return false;

      if (enable) {
        // Generate and send 2FA secret
        final secret = _generateTwoFactorSecret();
        final success = await _enableTwoFactorOnBackend(currentUser.email, secret);
        
        if (success) {
          _twoFactorEnabled = true;
          await _saveSecuritySettings();
          return true;
        }
      } else {
        // Disable 2FA
        final success = await _disableTwoFactorOnBackend(currentUser.email);
        
        if (success) {
          _twoFactorEnabled = false;
          await _saveSecuritySettings();
          return true;
        }
      }
    } catch (e) {
      print('Error toggling 2FA: $e');
    }
    return false;
  }

  // Generate 2FA secret
  String _generateTwoFactorSecret() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64Encode(bytes);
  }

  // Enable 2FA on backend
  Future<bool> _enableTwoFactorOnBackend(String email, String secret) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/security/enable-2fa'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'secret': secret,
        }),
      );
      
      return response.statusCode == 200;
    } catch (e) {
      print('Error enabling 2FA on backend: $e');
      return false;
    }
  }

  // Disable 2FA on backend
  Future<bool> _disableTwoFactorOnBackend(String email) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/security/disable-2fa'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );
      
      return response.statusCode == 200;
    } catch (e) {
      print('Error disabling 2FA on backend: $e');
      return false;
    }
  }

  // Verify 2FA code
  Future<bool> verifyTwoFactorCode(String code) async {
    try {
      final currentUser = AuthService.instance.currentUser;
      if (currentUser == null) return false;

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/security/verify-2fa'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': currentUser.email,
          'code': code,
        }),
      );
      
      return response.statusCode == 200;
    } catch (e) {
      print('Error verifying 2FA code: $e');
      return false;
    }
  }

  // Enable/disable biometric authentication
  Future<bool> toggleBiometricAuth(bool enable) async {
    try {
      final LocalAuthentication localAuth = LocalAuthentication();
      
      if (enable) {
        // Test biometric availability
        final canCheckBiometrics = await localAuth.canCheckBiometrics;
        if (!canCheckBiometrics) return false;
        
        // Authenticate with biometrics
        final authenticated = await localAuth.authenticate(
          localizedReason: 'Enable biometric authentication',
          options: const AuthenticationOptions(
            biometricOnly: true,
            stickyAuth: true,
          ),
        );
        
        if (authenticated) {
          _biometricEnabled = true;
          await _saveSecuritySettings();
          return true;
        }
      } else {
        _biometricEnabled = false;
        await _saveSecuritySettings();
        return true;
      }
    } catch (e) {
      print('Error toggling biometric auth: $e');
    }
    return false;
  }

  // Authenticate with biometrics
  Future<bool> authenticateWithBiometrics({String? reason}) async {
    if (!_biometricEnabled) return false;
    
    try {
      final LocalAuthentication localAuth = LocalAuthentication();
      
      final authenticated = await localAuth.authenticate(
        localizedReason: reason ?? 'Authenticate to continue',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
      
      if (authenticated) {
        _updateLastActivity();
        return true;
      }
    } catch (e) {
      print('Biometric authentication failed: $e');
    }
    return false;
  }

  // Encrypt data
  String encrypt(String plainText) {
    if (_encryptionKey == null) return plainText;
    
    try {
      final key = Key.fromBase64(_encryptionKey!);
      final iv = IV.fromLength(16);
      final encrypter = Encrypter(AES(key));
      
      final encrypted = encrypter.encrypt(plainText, iv: iv);
      return encrypted.base64 + ':' + iv.base64;
    } catch (e) {
      print('Error encrypting data: $e');
      return plainText;
    }
  }

  // Decrypt data
  String decrypt(String encryptedText) {
    if (_encryptionKey == null) return encryptedText;
    
    try {
      final parts = encryptedText.split(':');
      if (parts.length != 2) return encryptedText;
      
      final key = Key.fromBase64(_encryptionKey!);
      final iv = IV.fromBase64(parts[1]);
      final encrypter = Encrypter(AES(key));
      
      final decrypted = encrypter.decrypt64(parts[0], iv: iv);
      return decrypted;
    } catch (e) {
      print('Error decrypting data: $e');
      return encryptedText;
    }
  }

  // Hash password
  String hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Verify password
  bool verifyPassword(String password, String hashedPassword) {
    return hashPassword(password) == hashedPassword;
  }

  // Record failed login attempt
  Future<void> recordFailedAttempt() async {
    _failedAttempts++;
    
    // Lock account after 5 failed attempts
    if (_failedAttempts >= 5) {
      _lockoutUntil = DateTime.now().add(const Duration(minutes: 30));
    }
    
    await _saveSecuritySettings();
  }

  // Reset failed attempts
  Future<void> resetFailedAttempts() async {
    _failedAttempts = 0;
    _lockoutUntil = null;
    await _saveSecuritySettings();
  }

  // Update session timeout
  Future<void> updateSessionTimeout(Duration timeout) async {
    _sessionTimeout = timeout;
    await _saveSecuritySettings();
  }

  // Update last activity
  void _updateLastActivity() {
    _lastActivity = DateTime.now();
  }

  // Check if session is valid
  bool isSessionValid() {
    if (_lastActivity == null) return false;
    
    final elapsed = DateTime.now().difference(_lastActivity!);
    return elapsed < _sessionTimeout;
  }

  // Invalidate session
  void invalidateSession() {
    _lastActivity = null;
  }

  // Generate secure random token
  String generateSecureToken({int length = 32}) {
    final random = Random.secure();
    final bytes = List<int>.generate(length, (_) => random.nextInt(256));
    return base64Url.encode(bytes);
  }

  // Validate password strength
  PasswordStrength validatePasswordStrength(String password) {
    int score = 0;
    List<String> suggestions = [];

    // Length check
    if (password.length >= 8) {
      score += 1;
    } else {
      suggestions.add('Use at least 8 characters');
    }

    // Uppercase check
    if (password.contains(RegExp(r'[A-Z]'))) {
      score += 1;
    } else {
      suggestions.add('Include uppercase letters');
    }

    // Lowercase check
    if (password.contains(RegExp(r'[a-z]'))) {
      score += 1;
    } else {
      suggestions.add('Include lowercase letters');
    }

    // Numbers check
    if (password.contains(RegExp(r'[0-9]'))) {
      score += 1;
    } else {
      suggestions.add('Include numbers');
    }

    // Special characters check
    if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      score += 1;
    } else {
      suggestions.add('Include special characters');
    }

    // Common patterns check
    if (password.contains(RegExp(r'123|abc|password|qwerty', caseInsensitive: true))) {
      score -= 1;
      suggestions.add('Avoid common patterns');
    }

    // Determine strength
    PasswordStrength strength;
    if (score >= 4) {
      strength = PasswordStrength.strong;
    } else if (score >= 2) {
      strength = PasswordStrength.medium;
    } else {
      strength = PasswordStrength.weak;
    }

    return PasswordStrength(
      strength: strength,
      score: score,
      suggestions: suggestions,
    );
  }

  // Get security audit
  Map<String, dynamic> getSecurityAudit() {
    return {
      'two_factor_enabled': _twoFactorEnabled,
      'biometric_enabled': _biometricEnabled,
      'session_timeout_minutes': _sessionTimeout.inMinutes,
      'failed_attempts': _failedAttempts,
      'is_locked_out': isLockedOut,
      'lockout_remaining_minutes': _lockoutUntil != null 
          ? _lockoutUntil!.difference(DateTime.now()).inMinutes 
          : 0,
      'session_valid': isSessionValid(),
      'encryption_enabled': _encryptionKey != null,
      'last_activity': _lastActivity?.toIso8601String(),
    };
  }

  // Export encrypted data
  Future<String> exportEncryptedData(Map<String, dynamic> data) async {
    final jsonData = jsonEncode(data);
    return encrypt(jsonData);
  }

  // Import encrypted data
  Future<Map<String, dynamic>?> importEncryptedData(String encryptedData) async {
    try {
      final decrypted = decrypt(encryptedData);
      return jsonDecode(decrypted) as Map<String, dynamic>;
    } catch (e) {
      print('Error importing encrypted data: $e');
      return null;
    }
  }

  // Clear all security data
  Future<void> clearSecurityData() async {
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.remove(_encryptionKeyKey);
    await prefs.remove(_twoFactorEnabledKey);
    await prefs.remove(_biometricEnabledKey);
    await prefs.remove(_sessionTimeoutKey);
    await prefs.remove(_failedAttemptsKey);
    await prefs.remove(_lockoutUntilKey);
    
    _encryptionKey = null;
    _twoFactorEnabled = false;
    _biometricEnabled = false;
    _failedAttempts = 0;
    _lockoutUntil = null;
    _lastActivity = null;
  }
}

// Data models
class PasswordStrength {
  final PasswordStrengthLevel strength;
  final int score;
  final List<String> suggestions;

  PasswordStrength({
    required this.strength,
    required this.score,
    required this.suggestions,
  });
}

enum PasswordStrengthLevel {
  weak,
  medium,
  strong,
}

class SecurityEvent {
  final String type;
  final String description;
  final DateTime timestamp;
  final String? ipAddress;
  final String? userAgent;

  SecurityEvent({
    required this.type,
    required this.description,
    required this.timestamp,
    this.ipAddress,
    this.userAgent,
  });

  factory SecurityEvent.fromJson(Map<String, dynamic> json) {
    return SecurityEvent(
      type: json['type'] ?? '',
      description: json['description'] ?? '',
      timestamp: DateTime.parse(json['timestamp']),
      ipAddress: json['ipAddress'],
      userAgent: json['userAgent'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'description': description,
      'timestamp': timestamp.toIso8601String(),
      'ipAddress': ipAddress,
      'userAgent': userAgent,
    };
  }
}
