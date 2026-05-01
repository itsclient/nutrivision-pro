import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:http/http.dart' as http;
import 'package:camera/camera.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'api_config.dart';
import 'auth_service.dart';

class SmartCameraService {
  static final SmartCameraService instance = SmartCameraService._init();
  SmartCameraService._init();

  static const String _scanHistoryKey = 'smart_camera_history';
  static const String _modelLoadedKey = 'tflite_model_loaded';

  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  Interpreter? _interpreter;
  List<String> _labels = [];
  List<FoodScan> _scanHistory = [];

  // Getters
  CameraController? get cameraController => _cameraController;
  List<CameraDescription> get cameras => _cameras;
  bool get isModelLoaded => _interpreter != null;
  List<FoodScan> get scanHistory => _scanHistory;

  // Initialize camera and ML model
  Future<void> initialize() async {
    await _initializeCamera();
    await _loadMLModel();
    await _loadScanHistory();
  }

  // Initialize camera
  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      
      if (_cameras.isNotEmpty) {
        // Use back camera by default
        final backCamera = _cameras.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.back,
          orElse: () => _cameras.first,
        );

        _cameraController = CameraController(
          backCamera,
          ResolutionPreset.high,
          enableAudio: false,
          imageFormatGroup: ImageFormatGroup.jpeg,
        );

