import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image/image.dart' as img;
import 'api_config.dart';
import 'auth_service.dart';

class BarcodeScannerService {
  static final BarcodeScannerService instance = BarcodeScannerService._init();
  BarcodeScannerService._init();

  static const String _scanHistoryKey = 'barcode_scan_history';
  static const String _favoritesKey = 'barcode_favorites';
  static const String _customItemsKey = 'custom_barcode_items';

  List<BarcodeScan> _scanHistory = [];
  Set<String> _favoriteBarcodes = {};
  Map<String, CustomBarcodeItem> _customItems = {};

  // Getters
  List<BarcodeScan> get scanHistory => _scanHistory;
  Set<String> get favoriteBarcodes => _favoriteBarcodes;
  Map<String, CustomBarcodeItem> get customItems => _customItems;

  // Initialize barcode scanner service
  Future<void> initialize() async {
    await _loadScanHistory();
    await _loadFavorites();
    await _loadCustomItems();
  }

  // Load scan history
  Future<void> _loadScanHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getString(_scanHistoryKey);
    
    if (historyJson != null) {
      final historyList = jsonDecode(historyJson) as List;
      _scanHistory = historyList.map((e) => BarcodeScan.fromJson(e)).toList();
    }
  }

  // Load favorites
  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final favoritesJson = prefs.getString(_favoritesKey);
    
    if (favoritesJson != null) {
      final favoritesList = jsonDecode(favoritesJson) as List;
      _favoriteBarcodes = favoritesList.cast<String>().toSet();
    }
  }

  // Load custom items
  Future<void> _loadCustomItems() async {
    final prefs = await SharedPreferences.getInstance();
    final customJson = prefs.getString(_customItemsKey);
    
    if (customJson != null) {
      final customMap = jsonDecode(customJson) as Map<String, dynamic>;
      _customItems = customMap.map((key, value) => 
        MapEntry(key, CustomBarcodeItem.fromJson(value)));
    }
  }

  // Save scan history
  Future<void> _saveScanHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_scanHistoryKey, jsonEncode(
      _scanHistory.map((e) => e.toJson()).toList()
    ));
  }

  // Save favorites
  Future<void> _saveFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_favoritesKey, jsonEncode(_favoriteBarcodes.toList()));
  }

  // Save custom items
  Future<void> _saveCustomItems() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_customItemsKey, jsonEncode(
      _customItems.map((key, value) => MapEntry(key, value.toJson()))
    ));
  }

  // Scan barcode and get product info
  Future<BarcodeScanResult?> scanBarcode(String barcode) async {
    try {
      // Check if we have custom data first
      if (_customItems.containsKey(barcode)) {
        final customItem = _customItems[barcode]!;
        final scan = BarcodeScan(
          barcode: barcode,
          productName: customItem.name,
          brand: customItem.brand,
          category: customItem.category,
          calories: customItem.calories,
          protein: customItem.protein,
          carbs: customItem.carbs,
          fat: customItem.fat,
          servingSize: customItem.servingSize,
          timestamp: DateTime.now(),
          source: BarcodeSource.custom,
        );
        
        await _addToHistory(scan);
        return BarcodeScanResult(scan: scan, isNew: false);
      }

      // Try to get product from API
      final product = await _getProductFromAPI(barcode);
      
      if (product != null) {
        final scan = BarcodeScan(
          barcode: barcode,
          productName: product.name,
          brand: product.brand,
          category: product.category,
          calories: product.calories,
          protein: product.protein,
          carbs: product.carbs,
          fat: product.fat,
          servingSize: product.servingSize,
          timestamp: DateTime.now(),
          source: BarcodeSource.api,
        );
        
        await _addToHistory(scan);
        return BarcodeScanResult(scan: scan, isNew: true);
      }

      // Try Open Food Facts
      final openFoodProduct = await _getProductFromOpenFoodFacts(barcode);
      
      if (openFoodProduct != null) {
        final scan = BarcodeScan(
          barcode: barcode,
          productName: openFoodProduct.name,
          brand: openFoodProduct.brand,
          category: openFoodProduct.category,
          calories: openFoodProduct.calories,
          protein: openFoodProduct.protein,
          carbs: openFoodProduct.carbs,
          fat: openFoodProduct.fat,
          servingSize: openFoodProduct.servingSize,
          timestamp: DateTime.now(),
          source: BarcodeSource.openFoodFacts,
        );
        
        await _addToHistory(scan);
        return BarcodeScanResult(scan: scan, isNew: true);
      }

      // Product not found
      return null;
    } catch (e) {
      print('Error scanning barcode: $e');
      return null;
    }
  }

  // Get product from our API
  Future<ProductInfo?> _getProductFromAPI(String barcode) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/products/barcode/$barcode'),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return ProductInfo.fromJson(data);
      }
    } catch (e) {
      print('Error getting product from API: $e');
    }
    return null;
  }

  // Get product from Open Food Facts
  Future<ProductInfo?> _getProductFromOpenFoodFacts(String barcode) async {
    try {
      final response = await http.get(
        Uri.parse('https://world.openfoodfacts.org/api/v0/product/$barcode.json'),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['status'] == 1) {
          final product = data['product'];
          
          // Extract nutrition information
          final nutriments = product['nutriments'] ?? {};
          
          return ProductInfo(
            name: product['product_name'] ?? 'Unknown Product',
            brand: product['brands'] ?? 'Unknown Brand',
            category: _extractCategory(product),
            calories: (nutriments['energy-kcal_100g'] ?? 0.0).toDouble(),
            protein: (nutriments['proteins_100g'] ?? 0.0).toDouble(),
            carbs: (nutriments['carbohydrates_100g'] ?? 0.0).toDouble(),
            fat: (nutriments['fat_100g'] ?? 0.0).toDouble(),
            servingSize: product['serving_size'] ?? '100g',
            imageUrl: product['image_url'],
          );
        }
      }
    } catch (e) {
      print('Error getting product from Open Food Facts: $e');
    }
    return null;
  }

  // Extract category from product data
  String _extractCategory(Map<String, dynamic> product) {
    final categories = product['categories'] ?? '';
    final categoriesTags = product['categories_tags'] ?? [];
    
    if (categories.isNotEmpty) {
      return categories.split(',')[0].trim();
    }
    
    if (categoriesTags.isNotEmpty) {
      return (categoriesTags.first as String).split(':').last;
    }
    
    return 'Unknown';
  }

  // Add scan to history
  Future<void> _addToHistory(BarcodeScan scan) async {
    // Remove existing scan for same barcode if exists
    _scanHistory.removeWhere((s) => s.barcode == scan.barcode);
    
    // Add new scan to beginning
    _scanHistory.insert(0, scan);
    
    // Keep only last 100 scans
    if (_scanHistory.length > 100) {
      _scanHistory = _scanHistory.take(100).toList();
    }
    
    await _saveScanHistory();
  }

  // Add to favorites
  Future<void> addToFavorites(String barcode) async {
    _favoriteBarcodes.add(barcode);
    await _saveFavorites();
  }

  // Remove from favorites
  Future<void> removeFromFavorites(String barcode) async {
    _favoriteBarcodes.remove(barcode);
    await _saveFavorites();
  }

  // Check if barcode is favorite
  bool isFavorite(String barcode) {
    return _favoriteBarcodes.contains(barcode);
  }

  // Add custom item
  Future<void> addCustomItem(CustomBarcodeItem item) async {
    _customItems[item.barcode] = item;
    await _saveCustomItems();
  }

  // Update custom item
  Future<void> updateCustomItem(CustomBarcodeItem item) async {
    _customItems[item.barcode] = item;
    await _saveCustomItems();
  }

  // Delete custom item
  Future<void> deleteCustomItem(String barcode) async {
    _customItems.remove(barcode);
    await _saveCustomItems();
  }

  // Search scan history
  List<BarcodeScan> searchHistory(String query) {
    if (query.isEmpty) return _scanHistory;
    
    final lowerQuery = query.toLowerCase();
    return _scanHistory.where((scan) =>
      scan.productName.toLowerCase().contains(lowerQuery) ||
      scan.brand.toLowerCase().contains(lowerQuery) ||
      scan.barcode.contains(query)
    ).toList();
  }

  // Get scan statistics
  Map<String, dynamic> getScanStatistics() {
    final totalScans = _scanHistory.length;
    final uniqueProducts = _scanHistory.map((s) => s.barcode).toSet().length;
    final favoriteCount = _favoriteBarcodes.length;
    final customCount = _customItems.length;
    
    // Most scanned products
    final scanCounts = <String, int>{};
    for (final scan in _scanHistory) {
      scanCounts[scan.barcode] = (scanCounts[scan.barcode] ?? 0) + 1;
    }
    
    final mostScanned = scanCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    // Category distribution
    final categoryCounts = <String, int>{};
    for (final scan in _scanHistory) {
      categoryCounts[scan.category] = (categoryCounts[scan.category] ?? 0) + 1;
    }
    
    return {
      'total_scans': totalScans,
      'unique_products': uniqueProducts,
      'favorite_count': favoriteCount,
      'custom_count': customCount,
      'most_scanned': mostScanned.take(5).map((e) => {
        'barcode': e.key,
        'count': e.value,
        'name': _scanHistory.firstWhere((s) => s.barcode == e.key).productName,
      }).toList(),
      'category_distribution': categoryCounts,
    };
  }

  // Export scan history
  String exportScanHistory() {
    final exportData = {
      'export_date': DateTime.now().toIso8601String(),
      'total_scans': _scanHistory.length,
      'scans': _scanHistory.map((e) => e.toJson()).toList(),
    };
    
    return jsonEncode(exportData);
  }

  // Import scan history
  Future<bool> importScanHistory(String jsonData) async {
    try {
      final data = jsonDecode(jsonData) as Map<String, dynamic>;
      final scans = (data['scans'] as List)
          .map((e) => BarcodeScan.fromJson(e))
          .toList();
      
      // Merge with existing history
      for (final scan in scans) {
        _scanHistory.removeWhere((s) => s.barcode == scan.barcode);
        _scanHistory.add(scan);
      }
      
      // Sort by timestamp
      _scanHistory.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      
      // Keep only last 100 scans
      if (_scanHistory.length > 100) {
        _scanHistory = _scanHistory.take(100).toList();
      }
      
      await _saveScanHistory();
      return true;
    } catch (e) {
      print('Error importing scan history: $e');
      return false;
    }
  }

  // Clear scan history
  Future<void> clearScanHistory() async {
    _scanHistory.clear();
    await _saveScanHistory();
  }

  // Get recent scans
  List<BarcodeScan> getRecentScans({int limit = 10}) {
    return _scanHistory.take(limit).toList();
  }

  // Get favorite scans
  List<BarcodeScan> getFavoriteScans() {
    return _scanHistory.where((scan) => _favoriteBarcodes.contains(scan.barcode)).toList();
  }

  // Generate barcode image for custom items
  Future<Uint8List> generateBarcodeImage(String barcode) async {
    try {
      // This would use a barcode generation library
      // For now, return a placeholder
      final image = img.Image(width: 200, height: 100);
      img.fill(image, img.ColorRgb(255, 255, 255));
      
      // Add barcode representation (simplified)
      final barcodeData = barcode.hashCode;
      for (int i = 0; i < 50; i++) {
        final x = i * 4;
        final width = (barcodeData >> (i % 8)) % 2 == 0 ? 2 : 1;
        
        for (int y = 20; y < 80; y++) {
          for (int w = 0; w < width; w++) {
            if (x + w < 200) {
              image.setPixel(x + w, y, img.ColorRgb(0, 0, 0));
            }
          }
        }
      }
      
      return Uint8List.fromList(img.encodePng(image));
    } catch (e) {
      print('Error generating barcode image: $e');
      return Uint8List(0);
    }
  }

  // Validate barcode format
  bool isValidBarcode(String barcode) {
    // Basic validation for common barcode formats
    if (barcode.isEmpty) return false;
    
    // EAN-13: 13 digits
    if (RegExp(r'^\d{13}$').hasMatch(barcode)) return true;
    
    // UPC-A: 12 digits
    if (RegExp(r'^\d{12}$').hasMatch(barcode)) return true;
    
    // Code 128: variable length alphanumeric
    if (RegExp(r'^[A-Za-z0-9]{8,20}$').hasMatch(barcode)) return true;
    
    // QR Code: variable length
    if (barcode.length >= 8 && barcode.length <= 2953) return true;
    
    return false;
  }

  // Get barcode type
  BarcodeType getBarcodeType(String barcode) {
    if (RegExp(r'^\d{13}$').hasMatch(barcode)) return BarcodeType.ean13;
    if (RegExp(r'^\d{12}$').hasMatch(barcode)) return BarcodeType.upcA;
    if (RegExp(r'^[A-Za-z0-9]{8,20}$').hasMatch(barcode)) return BarcodeType.code128;
    if (barcode.length >= 8 && barcode.length <= 2953) return BarcodeType.qrCode;
    
    return BarcodeType.unknown;
  }
}

