import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class PerformanceService {
  static final PerformanceService instance = PerformanceService._init();
  PerformanceService._init();

  // Cache management
  static const String _cacheSizeKey = 'cache_size';
  static const String _lastCleanupKey = 'last_cleanup';
  static const Duration _cleanupInterval = Duration(days: 7);
  static const int _maxCacheSize = 100 * 1024 * 1024; // 100MB

  // Performance metrics
  Map<String, dynamic> _metrics = {
    'app_start_time': 0,
    'memory_usage': 0,
    'cache_size': 0,
    'network_requests': 0,
    'image_load_time': 0,
  };

  Map<String, dynamic> get metrics => _metrics;

  // Initialize performance monitoring
  Future<void> initialize() async {
    final startTime = DateTime.now().millisecondsSinceEpoch;
    
    // Initialize cache
    await _initializeCache();
    
    // Clean up old cache
    await _cleanupCache();
    
    // Record startup time
    _metrics['app_start_time'] = DateTime.now().millisecondsSinceEpoch - startTime;
    
    // Start monitoring
    _startPerformanceMonitoring();
  }

  // Initialize cache directory
  Future<void> _initializeCache() async {
    final directory = await getTemporaryDirectory();
    final cacheDir = Directory('${directory.path}/cache');
    
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
  }

  // Compress image before storing/uploading
  Future<Uint8List> compressImage(
    File imageFile, {
    int maxWidth = 800,
    int maxHeight = 800,
    int quality = 85,
  }) async {
    try {
      final startTime = DateTime.now().millisecondsSinceEpoch;
      
      // Read image
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes)!;
      
      // Calculate new dimensions
      final newWidth = _calculateNewWidth(image.width, image.height, maxWidth);
      final newHeight = _calculateNewHeight(image.width, image.height, maxHeight);
      
      // Resize image
      final resized = img.copyResize(
        image,
        width: newWidth,
        height: newHeight,
        interpolation: img.Interpolation.average,
      );
      
      // Compress
      final compressedBytes = img.encodeJpg(resized, quality: quality);
      
      // Record metrics
      _metrics['image_load_time'] = DateTime.now().millisecondsSinceEpoch - startTime;
      
      return Uint8List.fromList(compressedBytes);
    } catch (e) {
      print('Error compressing image: $e');
      rethrow;
    }
  }

  int _calculateNewWidth(int originalWidth, int originalHeight, int maxWidth) {
    if (originalWidth <= maxWidth) return originalWidth;
    final ratio = maxWidth / originalWidth;
    return (originalWidth * ratio).round();
  }

  int _calculateNewHeight(int originalWidth, int originalHeight, int maxHeight) {
    if (originalHeight <= maxHeight) return originalHeight;
    final ratio = maxHeight / originalHeight;
    return (originalHeight * ratio).round();
  }

  // Cache network responses
  Future<void> cacheResponse(String url, String data) async {
    try {
      final cacheFile = await _getCacheFile(url);
      await cacheFile.writeAsString(data);
      await _updateCacheSize();
    } catch (e) {
      print('Error caching response: $e');
    }
  }

  // Get cached response
  Future<String?> getCachedResponse(String url) async {
    try {
      final cacheFile = await _getCacheFile(url);
      
      if (await cacheFile.exists()) {
        // Check if cache is expired (24 hours)
        final lastModified = await cacheFile.lastModified();
        if (DateTime.now().difference(lastModified).inHours < 24) {
          return await cacheFile.readAsString();
        } else {
          await cacheFile.delete();
        }
      }
    } catch (e) {
      print('Error getting cached response: $e');
    }
    return null;
  }

  Future<File> _getCacheFile(String url) async {
    final directory = await getTemporaryDirectory();
    final fileName = url.hashCode.toString();
    return File('${directory.path}/cache/$fileName');
  }

  // Update cache size
  Future<void> _updateCacheSize() async {
    try {
      final directory = await getTemporaryDirectory();
      final cacheDir = Directory('${directory.path}/cache');
      
      if (await cacheDir.exists()) {
        int totalSize = 0;
        await for (final entity in cacheDir.list()) {
          if (entity is File) {
            totalSize += await entity.length();
          }
        }
        
        _metrics['cache_size'] = totalSize;
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_cacheSizeKey, totalSize);
      }
    } catch (e) {
      print('Error updating cache size: $e');
    }
  }

  // Clean up old cache
  Future<void> _cleanupCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastCleanup = prefs.getString(_lastCleanupKey);
      
      if (lastCleanup != null) {
        final lastCleanupDate = DateTime.parse(lastCleanup);
        if (DateTime.now().difference(lastCleanupDate) < _cleanupInterval) {
          return; // Not time to clean up yet
        }
      }
      
      final directory = await getTemporaryDirectory();
      final cacheDir = Directory('${directory.path}/cache');
      
      if (await cacheDir.exists()) {
        final files = <FileSystemEntity>[];
        await for (final entity in cacheDir.list()) {
          files.add(entity);
        }
        
        // Sort by last modified time
        files.sort((a, b) {
          final aDate = a is File ? a.lastModified() : Future.value(DateTime.now());
          final bDate = b is File ? b.lastModified() : Future.value(DateTime.now());
          return aDate.then((a) => bDate.then((b) => a.compareTo(b)));
        });
        
        // Delete old files until cache size is under limit
        int currentSize = 0;
        for (final file in files.reversed) {
          if (file is File) {
            currentSize += await file.length();
            if (currentSize > _maxCacheSize) {
              await file.delete();
            }
          }
        }
      }
      
      // Update last cleanup time
      await prefs.setString(_lastCleanupKey, DateTime.now().toIso8601String());
      await _updateCacheSize();
    } catch (e) {
      print('Error cleaning up cache: $e');
    }
  }

  // Optimize memory usage
  Future<void> optimizeMemory() async {
    try {
      // Force garbage collection
      await SystemChannels.platform.invokeMethod('System.gc');
      
      // Clear image cache
      PaintingBinding.instance.imageCache.clear();
      
      // Update memory usage metric
      await _updateMemoryUsage();
    } catch (e) {
      print('Error optimizing memory: $e');
    }
  }

  Future<void> _updateMemoryUsage() async {
    try {
      // This is a simplified memory usage calculation
      // In a real app, you'd use platform-specific APIs
      final info = await ProcessInfo.currentRss;
      _metrics['memory_usage'] = info;
    } catch (e) {
      print('Error getting memory usage: $e');
    }
  }

  // Start performance monitoring
  void _startPerformanceMonitoring() {
    // Update metrics every 30 seconds
    Timer.periodic(const Duration(seconds: 30), (_) async {
      await _updateMemoryUsage();
      await _updateCacheSize();
    });
  }

  // Lazy load resources
  Future<T> lazyLoad<T>(Future<T> Function() loader) async {
    try {
      return await loader();
    } catch (e) {
      print('Error in lazy loading: $e');
      rethrow;
    }
  }

  // Batch network requests
  Future<List<dynamic>> batchRequests(List<Future<http.Response>> requests) async {
    try {
      _metrics['network_requests'] = _metrics['network_requests'] + requests.length;
      
      final results = await Future.wait(
        requests,
        eagerError: false,
      );
      
      return results;
    } catch (e) {
      print('Error in batch requests: $e');
      rethrow;
    }
  }

  // Preload critical resources
  Future<void> preloadCriticalResources() async {
    try {
      // Preload common images
      final criticalImages = [
        'assets/images/placeholder.png',
        'assets/images/logo.png',
      ];
      
      for (final imagePath in criticalImages) {
        try {
          final byteData = await rootBundle.load(imagePath);
          // Keep in memory cache
          PaintingBinding.instance.imageCache.putIfAbsent(
            imagePath,
            () => instantiateImageCodec(byteData.buffer.asUint8List()),
          );
        } catch (e) {
          print('Error preloading image $imagePath: $e');
        }
      }
    } catch (e) {
      print('Error preloading resources: $e');
    }
  }

  // Get performance report
  Map<String, dynamic> getPerformanceReport() {
    return {
      'app_start_time_ms': _metrics['app_start_time'],
      'memory_usage_mb': (_metrics['memory_usage'] / (1024 * 1024)).round(),
      'cache_size_mb': (_metrics['cache_size'] / (1024 * 1024)).round(),
      'network_requests_count': _metrics['network_requests'],
      'avg_image_load_time_ms': _metrics['image_load_time'],
      'performance_score': _calculatePerformanceScore(),
    };
  }

  double _calculatePerformanceScore() {
    double score = 100.0;
    
    // Deduct points for slow startup
    if (_metrics['app_start_time'] > 3000) score -= 20;
    else if (_metrics['app_start_time'] > 2000) score -= 10;
    
    // Deduct points for high memory usage
    final memoryMB = _metrics['memory_usage'] / (1024 * 1024);
    if (memoryMB > 200) score -= 20;
    else if (memoryMB > 150) score -= 10;
    
    // Deduct points for large cache
    final cacheMB = _metrics['cache_size'] / (1024 * 1024);
    if (cacheMB > 50) score -= 15;
    else if (cacheMB > 30) score -= 5;
    
    // Deduct points for slow image loading
    if (_metrics['image_load_time'] > 1000) score -= 15;
    else if (_metrics['image_load_time'] > 500) score -= 5;
    
    return score.clamp(0.0, 100.0);
  }

  // Reduce app size by removing unused assets
  Future<void> optimizeAppSize() async {
    try {
      // Clear unused cache
      await _cleanupCache();
      
      // Optimize images
      await _optimizeStoredImages();
      
      // Remove old temporary files
      await _removeOldTempFiles();
      
      // Update metrics
      await _updateMemoryUsage();
      await _updateCacheSize();
    } catch (e) {
      print('Error optimizing app size: $e');
    }
  }

  Future<void> _optimizeStoredImages() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      
      await for (final entity in directory.list()) {
        if (entity is File && _isImageFile(entity.path)) {
          // Compress existing images
          final compressedBytes = await compressImage(entity);
          await entity.writeAsBytes(compressedBytes);
        }
      }
    } catch (e) {
      print('Error optimizing stored images: $e');
    }
  }

  bool _isImageFile(String path) {
    final imageExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp'];
    return imageExtensions.any((ext) => path.toLowerCase().endsWith(ext));
  }

  Future<void> _removeOldTempFiles() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final now = DateTime.now();
      
      await for (final entity in tempDir.list()) {
        if (entity is File) {
          final lastModified = await entity.lastModified();
          if (now.difference(lastModified).inDays > 7) {
            await entity.delete();
          }
        }
      }
    } catch (e) {
      print('Error removing old temp files: $e');
    }
  }

  // Monitor network performance
  Future<Map<String, dynamic>> measureNetworkPerformance(String url) async {
    final startTime = DateTime.now().millisecondsSinceEpoch;
    
    try {
      final response = await http.get(Uri.parse(url));
      final endTime = DateTime.now().millisecondsSinceEpoch;
      
      return {
        'url': url,
        'response_time_ms': endTime - startTime,
        'status_code': response.statusCode,
        'content_length': response.contentLength,
        'success': response.statusCode == 200,
      };
    } catch (e) {
      return {
        'url': url,
        'response_time_ms': DateTime.now().millisecondsSinceEpoch - startTime,
        'status_code': 0,
        'content_length': 0,
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Get storage usage breakdown
  Future<Map<String, dynamic>> getStorageBreakdown() async {
    final breakdown = <String, int>{};
    
    try {
      // Documents directory
      final documentsDir = await getApplicationDocumentsDirectory();
      breakdown['documents'] = await _getDirectorySize(documentsDir);
      
      // Cache directory
      final cacheDir = await getTemporaryDirectory();
      breakdown['cache'] = await _getDirectorySize(cacheDir);
      
      // Shared preferences
      final prefs = await SharedPreferences.getInstance();
      breakdown['preferences'] = prefs.getKeys().length * 100; // Estimate
      
    } catch (e) {
      print('Error getting storage breakdown: $e');
    }
    
    return breakdown;
  }

  Future<int> _getDirectorySize(Directory dir) async {
    int size = 0;
    
    try {
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) {
          size += await entity.length();
        }
      }
    } catch (e) {
      print('Error calculating directory size: $e');
    }
    
    return size;
  }
}
