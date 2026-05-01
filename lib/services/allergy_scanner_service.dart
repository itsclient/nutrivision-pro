import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:barcode_scanner_service.dart';
import 'api_config.dart';
import 'auth_service.dart';

class AllergyScannerService {
  static final AllergyScannerService instance = AllergyScannerService._init();
  AllergyScannerService._init();

  static const String _allergiesKey = 'user_allergies';
  static const String _dietaryRestrictionsKey = 'dietary_restrictions';
  static const String _scanHistoryKey = 'allergy_scan_history';

  Set<Allergen> _userAllergies = {};
  Set<DietaryRestriction> _dietaryRestrictions = {};
  List<AllergyScan> _scanHistory = [];

  // Getters
  Set<Allergen> get userAllergies => _userAllergies;
  Set<DietaryRestriction> get dietaryRestrictions => _dietaryRestrictions;
  List<AllergyScan> get scanHistory => _scanHistory;

  // Initialize service
  Future<void> initialize() async {
    await _loadUserPreferences();
    await _loadScanHistory();
  }

  // Load user preferences
  Future<void> _loadUserPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load allergies
    final allergiesJson = prefs.getString(_allergiesKey);
    if (allergiesJson != null) {
      final allergiesList = jsonDecode(allergiesJson) as List;
      _userAllergies = allergiesList.map((e) => Allergen.values[int.parse(e.toString())]).toSet();
    }
    