// Data models
class BarcodeScan {
  final String barcode;
  final String productName;
  final String brand;
  final String category;
  final int calories;
  final double protein;
  final double carbs;
  final double fat;
  final String servingSize;
  final DateTime timestamp;
  final BarcodeSource source;

  BarcodeScan({
    required this.barcode,
    required this.productName,
    required this.brand,
    required this.category,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.servingSize,
    required this.timestamp,
    required this.source,
  });

  factory BarcodeScan.fromJson(Map<String, dynamic> json) {
    return BarcodeScan(
      barcode: json['barcode'] ?? '',
      productName: json['productName'] ?? '',
      brand: json['brand'] ?? '',
      category: json['category'] ?? '',
      calories: json['calories'] ?? 0,
      protein: (json['protein'] ?? 0.0).toDouble(),
      carbs: (json['carbs'] ?? 0.0).toDouble(),
      fat: (json['fat'] ?? 0.0).toDouble(),
      servingSize: json['servingSize'] ?? '',
      timestamp: DateTime.parse(json['timestamp']),
      source: BarcodeSource.values.firstWhere(
        (e) => e.toString() == 'BarcodeSource.${json['source']}',
        orElse: () => BarcodeSource.unknown,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'barcode': barcode,
      'productName': productName,
      'brand': brand,
      'category': category,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'servingSize': servingSize,
      'timestamp': timestamp.toIso8601String(),
      'source': source.toString().split('.').last,
    };
  }
}

class BarcodeScanResult {
  final BarcodeScan scan;
  final bool isNew;

