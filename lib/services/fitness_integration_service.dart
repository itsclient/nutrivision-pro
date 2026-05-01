import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:health/health.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:fitbit/fitbit.dart';
import 'api_config.dart';
import 'auth_service.dart';

class FitnessIntegrationService {
  static final FitnessIntegrationService instance = FitnessIntegrationService._init();
  FitnessIntegrationService._init();

  static const String _connectedAppsKey = 'connected_fitness_apps';
  static const String _lastSyncKey = 'last_fitness_sync';

  Map<FitnessApp, bool> _connectedApps = {};
  DateTime? _lastSync;
  Health? _health;
  GoogleSignIn? _googleSignIn;

  // Getters
  Map<FitnessApp, bool> get connectedApps => _connectedApps;
  DateTime? get lastSync => _lastSync;

  // Initialize fitness integrations
  Future<void> initialize() async {
    await _loadConnectedApps();
    await _initializeHealthKit();
    await _initializeGoogleFit();
    await _initializeFitbit();
  }

  // Load connected apps
  Future<void> _loadConnectedApps() async {
    final prefs = await SharedPreferences.getInstance();
    final connectedJson = prefs.getString(_connectedAppsKey);
    
    if (connectedJson != null) {
      final connectedMap = jsonDecode(connectedJson) as Map<String, dynamic>;
      _connectedApps = connectedMap.map((key, value) => 
        MapEntry(FitnessApp.values[int.parse(key)], value as bool));
    }
    
    final lastSyncTimestamp = prefs.getString(_lastSyncKey);
    if (lastSyncTimestamp != null) {
      _lastSync = DateTime.parse(lastSyncTimestamp);
    }
  }

  // Save connected apps
  Future<void> _saveConnectedApps() async {
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.setString(_connectedAppsKey, jsonEncode(
      _connectedApps.map((key, value) => MapEntry(key.index.toString(), value))
    ));
    
    await prefs.setString(_lastSyncKey, _lastSync?.toIso8601String() ?? '');
  }

  // Initialize HealthKit (iOS)
  Future<void> _initializeHealthKit() async {
    try {
      _health = Health();
      await _health!.configure();
    } catch (e) {
      print('HealthKit not available: $e');
    }
  }

  // Initialize Google Fit (Android)
  Future<void> _initializeGoogleFit() async {
    try {
      _googleSignIn = GoogleSignIn(
        scopes: [
          'email',
          'https://www.googleapis.com/auth/fitness.activity.read',
          'https://www.googleapis.com/auth/fitness.body.read',
          'https://www.googleapis.com/auth/fitness.nutrition.read',
        ],
      );
    } catch (e) {
      print('Google Fit not available: $e');
    }
  }

  // Initialize Fitbit
  Future<void> _initializeFitbit() async {
    try {
      // Fitbit initialization would go here
      // This is a placeholder for Fitbit SDK integration
    } catch (e) {
      print('Fitbit not available: $e');
    }
  }

  // Connect to fitness app
  Future<bool> connectFitnessApp(FitnessApp app) async {
    try {
      bool success = false;
      
      switch (app) {
        case FitnessApp.appleHealth:
          success = await _connectAppleHealth();
          break;
        case FitnessApp.googleFit:
          success = await _connectGoogleFit();
          break;
        case FitnessApp.fitbit:
          success = await _connectFitbit();
          break;
        case FitnessApp.garminConnect:
          success = await _connectGarminConnect();
          break;
        case FitnessApp.strava:
          success = await _connectStrava();
          break;
      }
      
      if (success) {
        _connectedApps[app] = true;
        await _saveConnectedApps();
      }
      
      return success;
    } catch (e) {
      print('Error connecting to $app: $e');
      return false;
    }
  }

  // Connect to Apple Health
  Future<bool> _connectAppleHealth() async {
    if (_health == null) return false;
    
    try {
      final types = [
        HealthDataType.STEPS,
        HealthDataType.CALORIES_ACTIVE,
        HealthDataType.WEIGHT,
        HealthDataType.HEIGHT,
        HealthDataType.BODY_FAT_PERCENTAGE,
      ];
      
      final requested = await _health!.requestAuthorization(types);
      
      if (requested) {
        return true;
      }
    } catch (e) {
      print('Error connecting to Apple Health: $e');
    }
    return false;
  }

  // Connect to Google Fit
  Future<bool> _connectGoogleFit() async {
    if (_googleSignIn == null) return false;
    
    try {
      final GoogleSignInAccount? account = await _googleSignIn!.signIn();
      
      if (account != null) {
        // Store Google Fit access token
        return true;
      }
    } catch (e) {
      print('Error connecting to Google Fit: $e');
    }
    return false;
  }