        await _cameraController!.initialize();
      }
    } catch (e) {
      print('Error initializing camera: $e');
    }
  }

  // Load TensorFlow Lite model
  Future<void> _loadMLModel() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final modelLoaded = prefs.getBool(_modelLoadedKey) ?? false;
      
      if (!modelLoaded) {
        // Load food recognition model
        _interpreter = await Tflite.loadModel(
          model: "assets/models/food_recognition.tflite",
          labels: "assets/models/food_labels.txt",
        );
        
        // Load labels
        final labelsData = await DefaultAssetBundle.of(Get.context!)
            .loadString("assets/models/food_labels.txt");
        _labels = labelsData.split('\n');
        
        await prefs.setBool(_modelLoadedKey, true);
      }
    } catch (e) {
      print('Error loading ML model: $e');
      // Fallback to cloud API
      _interpreter = null;
    }
  }

  // Load scan history
  Future<void> _loadScanHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString(_scanHistoryKey);
      
      if (historyJson != null) {
        final historyList = jsonDecode(historyJson) as List;
        _scanHistory = historyList.map((e) => FoodScan.fromJson(e)).toList();
      }
    } catch (e) {
      print('Error loading scan history: $e');
    }
  }

  // Save scan history
  Future<void> _saveScanHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_scanHistoryKey, jsonEncode(
        _scanHistory.map((e) => e.toJson()).toList()
      ));
    } catch (e) {
      print('Error saving scan history: $e');
    }
  }

  // Capture and analyze image
  Future<FoodScanResult?> captureAndAnalyze() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return null;
    }

    try {
      final XFile imageFile = await _cameraController!.takePicture();
      final imageBytes = await imageFile.readAsBytes();
      
      // Analyze image
      final result = await _analyzeImage(imageBytes, imageFile.path);
      
      // Clean up temporary file
      await File(imageFile.path).delete();
      
      return result;
    } catch (e) {
      print('Error capturing and analyzing image: $e');
      return null;
    }
  }

  // Analyze image using ML model or API
  Future<FoodScanResult?> _analyzeImage(Uint8List imageBytes, String imagePath) async {
    try {
      // Try local ML model first
      if (_interpreter != null) {
        final result = await _analyzeWithMLModel(imageBytes);
        if (result != null) return result;
      }
      
      // Fallback to cloud API
      return await _analyzeWithCloudAPI(imageBytes, imagePath);
    } catch (e) {
      print('Error analyzing image: $e');
      return null;
    }
  }

  // Analyze with local TensorFlow Lite model
  Future<FoodScanResult?> _analyzeWithMLModel(Uint8List imageBytes) async {
    try {
      // Decode and preprocess image
      final image = img.decodeImage(imageBytes);
      final resizedImage = img.copyResize(image, width: 224, height: 224);
      
      // Convert to tensor format
      final input = _imageToTensor(resizedImage);
      
      // Run inference
      final output = List.filled(1 * _labels.length, 0.0).reshape([1, _labels.length]);
      _interpreter!.run(input, output);
      
      // Process results
      final results = output[0] as List<double>;
      final sortedResults = results.asMap().entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      
      // Get top prediction
      if (sortedResults.isNotEmpty && sortedResults.first.value > 0.5) {
        final topResult = sortedResults.first;
        final foodName = _labels[topResult.key];
        final confidence = topResult.value;
        
        // Get nutritional info
        final nutrition = await _getNutritionInfo(foodName);
        
        return FoodScanResult(
          foodName: foodName,
          confidence: confidence,
          nutrition: nutrition,
          source: ScanSource.localML,
        );
      }
    } catch (e) {
      print('Error analyzing with ML model: $e');
    }
    return null;
  }

  // Convert image to tensor format
  List<List<List<List<double>>>> _imageToTensor(img.Image image) {
    final tensor = List.generate(
      224,
      (y) => List.generate(
        224,
        (x) => List.generate(
          3,
          (c) => _normalizePixel(image.getPixel(x, y), c),
        ),
      ),
    );
    return tensor;
  }

  double _normalizePixel(img.Pixel pixel, int channel) {
    switch (channel) {
      case 0: // Red
        return pixel.r / 255.0;
      case 1: // Green
        return pixel.g / 255.0;
      case 2: // Blue
        return pixel.b / 255.0;
      default:
        return 0.0;
    }
  }

  // Analyze with cloud API
  Future<FoodScanResult?> _analyzeWithCloudAPI(Uint8List imageBytes, String imagePath) async {
    try {
      // Google Vision API
      final visionResult = await _analyzeWithGoogleVision(imageBytes);
      if (visionResult != null) return visionResult;
      
      // Custom food recognition API
      final customResult = await _analyzeWithCustomAPI(imageBytes);
      if (customResult != null) return customResult;
      
      return null;
    } catch (e) {
      print('Error analyzing with cloud API: $e');
      return null;
    }
  }

  // Analyze with Google Vision API
  Future<FoodScanResult?> _analyzeWithGoogleVision(Uint8List imageBytes) async {
    try {
      final request = {
        'requests': [
          {
            'image': {
              'content': base64Encode(imageBytes),
            },
            'features': [
              {'type': 'LABEL_DETECTION', 'maxResults': 10},
              {'type': 'OBJECT_LOCALIZATION', 'maxResults': 10},
            ],
          },
        ],
      };

      final response = await http.post(
        Uri.parse('https://vision.googleapis.com/v1/images:annotate?key=YOUR_API_KEY'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(request),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final labels = data['responses'][0]['labelAnnotations'] as List;
        
        // Find food-related labels
        final foodLabels = labels.where((label) =>
          _isFoodLabel(label['description'] as String)
        ).toList();

        if (foodLabels.isNotEmpty) {
          final topLabel = foodLabels.first;
          final foodName = topLabel['description'] as String;
          final confidence = (topLabel['score'] as double).toDouble();
          
          final nutrition = await _getNutritionInfo(foodName);
          
          return FoodScanResult(
            foodName: foodName,
            confidence: confidence,
            nutrition: nutrition,
            source: ScanSource.googleVision,
          );
        }
      }
    } catch (e) {
      print('Error with Google Vision API: $e');
    }
    return null;
  }

  // Analyze with custom API
  Future<FoodScanResult?> _analyzeWithCustomAPI(Uint8List imageBytes) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.baseUrl}/ai/analyze-food'),
      );
      
      request.files.add(
        http.MultipartFile.fromBytes('image', imageBytes, filename: 'food.jpg'),
      );
      
      final response = await request.send();
      final responseData = await response.stream.bytesToString();
      
      if (response.statusCode == 200) {
        final data = jsonDecode(responseData);
        
        return FoodScanResult(
          foodName: data['food_name'],
          confidence: (data['confidence'] as double).toDouble(),
          nutrition: NutritionInfo.fromJson(data['nutrition']),
          source: ScanSource.customAPI,
        );
      }
    } catch (e) {
      print('Error with custom API: $e');
    }
    return null;
  }

  // Check if label is food-related
  bool _isFoodLabel(String label) {
    final foodKeywords = [
      'food', 'fruit', 'vegetable', 'meat', 'fish', 'bread', 'cake',
      'dessert', 'pizza', 'burger', 'salad', 'soup', 'pasta', 'rice',
      'chicken', 'beef', 'pork', 'cheese', 'milk', 'egg', 'breakfast',
      'lunch', 'dinner', 'snack', 'sweet', 'chocolate', 'ice cream',
    ];
    
    final lowerLabel = label.toLowerCase();
    return foodKeywords.any((keyword) => lowerLabel.contains(keyword));
  }

  // Get nutrition information for food
  Future<NutritionInfo?> _getNutritionInfo(String foodName) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/nutrition/food/${Uri.encodeComponent(foodName)}'),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return NutritionInfo.fromJson(data);
      }
    } catch (e) {
      print('Error getting nutrition info: $e');
    }
    
    // Return mock data if API fails
    return _getMockNutritionInfo(foodName);
  }

  // Get mock nutrition info
  NutritionInfo _getMockNutritionInfo(String foodName) {
    final lowerName = foodName.toLowerCase();
    
    if (lowerName.contains('cake') || lowerName.contains('dessert')) {
      return NutritionInfo(
        calories: 350,
        protein: 4.0,
        carbs: 45.0,
        fat: 18.0,
        fiber: 2.0,
        sugar: 25.0,
        sodium: 200,
        servingSize: '100g',
      );
    } else if (lowerName.contains('fruit') || lowerName.contains('apple')) {
      return NutritionInfo(
        calories: 52,
        protein: 0.3,
        carbs: 14.0,
        fat: 0.2,
        fiber: 2.4,
        sugar: 10.4,
        sodium: 1,
        servingSize: '100g',
      );
    } else if (lowerName.contains('vegetable') || lowerName.contains('salad')) {
      return NutritionInfo(
        calories: 25,
        protein: 1.5,
        carbs: 5.0,
        fat: 0.2,
        fiber: 2.8,
        sugar: 2.0,
        sodium: 15,
        servingSize: '100g',
      );
    } else {
      // Default values
      return NutritionInfo(
        calories: 150,
        protein: 10.0,
        carbs: 20.0,
        fat: 5.0,
        fiber: 3.0,
        sugar: 5.0,
        sodium: 100,
        servingSize: '100g',
      );
    }
  }

  // Add scan to history
  Future<void> addToHistory(FoodScan scan) async {
    _scanHistory.insert(0, scan);
    
    // Keep only last 50 scans
    if (_scanHistory.length > 50) {
      _scanHistory = _scanHistory.take(50).toList();
    }
    
    await _saveScanHistory();
  }

  // Search scan history
  List<FoodScan> searchHistory(String query) {
    if (query.isEmpty) return _scanHistory;
    
    final lowerQuery = query.toLowerCase();
    return _scanHistory.where((scan) =>
      scan.foodName.toLowerCase().contains(lowerQuery)
    ).toList();
  }

  // Dispose camera
  void dispose() {
    _cameraController?.dispose();
    _interpreter?.close();
  }

  // Get scan statistics
  Map<String, dynamic> getScanStatistics() {
    final totalScans = _scanHistory.length;
    final uniqueFoods = _scanHistory.map((s) => s.foodName).toSet().length;
    
    // Most scanned foods
    final scanCounts = <String, int>{};
    for (final scan in _scanHistory) {
      scanCounts[scan.foodName] = (scanCounts[scan.foodName] ?? 0) + 1;
    }
    
    final mostScanned = scanCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    // Average confidence
    final avgConfidence = _scanHistory.isEmpty ? 0.0 :
        _scanHistory.fold(0.0, (sum, scan) => sum + scan.confidence) / _scanHistory.length;
    
    return {
      'total_scans': totalScans,
      'unique_foods': uniqueFoods,
      'most_scanned': mostScanned.take(5).map((e) => {
        'food': e.key,
        'count': e.value,
      }).toList(),
      'average_confidence': avgConfidence,
    };
  }
}