  BarcodeScanResult({
    required this.scan,
    required this.isNew,
  });
}

class ProductInfo {
  final String name;
  final String brand;
  final String category;
  final int calories;
  final double protein;
  final double carbs;
  final double fat;
  final String servingSize;
  final String? imageUrl;

  ProductInfo({
    required this.name,
    required this.brand,
    required this.category,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.servingSize,
    this.imageUrl,
  });

  factory ProductInfo.fromJson(Map<String, dynamic> json) {
    return ProductInfo(
      name: json['name'] ?? '',
      brand: json['brand'] ?? '',
      category: json['category'] ?? '',
      calories: json['calories'] ?? 0,
      protein: (json['protein'] ?? 0.0).toDouble(),
      carbs: (json['carbs'] ?? 0.0).toDouble(),
      fat: (json['fat'] ?? 0.0).toDouble(),
      servingSize: json['servingSize'] ?? '',
      imageUrl: json['imageUrl'],
    );
  }
}

class CustomBarcodeItem {
  final String barcode;
  final String name;
  final String brand;
  final String category;
  final int calories;
  final double protein;
  final double carbs;
  final double fat;
  final String servingSize;
  final String? notes;
  final DateTime createdAt;

  CustomBarcodeItem({
    required this.barcode,
    required this.name,
    required this.brand,
    required this.category,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.servingSize,
    this.notes,
    required this.createdAt,
  });

  factory CustomBarcodeItem.fromJson(Map<String, dynamic> json) {
    return CustomBarcodeItem(
      barcode: json['barcode'] ?? '',
      name: json['name'] ?? '',
      brand: json['brand'] ?? '',
      category: json['category'] ?? '',
      calories: json['calories'] ?? 0,
      protein: (json['protein'] ?? 0.0).toDouble(),
      carbs: (json['carbs'] ?? 0.0).toDouble(),
      fat: (json['fat'] ?? 0.0).toDouble(),
      servingSize: json['servingSize'] ?? '',
      notes: json['notes'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'barcode': barcode,
      'name': name,
      'brand': brand,
      'category': category,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'servingSize': servingSize,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

enum BarcodeSource {
  api,
  openFoodFacts,
  custom,
  unknown,
}

enum BarcodeType {
  ean13,
  upcA,
  code128,
  qrCode,
  unknown,
}