  // Connect to Fitbit
  Future<bool> _connectFitbit() async {
    try {
      // Implement Fitbit OAuth flow
      // This is a placeholder for actual Fitbit integration
      return true;
    } catch (e) {
      print('Error connecting to Fitbit: $e');
      return false;
    }
  }

  // Connect to Garmin Connect
  Future<bool> _connectGarminConnect() async {
    try {
      // Implement Garmin Connect OAuth flow
      // This is a placeholder for actual Garmin integration
      return true;
    } catch (e) {
      print('Error connecting to Garmin Connect: $e');
      return false;
    }
  }

  // Connect to Strava
  Future<bool> _connectStrava() async {
    try {
      // Implement Strava OAuth flow
      // This is a placeholder for actual Strava integration
      return true;
    } catch (e) {
      print('Error connecting to Strava: $e');
      return false;
    }
  }

  // Disconnect from fitness app
  Future<bool> disconnectFitnessApp(FitnessApp app) async {
    try {
      bool success = false;
      
      switch (app) {
        case FitnessApp.appleHealth:
          success = await _disconnectAppleHealth();
          break;
        case FitnessApp.googleFit:
          success = await _disconnectGoogleFit();
          break;
        case FitnessApp.fitbit:
          success = await _disconnectFitbit();
          break;
        case FitnessApp.garminConnect:
          success = await _disconnectGarminConnect();
          break;
        case FitnessApp.strava:
          success = await _disconnectStrava();
          break;
      }
      
      if (success) {
        _connectedApps[app] = false;
        await _saveConnectedApps();
      }
      
      return success;
    } catch (e) {
      print('Error disconnecting from $app: $e');
      return false;
    }
  }

  // Disconnect from Apple Health
  Future<bool> _disconnectAppleHealth() async {
    // Apple Health doesn't have a traditional disconnect
    // Just revoke permissions
    _connectedApps[FitnessApp.appleHealth] = false;
    return true;
  }

  // Disconnect from Google Fit
  Future<bool> _disconnectGoogleFit() async {
    try {
      await _googleSignIn?.disconnect();
      return true;
    } catch (e) {
      print('Error disconnecting from Google Fit: $e');
      return false;
    }
  }

  // Disconnect from Fitbit
  Future<bool> _disconnectFitbit() async {
    // Implement Fitbit token revocation
    return true;
  }

  // Disconnect from Garmin Connect
  Future<bool> _disconnectGarminConnect() async {
    // Implement Garmin Connect token revocation
    return true;
  }

  // Disconnect from Strava
  Future<bool> _disconnectStrava() async {
    // Implement Strava token revocation
    return true;
  }

