import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'database_service.dart';
import 'sync_service.dart';
import 'package:http/http.dart' as http;

class OfflineService {
  static final OfflineService instance = OfflineService._init();
  OfflineService._init();

  Database? _offlineDb;
  bool _isOnline = true;
  bool _syncInProgress = false;

  bool get isOnline => _isOnline;
  bool get syncInProgress => _syncInProgress;

  Future<void> initialize() async {
    final dbPath = await getDatabasesPath();
    _offlineDb = await openDatabase(
      join(dbPath, 'offline_cache.db'),
      version: 1,
      onCreate: (db, version) async {
        // Pending sync operations
        await db.execute('''
          CREATE TABLE pending_operations (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            type TEXT NOT NULL,
            data TEXT NOT NULL,
            timestamp INTEGER NOT NULL,
            retry_count INTEGER DEFAULT 0
          )
        ''');

        // Cached API responses
        await db.execute('''
          CREATE TABLE api_cache (
            url TEXT PRIMARY KEY,
            data TEXT NOT NULL,
            timestamp INTEGER NOT NULL,
            expiry INTEGER NOT NULL
          )
        ''');

        // Offline scans queue
        await db.execute('''
          CREATE TABLE offline_scans (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            scan_data TEXT NOT NULL,
            timestamp INTEGER NOT NULL,
            synced INTEGER DEFAULT 0
          )
        ''');
      },
    );
  }

  // Check network connectivity
  Future<bool> checkConnectivity() async {
    try {
      final response = await http.get(
        Uri.parse('https://nutrivision-api-kqed.onrender.com/api/admin/stats'),
      ).timeout(const Duration(seconds: 5));
      _isOnline = response.statusCode == 200;
    } catch (e) {
      _isOnline = false;
    }
    return _isOnline;
  }

  // Save operation for later sync
  Future<void> queueOperation(String type, Map<String, dynamic> data) async {
    if (_offlineDb == null) await initialize();
    
    await _offlineDb!.insert(
      'pending_operations',
      {
        'type': type,
        'data': jsonEncode(data),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'retry_count': 0,
      },
    );
  }

  // Cache API response
  Future<void> cacheResponse(String url, dynamic data, {Duration expiry = const Duration(hours: 1)}) async {
    if (_offlineDb == null) await initialize();
    
    await _offlineDb!.insert(
      'api_cache',
      {
        'url': url,
        'data': jsonEncode(data),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'expiry': DateTime.now().add(expiry).millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Get cached response
  Future<dynamic?> getCachedResponse(String url) async {
    if (_offlineDb == null) await initialize();
    
    final result = await _offlineDb!.query(
      'api_cache',
      where: 'url = ? AND expiry > ?',
      whereArgs: [url, DateTime.now().millisecondsSinceEpoch],
    );

    if (result.isNotEmpty) {
      return jsonDecode(result.first['data'] as String);
    }
    return null;
  }

  // Save scan for offline
  Future<void> saveOfflineScan(Map<String, dynamic> scanData) async {
    if (_offlineDb == null) await initialize();
    
    await _offlineDb!.insert(
      'offline_scans',
      {
        'scan_data': jsonEncode(scanData),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'synced': 0,
      },
    );
  }

  // Sync all pending operations
  Future<bool> syncPendingOperations() async {
    if (_syncInProgress || !await checkConnectivity()) return false;
    
    _syncInProgress = true;
    
    try {
      // Sync pending operations
      final operations = await _offlineDb!.query(
        'pending_operations',
        orderBy: 'timestamp ASC',
      );

      for (final op in operations) {
        try {
          final data = jsonDecode(op['data'] as String);
          final type = op['type'] as String;
          
          bool success = false;
          
          switch (type) {
            case 'scan':
              success = await _syncScan(data);
              break;
            case 'profile_update':
              success = await _syncProfile(data);
              break;
            case 'settings_update':
              success = await _syncSettings(data);
              break;
          }

          if (success) {
            await _offlineDb!.delete(
              'pending_operations',
              where: 'id = ?',
              whereArgs: [op['id']],
            );
          } else {
            // Increment retry count
            await _offlineDb!.update(
              'pending_operations',
              {'retry_count': (op['retry_count'] as int) + 1},
              where: 'id = ?',
              whereArgs: [op['id']],
            );
          }
        } catch (e) {
          print('Error syncing operation: $e');
        }
      }

      // Sync offline scans
      await _syncOfflineScans();
      
      return true;
    } finally {
      _syncInProgress = false;
    }
  }

  Future<bool> _syncScan(Map<String, dynamic> scanData) async {
    try {
      final response = await http.post(
        Uri.parse('https://nutrivision-api-kqed.onrender.com/api/sync'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'scans': [scanData]}),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _syncProfile(Map<String, dynamic> profileData) async {
    try {
      final response = await http.put(
        Uri.parse('https://nutrivision-api-kqed.onrender.com/api/user/profile'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(profileData),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _syncSettings(Map<String, dynamic> settingsData) async {
    // Settings are stored locally, but we can track them if needed
    return true;
  }

  Future<void> _syncOfflineScans() async {
    final scans = await _offlineDb!.query(
      'offline_scans',
      where: 'synced = 0',
      orderBy: 'timestamp ASC',
    );

    for (final scan in scans) {
      try {
        final scanData = jsonDecode(scan['scan_data'] as String);
        final success = await _syncScan(scanData);
        
        if (success) {
          await _offlineDb!.update(
            'offline_scans',
            {'synced': 1},
            where: 'id = ?',
            whereArgs: [scan['id']],
          );
        }
      } catch (e) {
        print('Error syncing offline scan: $e');
      }
    }
  }

  // Get offline statistics
  Future<Map<String, int>> getOfflineStats() async {
    if (_offlineDb == null) await initialize();
    
    final pendingOps = await _offlineDb!.rawQuery('SELECT COUNT(*) as count FROM pending_operations');
    final offlineScans = await _offlineDb!.rawQuery('SELECT COUNT(*) as count FROM offline_scans WHERE synced = 0');
    
    return {
      'pending_operations': pendingOps.first['count'] as int,
      'offline_scans': offlineScans.first['count'] as int,
    };
  }

  // Clear old cache
  Future<void> clearOldCache() async {
    if (_offlineDb == null) await initialize();
    
    final now = DateTime.now().millisecondsSinceEpoch;
    
    await _offlineDb!.delete(
      'api_cache',
      where: 'expiry < ?',
      whereArgs: [now],
    );
    
    // Clear old failed operations (more than 7 days and 5+ retries)
    final weekAgo = now - (7 * 24 * 60 * 60 * 1000);
    await _offlineDb!.delete(
      'pending_operations',
      where: 'timestamp < ? AND retry_count >= 5',
      whereArgs: [weekAgo],
    );
  }
}