    // Load dietary restrictions
    final restrictionsJson = prefs.getString(_dietaryRestrictionsKey);
    if (restrictionsJson != null) {
      final restrictionsList = jsonDecode(restrictionsJson) as List;
      _dietaryRestrictions = restrictionsList.map((e) => DietaryRestriction.values[int.parse(e.toString())]).toSet();
    }
  }

  // Load scan history
  Future<void> _loadScanHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getString(_scanHistoryKey);
    
    if (historyJson != null) {
      final historyList = jsonDecode(historyJson) as List;
      _scanHistory = historyList.map((e) => AllergyScan.fromJson(e)).toList();
    }
  }

  // Save user preferences
  Future<void> _saveUserPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.setString(_allergiesKey, jsonEncode(
      _userAllergies.map((e) => e.index).toList()
    ));
    await prefs.setString(_dietaryRestrictionsKey, jsonEncode(
      _dietaryRestrictions.map((e) => e.index).toList()
    ));
  }

  // Save scan history
  Future<void> _saveScanHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_scanHistoryKey, jsonEncode(
      _scanHistory.map((e) => e.toJson()).toList()
    ));
  }

  // Add allergy
  Future<void> addAllergy(Allergen allergen) async {
    _userAllergies.add(allergen);
    await _saveUserPreferences();
  }

  // Remove allergy
  Future<void> removeAllergy(Allergen allergen) async {
    _userAllergies.remove(allergen);
    await _saveUserPreferences();
  }

  // Add dietary restriction
  Future<void> addDietaryRestriction(DietaryRestriction restriction) async {
    _dietaryRestrictions.add(restriction);
    await _saveUserPreferences();
  }

  // Remove dietary restriction
  Future<void> removeDietaryRestriction(DietaryRestriction restriction) async {
    _dietaryRestrictions.remove(restriction);
    await _saveUserPreferences();
  }

  // Scan product for allergens and dietary compliance
  Future<AllergyScanResult> scanProduct(String barcode, {String? productName}) async {
    try {
      // Get product info from barcode scanner
      final barcodeService = BarcodeScannerService.instance;
      final scanResult = await barcodeService.scanBarcode(barcode);
      
      if (scanResult == null) {
        return AllergyScanResult(
          isSafe: false,
          warning: 'Product not found in database',
          detectedAllergens: [],
          dietaryViolations: [],
          recommendations: ['Try manual entry or contact manufacturer'],
        );
      }

      // Analyze ingredients for allergens
      final detectedAllergens = await _detectAllergens(scanResult.scan);
      
      // Check dietary restrictions
      final dietaryViolations = await _checkDietaryRestrictions(scanResult.scan);
      
      // Generate recommendations
      final recommendations = _generateRecommendations(
        scanResult.scan,
        detectedAllergens,
        dietaryViolations,
      );

      final scan = AllergyScan(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        barcode: barcode,
        productName: scanResult.scan.productName,
        detectedAllergens: detectedAllergens,
        dietaryViolations: dietaryViolations,
        isSafe: detectedAllergens.isEmpty && dietaryViolations.isEmpty,
        timestamp: DateTime.now(),
        recommendations: recommendations,
      );

      // Add to history
      _scanHistory.insert(0, scan);
      if (_scanHistory.length > 100) {
        _scanHistory = _scanHistory.take(100).toList();
      }
      await _saveScanHistory();

      return AllergyScanResult(
        isSafe: scan.isSafe,
        warning: scan.isSafe ? 'Product is safe for you' : 'Product contains allergens or violates dietary restrictions',
        detectedAllergens: detectedAllergens,
        dietaryViolations: dietaryViolations,
        recommendations: recommendations,
      );
    } catch (e) {
      print('Error scanning product: $e');
      return AllergyScanResult(
        isSafe: false,
        warning: 'Error scanning product',
        detectedAllergens: [],
        dietaryViolations: [],
        recommendations: ['Please try again later'],
      );
    }
  }

  // Detect allergens in product
  Future<List<Allergen>> _detectAllergens(BarcodeScan scan) async {
    final detectedAllergens = <Allergen>[];
    
    for (final allergen in _userAllergies) {
      if (await _containsAllergen(scan, allergen)) {
        detectedAllergens.add(allergen);
      }
    }
    
    return detectedAllergens;
  }

  // Check if product contains specific allergen
  Future<bool> _containsAllergen(BarcodeScan scan, Allergen allergen) async {
    // Get allergen keywords
    final keywords = _getAllergenKeywords(allergen);
    
    // Check product name and brand
    final searchText = '${scan.productName} ${scan.brand}'.toLowerCase();
    
    for (final keyword in keywords) {
      if (searchText.contains(keyword)) {
        return true;
      }
    }
    
    // For more detailed analysis, we could check ingredients list
    // This would require ingredient data from the barcode service
    
    return false;
  }

  // Get keywords for allergen detection
  List<String> _getAllergenKeywords(Allergen allergen) {
    switch (allergen) {
      case Allergen.milk:
        return ['milk', 'dairy', 'cheese', 'butter', 'cream', 'yogurt', 'lactose', 'whey', 'casein'];
      case Allergen.eggs:
        return ['egg', 'eggs', 'albumin', 'ovalbumin', 'mayonnaise'];
      case Allergen.fish:
        return ['fish', 'salmon', 'tuna', 'cod', 'anchovy', 'sardine', 'omega-3'];
      case Allergen.shellfish:
        return ['shrimp', 'crab', 'lobster', 'clam', 'mussel', 'oyster', 'scallop', 'crustacean'];
      case Allergen.treeNuts:
        return ['almond', 'walnut', 'pecan', 'cashew', 'pistachio', 'hazelnut', 'macadamia', 'brazil nut'];
      case Allergen.peanuts:
        return ['peanut', 'peanuts', 'groundnut', 'arachis', 'mandelona'];
      case Allergen.wheat:
        return ['wheat', 'gluten', 'flour', 'bread', 'pasta', 'couscous', 'semolina'];
      case Allergen.soy:
        return ['soy', 'soybean', 'tofu', 'edamame', 'miso', 'tempeh', 'soy sauce'];
      case Allergen.sesame:
        return ['sesame', 'tahini', 'sesame oil', 'benne', 'simsim'];
      default:
        return [];
    }
  }

  // Check dietary restrictions
  Future<List<DietaryViolation>> _checkDietaryRestrictions(BarcodeScan scan) async {
    final violations = <DietaryViolation>[];
    
    for (final restriction in _dietaryRestrictions) {
      if (await _violatesRestriction(scan, restriction)) {
        violations.add(DietaryViolation(
          restriction: restriction,
          severity: _getViolationSeverity(scan, restriction),
          details: _getViolationDetails(scan, restriction),
        ));
      }
    }
    
    return violations;
  }

  // Check if product violates dietary restriction
  Future<bool> _violatesRestriction(BarcodeScan scan, DietaryRestriction restriction) async {
    switch (restriction) {
      case DietaryRestriction.vegetarian:
        return await _containsMeat(scan);
      case DietaryRestriction.vegan:
        return await _containsAnimalProducts(scan);
      case DietaryRestriction.glutenFree:
        return await _containsGluten(scan);
      case DietaryRestriction.dairyFree:
        return await _containsDairy(scan);
      case DietaryRestriction.kosher:
        return await _containsNonKosher(scan);
      case DietaryRestriction.halal:
        return await _containsNonHalal(scan);
      case DietaryRestriction.lowSodium:
        return scan.sodium > 140; // FDA definition of low sodium
      case DietaryRestriction.lowSugar:
        return scan.sugar > 5; // Less than 5g per serving
      case DietaryRestriction.lowFat:
        return scan.fat > 3; // Less than 3g per serving
      default:
        return false;
    }
  }

  // Helper methods for dietary restriction checks
  Future<bool> _containsMeat(BarcodeScan scan) async {
    final meatKeywords = ['beef', 'pork', 'chicken', 'turkey', 'lamb', 'veal', 'meat', 'bacon', 'sausage'];
    final searchText = scan.productName.toLowerCase();
    return meatKeywords.any((keyword) => searchText.contains(keyword));
  }

  Future<bool> _containsAnimalProducts(BarcodeScan scan) async {
    return await _containsMeat(scan) || await _containsDairy(scan) || 
           await _containsEggs(scan) || await _containsHoney(scan);
  }

  Future<bool> _containsGluten(BarcodeScan scan) async {
    final glutenKeywords = ['wheat', 'barley', 'rye', 'oats', 'gluten', 'flour', 'bread', 'pasta'];
    final searchText = scan.productName.toLowerCase();
    return glutenKeywords.any((keyword) => searchText.contains(keyword));
  }

  Future<bool> _containsDairy(BarcodeScan scan) async {
    final dairyKeywords = ['milk', 'cheese', 'butter', 'cream', 'yogurt', 'dairy', 'lactose'];
    final searchText = scan.productName.toLowerCase();
    return dairyKeywords.any((keyword) => searchText.contains(keyword));
  }

  Future<bool> _containsEggs(BarcodeScan scan) async {
    final eggKeywords = ['egg', 'eggs', 'mayonnaise'];
    final searchText = scan.productName.toLowerCase();
    return eggKeywords.any((keyword) => searchText.contains(keyword));
  }

  Future<bool> _containsHoney(BarcodeScan scan) async {
    final searchText = scan.productName.toLowerCase();
    return searchText.contains('honey');
  }

  Future<bool> _containsNonKosher(BarcodeScan scan) async {
    // Simplified check - in real app would use kosher certification database
    final nonKosherKeywords = ['pork', 'bacon', 'ham', 'shrimp', 'crab', 'lobster', 'clam', 'oyster'];
    final searchText = scan.productName.toLowerCase();
    return nonKosherKeywords.any((keyword) => searchText.contains(keyword));
  }

  Future<bool> _containsNonHalal(BarcodeScan scan) async {
    // Simplified check - in real app would use halal certification database
    final nonHalalKeywords = ['pork', 'bacon', 'ham', 'alcohol'];
    final searchText = scan.productName.toLowerCase();
    return nonHalalKeywords.any((keyword) => searchText.contains(keyword));
  }

  ViolationSeverity _getViolationSeverity(BarcodeScan scan, DietaryRestriction restriction) {
    switch (restriction) {
      case DietaryRestriction.vegetarian:
      case DietaryRestriction.vegan:
        return ViolationSeverity.high;
      case DietaryRestriction.glutenFree:
        return ViolationSeverity.critical;
      case DietaryRestriction.dairyFree:
        return _userAllergies.contains(Allergen.milk) ? ViolationSeverity.critical : ViolationSeverity.medium;
      default:
        return ViolationSeverity.low;
    }
  }

  String _getViolationDetails(BarcodeScan scan, DietaryRestriction restriction) {
    switch (restriction) {
      case DietaryRestriction.vegetarian:
        return 'Contains meat or animal products';
      case DietaryRestriction.vegan:
        return 'Contains animal products';
      case DietaryRestriction.glutenFree:
        return 'Contains gluten or wheat-based ingredients';
      case DietaryRestriction.dairyFree:
        return 'Contains dairy products';
      case DietaryRestriction.kosher:
        return 'Not certified kosher';
      case DietaryRestriction.halal:
        return 'Not certified halal';
      case DietaryRestriction.lowSodium:
        return 'High sodium content: ${scan.sodium}mg';
      case DietaryRestriction.lowSugar:
        return 'High sugar content: ${scan.sugar}g';
      case DietaryRestriction.lowFat:
        return 'High fat content: ${scan.fat}g';
      default:
        return 'Violates dietary restriction';
    }
  }

  // Generate recommendations
  List<String> _generateRecommendations(
    BarcodeScan scan,
    List<Allergen> allergens,
    List<DietaryViolation> violations,
  ) {
    final recommendations = <String>[];
    
    if (allergens.isNotEmpty) {
      recommendations.add('Avoid this product due to allergens: ${allergens.map((a) => a.displayName).join(', ')}');
      recommendations.add('Look for allergen-free alternatives');
    }
    
    if (violations.isNotEmpty) {
      for (final violation in violations) {
        recommendations.add('${violation.restriction.displayName}: ${violation.details}');
      }
    }
    
    if (allergens.isEmpty && violations.isEmpty) {
      recommendations.add('This product is safe for your dietary needs');
      recommendations.add('Enjoy in moderation as part of a balanced diet');
    }
    
    // Add general recommendations
    recommendations.add('Always check ingredient lists for the most accurate information');
    recommendations.add('Contact manufacturer if you have specific concerns');
    
    return recommendations;
  }

  // Get scan statistics
  Map<String, dynamic> getScanStatistics() {
    final totalScans = _scanHistory.length;
    final safeScans = _scanHistory.where((s) => s.isSafe).length;
    final unsafeScans = totalScans - safeScans;
    
    // Most common allergens detected
    final allergenCounts = <Allergen, int>{};
    for (final scan in _scanHistory) {
      for (final allergen in scan.detectedAllergens) {
        allergenCounts[allergen] = (allergenCounts[allergen] ?? 0) + 1;
      }
    }
    
    final mostCommonAllergens = allergenCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    // Most common dietary violations
    final violationCounts = <DietaryRestriction, int>{};
    for (final scan in _scanHistory) {
      for (final violation in scan.dietaryViolations) {
        violationCounts[violation.restriction] = (violationCounts[violation.restriction] ?? 0) + 1;
      }
    }
    
    final mostCommonViolations = violationCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return {
      'total_scans': totalScans,
      'safe_scans': safeScans,
      'unsafe_scans': unsafeScans,
      'safety_rate': totalScans > 0 ? (safeScans / totalScans * 100).round() : 0,
      'most_common_allergens': mostCommonAllergens.take(3).map((e) => {
        'allergen': e.key.displayName,
        'count': e.value,
      }).toList(),
      'most_common_violations': mostCommonViolations.take(3).map((e) => {
        'restriction': e.key.displayName,
        'count': e.value,
      }).toList(),
    };
  }

  // Clear scan history
  Future<void> clearScanHistory() async {
    _scanHistory.clear();
    await _saveScanHistory();
  }

  // Export scan history
  String exportScanHistory() {
    final exportData = {
      'export_date': DateTime.now().toIso8601String(),
      'user_allergies': _userAllergies.map((e) => e.displayName).toList(),
      'dietary_restrictions': _dietaryRestrictions.map((e) => e.displayName).toList(),
      'scan_history': _scanHistory.map((e) => e.toJson()).toList(),
    };
    
    return jsonEncode(exportData);
  }
}