  // Sync fitness data
  Future<List<FitnessData>> syncFitnessData({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final allData = <FitnessData>[];
    
    final now = DateTime.now();
    final start = startDate ?? now.subtract(const Duration(days: 7));
    final end = endDate ?? now;
    
    for (final app in _connectedApps.keys) {
      if (_connectedApps[app] == true) {
        final data = await _syncFromApp(app, start, end);
        allData.addAll(data);
      }
    }
    
    _lastSync = DateTime.now();
    await _saveConnectedApps();
    
    return allData;
  }

  // Sync from specific app
  Future<List<FitnessData>> _syncFromApp(FitnessApp app, DateTime start, DateTime end) async {
    switch (app) {
      case FitnessApp.appleHealth:
        return await _syncFromAppleHealth(start, end);
      case FitnessApp.googleFit:
        return await _syncFromGoogleFit(start, end);
      case FitnessApp.fitbit:
        return await _syncFromFitbit(start, end);
      case FitnessApp.garminConnect:
        return await _syncFromGarminConnect(start, end);
      case FitnessApp.strava:
        return await _syncFromStrava(start, end);
    }
  }

  // Sync from Apple Health
  Future<List<FitnessData>> _syncFromAppleHealth(DateTime start, DateTime end) async {
    final data = <FitnessData>[];
    
    if (_health == null) return data;
    
    try {
      // Sync steps
      final steps = await _health!.getHealthDataFromTypes(
        types: [HealthDataType.STEPS],
        startDate: start,
        endDate: end,
      );
      
      for (final step in steps) {
        if (step.value != null) {
          data.add(FitnessData(
            type: FitnessDataType.steps,
            value: step.value!.toDouble(),
            unit: 'count',
            timestamp: step.dateFrom,
            source: FitnessApp.appleHealth,
          ));
        }
      }
      
      // Sync calories
      final calories = await _health!.getHealthDataFromTypes(
        types: [HealthDataType.CALORIES_ACTIVE],
        startDate: start,
        endDate: end,
      );
      
      for (final calorie in calories) {
        if (calorie.value != null) {
          data.add(FitnessData(
            type: FitnessDataType.calories,
            value: calorie.value!.toDouble(),
            unit: 'kcal',
            timestamp: calorie.dateFrom,
            source: FitnessApp.appleHealth,
          ));
        }
      }
      
      // Sync weight
      final weight = await _health!.getHealthDataFromTypes(
        types: [HealthDataType.WEIGHT],
        startDate: start,
        endDate: end,
      );
      
      for (final w in weight) {
        if (w.value != null) {
          data.add(FitnessData(
            type: FitnessDataType.weight,
            value: w.value!.toDouble(),
            unit: 'kg',
            timestamp: w.dateFrom,
            source: FitnessApp.appleHealth,
          ));
        }
      }
    } catch (e) {
      print('Error syncing from Apple Health: $e');
    }
    
    return data;
  }

  // Sync from Google Fit
  Future<List<FitnessData>> _syncFromGoogleFit(DateTime start, DateTime end) async {
    final data = <FitnessData>[];
    
    try {
      // This is a placeholder for Google Fit API calls
      // In a real implementation, you'd use the Google Fit REST API
      
      // Mock data for demonstration
      final now = DateTime.now();
      for (int i = 0; i < 7; i++) {
        final date = now.subtract(Duration(days: i));
        
        // Mock steps
        data.add(FitnessData(
          type: FitnessDataType.steps,
          value: (8000 + Random().nextInt(4000)).toDouble(),
          unit: 'count',
          timestamp: date,
          source: FitnessApp.googleFit,
        ));
        
        // Mock calories
        data.add(FitnessData(
          type: FitnessDataType.calories,
          value: (2000 + Random().nextInt(800)).toDouble(),
          unit: 'kcal',
          timestamp: date,
          source: FitnessApp.googleFit,
        ));
      }
    } catch (e) {
      print('Error syncing from Google Fit: $e');
    }
    
    return data;
  }

  // Sync from Fitbit
  Future<List<FitnessData>> _syncFromFitbit(DateTime start, DateTime end) async {
    final data = <FitnessData>[];
    
    try {
      // This is a placeholder for Fitbit API calls
      // In a real implementation, you'd use the Fitbit Web API
      
      // Mock data for demonstration
      final now = DateTime.now();
      for (int i = 0; i < 7; i++) {
        final date = now.subtract(Duration(days: i));
        
        // Mock steps
        data.add(FitnessData(
          type: FitnessDataType.steps,
          value: (7000 + Random().nextInt(5000)).toDouble(),
          unit: 'count',
          timestamp: date,
          source: FitnessApp.fitbit,
        ));
        
        // Mock calories
        data.add(FitnessData(
          type: FitnessDataType.calories,
          value: (1800 + Random().nextInt(1000)).toDouble(),
          unit: 'kcal',
          timestamp: date,
          source: FitnessApp.fitbit,
        ));
      }
    } catch (e) {
      print('Error syncing from Fitbit: $e');
    }
    
    return data;
  }

  // Sync from Garmin Connect
  Future<List<FitnessData>> _syncFromGarminConnect(DateTime start, DateTime end) async {
    final data = <FitnessData>[];
    
    try {
      // This is a placeholder for Garmin Connect API calls
      // In a real implementation, you'd use the Garmin Connect API
      
      // Mock data for demonstration
      final now = DateTime.now();
      for (int i = 0; i < 7; i++) {
        final date = now.subtract(Duration(days: i));
        
        // Mock steps
        data.add(FitnessData(
          type: FitnessDataType.steps,
          value: (9000 + Random().nextInt(3000)).toDouble(),
          unit: 'count',
          timestamp: date,
          source: FitnessApp.garminConnect,
        ));
      }
    } catch (e) {
      print('Error syncing from Garmin Connect: $e');
    }
    
    return data;
  }

  // Sync from Strava
  Future<List<FitnessData>> _syncFromStrava(DateTime start, DateTime end) async {
    final data = <FitnessData>[];
    
    try {
      // This is a placeholder for Strava API calls
      // In a real implementation, you'd use the Strava API
      
      // Mock data for demonstration
      final now = DateTime.now();
      for (int i = 0; i < 7; i++) {
        final date = now.subtract(Duration(days: i));
        
        // Mock distance
        data.add(FitnessData(
          type: FitnessDataType.distance,
          value: (5.0 + Random().nextInt(10)).toDouble(),
          unit: 'km',
          timestamp: date,
          source: FitnessApp.strava,
        ));
      }
    } catch (e) {
      print('Error syncing from Strava: $e');
    }
    
    return data;
  }

  // Get aggregated fitness data
  Map<FitnessDataType, List<FitnessData>> getAggregatedData(List<FitnessData> data) {
    final aggregated = <FitnessDataType, List<FitnessData>>{};
    
    for (final item in data) {
      if (!aggregated.containsKey(item.type)) {
        aggregated[item.type] = [];
      }
      aggregated[item.type]!.add(item);
    }
    
    return aggregated;
  }

  // Get daily summaries
  List<DailyFitnessSummary> getDailySummaries(List<FitnessData> data) {
    final summaries = <DailyFitnessSummary>{};
    
    for (final item in data) {
      final date = DateTime(item.timestamp.year, item.timestamp.month, item.timestamp.day);
      
      if (!summaries.containsKey(date)) {
        summaries[date] = DailyFitnessSummary(date: date);
      }
      
      summaries[date]!.addData(item);
    }
    
    return summaries.values.toList()..sort((a, b) => b.date.compareTo(a.date));
  }

  // Check if any fitness apps are connected
  bool get hasConnectedApps => _connectedApps.values.any((connected) => connected);

  // Get available fitness apps
  List<FitnessApp> getAvailableApps() {
    return FitnessApp.values;
  }

  // Get connection status for all apps
  Map<FitnessApp, ConnectionStatus> getConnectionStatus() {
    final status = <FitnessApp, ConnectionStatus>{};
    
    for (final app in FitnessApp.values) {
      if (_connectedApps[app] == true) {
        status[app] = ConnectionStatus.connected;
      } else {
        status[app] = ConnectionStatus.disconnected;
      }
    }
    
    return status;
  }
}

// Data models
class FitnessData {
  final FitnessDataType type;
  final double value;
  final String unit;
  final DateTime timestamp;
  final FitnessApp source;