// Data models
class FoodScanResult {
  final String foodName;
  final double confidence;
  final NutritionInfo nutrition;
  final ScanSource source;

  FoodScanResult({
    required this.foodName,
    required this.confidence,
    required this.nutrition,
    required this.source,
  });
}

class FoodScan {
  final String id;
  final String foodName;
  final double confidence;
  final NutritionInfo nutrition;
  final ScanSource source;
  final DateTime timestamp;
  final String? imagePath;

  FoodScan({
    required this.id,
    required this.foodName,
    required this.confidence,
    required this.nutrition,
    required this.source,
    required this.timestamp,
    this.imagePath,
  });

  factory FoodScan.fromJson(Map<String, dynamic> json) {
    return FoodScan(
      id: json['id'] ?? '',
      foodName: json['foodName'] ?? '',
      confidence: (json['confidence'] ?? 0.0).toDouble(),
      nutrition: NutritionInfo.fromJson(json['nutrition']),
      source: ScanSource.values.firstWhere(
        (e) => e.toString() == 'ScanSource.${json['source']}',
        orElse: () => ScanSource.unknown,
      ),
      timestamp: DateTime.parse(json['timestamp']),
      imagePath: json['imagePath'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'foodName': foodName,
      'confidence': confidence,
      'nutrition': nutrition.toJson(),
      'source': source.toString().split('.').last,
      'timestamp': timestamp.toIso8601String(),
      'imagePath': imagePath,
    };
  }
}

class NutritionInfo {
  final int calories;
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;
  final double sugar;
  final int sodium;
  final String servingSize;

  NutritionInfo({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.fiber,
    required this.sugar,
    required this.sodium,
    required this.servingSize,
  });

  factory NutritionInfo.fromJson(Map<String, dynamic> json) {
    return NutritionInfo(
      calories: json['calories'] ?? 0,
      protein: (json['protein'] ?? 0.0).toDouble(),
      carbs: (json['carbs'] ?? 0.0).toDouble(),
      fat: (json['fat'] ?? 0.0).toDouble(),
      fiber: (json['fiber'] ?? 0.0).toDouble(),
      sugar: (json['sugar'] ?? 0.0).toDouble(),
      sodium: json['sodium'] ?? 0,
      servingSize: json['servingSize'] ?? '100g',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'fiber': fiber,
      'sugar': sugar,
      'sodium': sodium,
      'servingSize': servingSize,
    };
  }
}

enum ScanSource {
  localML,
  googleVision,
  customAPI,
  unknown,
}