// Data models
class AllergyScanResult {
  final bool isSafe;
  final String warning;
  final List<Allergen> detectedAllergens;
  final List<DietaryViolation> dietaryViolations;
  final List<String> recommendations;

  AllergyScanResult({
    required this.isSafe,
    required this.warning,
    required this.detectedAllergens,
    required this.dietaryViolations,
    required this.recommendations,
  });
}

class AllergyScan {
  final String id;
  final String barcode;
  final String productName;
  final List<Allergen> detectedAllergens;
  final List<DietaryViolation> dietaryViolations;
  final bool isSafe;
  final DateTime timestamp;
  final List<String> recommendations;

  AllergyScan({
    required this.id,
    required this.barcode,
    required this.productName,
    required this.detectedAllergens,
    required this.dietaryViolations,
    required this.isSafe,
    required this.timestamp,
    required this.recommendations,
  });

  factory AllergyScan.fromJson(Map<String, dynamic> json) {
    return AllergyScan(
      id: json['id'] ?? '',
      barcode: json['barcode'] ?? '',
      productName: json['productName'] ?? '',
      detectedAllergens: (json['detectedAllergens'] as List)
          .map((e) => Allergen.values[int.parse(e.toString())])
          .toList(),
      dietaryViolations: (json['dietaryViolations'] as List)
          .map((e) => DietaryViolation.fromJson(e))
          .toList(),
      isSafe: json['isSafe'] ?? false,
      timestamp: DateTime.parse(json['timestamp']),
      recommendations: List<String>.from(json['recommendations'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'barcode': barcode,
      'productName': productName,
      'detectedAllergens': detectedAllergens.map((e) => e.index).toList(),
      'dietaryViolations': dietaryViolations.map((e) => e.toJson()).toList(),
      'isSafe': isSafe,
      'timestamp': timestamp.toIso8601String(),
      'recommendations': recommendations,
    };
  }
}

class DietaryViolation {
  final DietaryRestriction restriction;
  final ViolationSeverity severity;
  final String details;

  DietaryViolation({
    required this.restriction,
    required this.severity,
    required this.details,
  });

  factory DietaryViolation.fromJson(Map<String, dynamic> json) {
    return DietaryViolation(
      restriction: DietaryRestriction.values[int.parse(json['restriction'].toString())],
      severity: ViolationSeverity.values[int.parse(json['severity'].toString())],
      details: json['details'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'restriction': restriction.index,
      'severity': severity.index,
      'details': details,
    };
  }
}

enum Allergen {
  milk,
  eggs,
  fish,
  shellfish,
  treeNuts,
  peanuts,
  wheat,
  soy,
  sesame,
}

extension AllergenExtension on Allergen {
  String get displayName {
    switch (this) {
      case Allergen.milk:
        return 'Milk/Dairy';
      case Allergen.eggs:
        return 'Eggs';
      case Allergen.fish:
        return 'Fish';
      case Allergen.shellfish:
        return 'Shellfish';
      case Allergen.treeNuts:
        return 'Tree Nuts';
      case Allergen.peanuts:
        return 'Peanuts';
      case Allergen.wheat:
        return 'Wheat/Gluten';
      case Allergen.soy:
        return 'Soy';
      case Allergen.sesame:
        return 'Sesame';
    }
  }

  String get icon {
    switch (this) {
      case Allergen.milk:
        return 'glass';
      case Allergen.eggs:
        return 'egg';
      case Allergen.fish:
        return 'fish';
      case Allergen.shellfish:
        return 'set_meal';
      case Allergen.treeNuts:
        return 'forest';
      case Allergen.peanuts:
        return 'grass';
      case Allergen.wheat:
        return 'grass';
      case Allergen.soy:
        return 'eco';
      case Allergen.sesame:
        return 'grain';
    }
  }

  Color get color {
    switch (this) {
      case Allergen.milk:
        return Colors.blue;
      case Allergen.eggs:
        return Colors.orange;
      case Allergen.fish:
        return Colors.cyan;
      case Allergen.shellfish:
        return Colors.purple;
      case Allergen.treeNuts:
        return Colors.brown;
      case Allergen.peanuts:
        return Colors.amber;
      case Allergen.wheat:
        return Colors.yellow;
      case Allergen.soy:
        return Colors.green;
      case Allergen.sesame:
        return Colors.grey;
    }
  }
}

enum DietaryRestriction {
  vegetarian,
  vegan,
  glutenFree,
  dairyFree,
  kosher,
  halal,
  lowSodium,
  lowSugar,
  lowFat,
}

extension DietaryRestrictionExtension on DietaryRestriction {
  String get displayName {
    switch (this) {
      case DietaryRestriction.vegetarian:
        return 'Vegetarian';
      case DietaryRestriction.vegan:
        return 'Vegan';
      case DietaryRestriction.glutenFree:
        return 'Gluten-Free';
      case DietaryRestriction.dairyFree:
        return 'Dairy-Free';
      case DietaryRestriction.kosher:
        return 'Kosher';
      case DietaryRestriction.halal:
        return 'Halal';
      case DietaryRestriction.lowSodium:
        return 'Low Sodium';
      case DietaryRestriction.lowSugar:
        return 'Low Sugar';
      case DietaryRestriction.lowFat:
        return 'Low Fat';
    }
  }

  String get icon {
    switch (this) {
      case DietaryRestriction.vegetarian:
        return 'leaf';
      case DietaryRestriction.vegan:
        return 'spa';
      case DietaryRestriction.glutenFree:
        return 'no_food';
      case DietaryRestriction.dairyFree:
        return 'no_meals';
      case DietaryRestriction.kosher:
        return 'verified';
      case DietaryRestriction.halal:
        return 'verified';
      case DietaryRestriction.lowSodium:
        return 'do_not_disturb';
      case DietaryRestriction.lowSugar:
        return 'no_food';
      case DietaryRestriction.lowFat:
        return 'fitness_center';
    }
  }

  Color get color {
    switch (this) {
      case DietaryRestriction.vegetarian:
        return Colors.green;
      case DietaryRestriction.vegan:
        return Colors.lightGreen;
      case DietaryRestriction.glutenFree:
        return Colors.brown;
      case DietaryRestriction.dairyFree:
        return Colors.blue;
      case DietaryRestriction.kosher:
        return Colors.indigo;
      case DietaryRestriction.halal:
        return Colors.teal;
      case DietaryRestriction.lowSodium:
        return Colors.red;
      case DietaryRestriction.lowSugar:
        return Colors.orange;
      case DietaryRestriction.lowFat:
        return Colors.purple;
    }
  }
}

enum ViolationSeverity {
  low,
  medium,
  high,
  critical,
}

extension ViolationSeverityExtension on ViolationSeverity {
  String get displayName {
    switch (this) {
      case ViolationSeverity.low:
        return 'Low';
      case ViolationSeverity.medium:
        return 'Medium';
      case ViolationSeverity.high:
        return 'High';
      case ViolationSeverity.critical:
        return 'Critical';
    }
  }

  Color get color {
    switch (this) {
      case ViolationSeverity.low:
        return Colors.yellow;
      case ViolationSeverity.medium:
        return Colors.orange;
      case ViolationSeverity.high:
        return Colors.red;
      case ViolationSeverity.critical:
        return Colors.red.shade900;
    }
  }
}