  FitnessData({
    required this.type,
    required this.value,
    required this.unit,
    required this.timestamp,
    required this.source,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type.toString().split('.').last,
      'value': value,
      'unit': unit,
      'timestamp': timestamp.toIso8601String(),
      'source': source.toString().split('.').last,
    };
  }
}

class DailyFitnessSummary {
  final DateTime date;
  double? steps;
  double? calories;
  double? distance;
  double? weight;
  Map<FitnessApp, Map<FitnessDataType, double>>? dataBySource;

  DailyFitnessSummary({required this.date});

  void addData(FitnessData data) {
    switch (data.type) {
      case FitnessDataType.steps:
        steps = (steps ?? 0) + data.value;
        break;
      case FitnessDataType.calories:
        calories = (calories ?? 0) + data.value;
        break;
      case FitnessDataType.distance:
        distance = (distance ?? 0) + data.value;
        break;
      case FitnessDataType.weight:
        weight = data.value; // Use latest weight
        break;
    }
    
    // Track data by source
    dataBySource ??= {};
    dataBySource![data.source] ??= {};
    dataBySource![data.source]![data.type] = data.value;
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'steps': steps,
      'calories': calories,
      'distance': distance,
      'weight': weight,
      'dataBySource': dataBySource?.map((key, value) => 
        MapEntry(key.toString().split('.').last, value)),
    };
  }
}

enum FitnessApp {
  appleHealth,
  googleFit,
  fitbit,
  garminConnect,
  strava,
}

enum FitnessDataType {
  steps,
  calories,
  distance,
  weight,
  height,
  bodyFat,
  heartRate,
  activeMinutes,
}

enum ConnectionStatus {
  connected,
  disconnected,
  error,
}

extension FitnessAppExtension on FitnessApp {
  String get displayName {
    switch (this) {
      case FitnessApp.appleHealth:
        return 'Apple Health';
      case FitnessApp.googleFit:
        return 'Google Fit';
      case FitnessApp.fitbit:
        return 'Fitbit';
      case FitnessApp.garminConnect:
        return 'Garmin Connect';
      case FitnessApp.strava:
        return 'Strava';
    }
  }

  String get icon {
    switch (this) {
      case FitnessApp.appleHealth:
        return 'heart';
      case FitnessApp.googleFit:
        return 'fitness_center';
      case FitnessApp.fitbit:
        return 'watch';
      case FitnessApp.garminConnect:
        return 'gps_fixed';
      case FitnessApp.strava:
        return 'directions_run';
    }
  }

  bool get isAvailable {
    switch (this) {
      case FitnessApp.appleHealth:
        return Platform.isIOS;
      case FitnessApp.googleFit:
        return Platform.isAndroid;
      case FitnessApp.fitbit:
      case FitnessApp.garminConnect:
      case FitnessApp.strava:
        return true; // Available on both platforms
    }
  }
}
