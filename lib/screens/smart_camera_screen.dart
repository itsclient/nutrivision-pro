import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:camera/camera.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../services/theme_service.dart';
import '../services/smart_camera_service.dart';
import '../services/gesture_service.dart';
import '../services/gamification_service.dart';
import '../services/notification_service.dart';

class SmartCameraScreen extends StatefulWidget {
  const SmartCameraScreen({Key? key}) : super(key: key);

  @override
  State<SmartCameraScreen> createState() => _SmartCameraScreenState();
}

class _SmartCameraScreenState extends State<SmartCameraScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;

  bool _isScanning = false;
  bool _isProcessing = false;
  FoodScanResult? _lastResult;
  List<String> _scanHistory = [];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeCamera();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _animationController.forward();
  }

  Future<void> _initializeCamera() async {
    try {
      await SmartCameraService.instance.initialize();
      setState(() {});
    } catch (e) {
      print('Error initializing camera: $e');
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    SmartCameraService.instance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera view
          if (SmartCameraService.instance.cameraController != null)
            _buildCameraView()
          else
            _buildCameraPlaceholder(),
          
          // UI overlay
          _buildUIOverlay(),
          
          // Result overlay
          if (_lastResult != null)
            _buildResultOverlay(),
        ],
      ),
    );
  }

  Widget _buildCameraView() {
    final cameraController = SmartCameraService.instance.cameraController!;
    
    if (!cameraController.value.isInitialized) {
      return _buildCameraPlaceholder();
    }

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: CameraPreview(cameraController),
        );
      },
    );
  }

  Widget _buildCameraPlaceholder() {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary,
                        width: 3,
                      ),
                    ),
                    child: Icon(
                      FontAwesomeIcons.camera,
                      color: Theme.of(context).colorScheme.primary,
                      size: 40,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            Text(
              'Initializing Camera...',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUIOverlay() {
    return Column(
      children: [
        // Top bar
        _buildTopBar(),
        
        // Middle area - scanning indicator
        Expanded(
          child: Center(
            child: _buildScanningIndicator(),
          ),
        ),
        
        // Bottom controls
        _buildBottomControls(),
      ],
    );
  }

  Widget _buildTopBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Back button
            GestureService.instance.hapticGestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  FontAwesomeIcons.arrowLeft,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
            
            const Spacer(),
            
            // Title
            Text(
              'AI Food Scanner',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const Spacer(),
            
            // Flash toggle
            GestureService.instance.hapticGestureDetector(
              onTap: _toggleFlash,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  FontAwesomeIcons.bolt,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanningIndicator() {
    if (!_isScanning) return const SizedBox.shrink();
    
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Scanning frame
        Container(
          width: 250,
          height: 250,
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).colorScheme.primary,
              width: 3,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Stack(
            children: [
              // Corner brackets
              Positioned(
                top: 10,
                left: 10,
                child: _buildCornerBracket(TopLeft),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: _buildCornerBracket(TopRight),
              ),
              Positioned(
                bottom: 10,
                left: 10,
                child: _buildCornerBracket(BottomLeft),
              ),
              Positioned(
                bottom: 10,
                right: 10,
                child: _buildCornerBracket(BottomRight),
              ),
              
              // Scanning animation
              if (_isScanning)
                Center(
                  child: AnimatedBuilder(
                    animation: _animationController,
                    builder: (context, child) {
                      return Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Theme.of(context).colorScheme.primary.withOpacity(
                              (_fadeAnimation.value * 0.5).clamp(0.0, 1.0)
                            ),
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(15),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
        
        const SizedBox(height: 24),
        
        // Scanning text
        Text(
          _isProcessing ? 'Analyzing...' : 'Scanning...',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        
        if (_isProcessing) ...[
          const SizedBox(height: 16),
          const CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 2,
          ),
        ],
      ],
    );
  }

  Widget _buildCornerBracket(CornerPosition position) {
    Alignment alignment;
    IconData icon;
    
    switch (position) {
      case CornerPosition.topLeft:
        alignment = Alignment.topLeft;
        icon = FontAwesomeIcons.caretUp;
        break;
      case CornerPosition.topRight:
        alignment = Alignment.topRight;
        icon = FontAwesomeIcons.caretUp;
        break;
      case CornerPosition.bottomLeft:
        alignment = Alignment.bottomLeft;
        icon = FontAwesomeIcons.caretDown;
        break;
      case CornerPosition.bottomRight:
        alignment = Alignment.bottomRight;
        icon = FontAwesomeIcons.caretDown;
        break;
    }
    
    return Align(
      alignment: alignment,
      child: Icon(
        icon,
        color: Theme.of(context).colorScheme.primary,
        size: 24,
      ),
    );
  }

  Widget _buildBottomControls() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Recent scans
            if (_scanHistory.isNotEmpty) ...[
              Container(
                height: 60,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _scanHistory.take(5).length,
                  itemBuilder: (context, index) {
                    return _buildRecentScanChip(_scanHistory[index]);
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            // Capture button
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Gallery button
                GestureService.instance.hapticGestureDetector(
                  onTap: _pickFromGallery,
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.5),
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      FontAwesomeIcons.images,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
                
                const SizedBox(width: 32),
                
                // Capture button
                GestureService.instance.hapticGestureDetector(
                  onTap: _captureAndAnalyze,
                  hapticType: HapticType.heavy,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: _isProcessing
                        ? const CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          )
                        : const Icon(
                            FontAwesomeIcons.camera,
                            color: Colors.white,
                            size: 32,
                          ),
                  ),
                ),
                
                const SizedBox(width: 32),
                
                // History button
                GestureService.instance.hapticGestureDetector(
                  onTap: _showScanHistory,
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.5),
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      FontAwesomeIcons.history,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Instructions
            Text(
              'Point camera at food and tap to scan',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white.withOpacity(0.8),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentScanChip(String foodName) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
        ),
      ),
      child: Text(
        foodName,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildResultOverlay() {
    if (_lastResult == null) return const SizedBox.shrink();
    
    final result = _lastResult!;
    
    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Result header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: result.confidence > 0.7 ? Colors.green : Colors.orange,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  result.confidence > 0.7 ? FontAwesomeIcons.check : FontAwesomeIcons.exclamationTriangle,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.foodName,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Confidence: ${(result.confidence * 100).round()}%',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Nutrition info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nutrition Information',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                _buildNutritionRow('Calories', '${result.nutrition.calories}', Colors.orange),
                _buildNutritionRow('Protein', '${result.nutrition.protein}g', Colors.green),
                _buildNutritionRow('Carbs', '${result.nutrition.carbs}g', Colors.blue),
                _buildNutritionRow('Fat', '${result.nutrition.fat}g', Colors.red),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Source info
          Row(
            children: [
              Icon(
                FontAwesomeIcons.infoCircle,
                size: 16,
                color: Colors.grey[600],
              ),
              const SizedBox(width: 8),
              Text(
                'Source: ${result.source.displayName}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Action buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _saveResult,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Save'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: _dismissResult,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey[300]!),
                  ),
                  child: const Text('Dismiss'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNutritionRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _captureAndAnalyze() async {
    if (_isProcessing) return;
    
    setState(() {
      _isScanning = true;
      _isProcessing = true;
    });

    try {
      final result = await SmartCameraService.instance.captureAndAnalyze();
      
      if (result != null) {
        setState(() {
          _lastResult = result;
          _scanHistory.insert(0, result.foodName);
          if (_scanHistory.length > 10) {
            _scanHistory = _scanHistory.take(10).toList();
          }
        });

        // Award points for successful scan
        await GamificationService.instance.awardPoints(
          15,
          reason: 'AI food scan',
        );

        // Show notification
        await NotificationService.instance.showAchievement(
          'Food Scanned!',
          result.foodName,
        );
      }
    } catch (e) {
      print('Error capturing and analyzing: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isScanning = false;
        _isProcessing = false;
      });
    }
  }

  Future<void> _pickFromGallery() async {
    // Implement gallery pick
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Gallery picker coming soon!'),
      ),
    );
  }

  void _showScanHistory() {
    final scanHistory = SmartCameraService.instance.scanHistory;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Scan History',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: scanHistory.isEmpty
                  ? const Center(
                      child: Text('No scans yet'),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: scanHistory.length,
                      itemBuilder: (context, index) {
                        final scan = scanHistory[index];
                        return ListTile(
                          leading: const Icon(FontAwesomeIcons.utensils),
                          title: Text(scan.productName),
                          subtitle: Text(
                            '${scan.timestamp.day}/${scan.timestamp.month}/${scan.timestamp.year}',
                          ),
                          trailing: Text(
                            '${scan.nutrition.calories} cal',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveResult() async {
    if (_lastResult == null) return;
    
    // Add to scan history
    final scan = FoodScan(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      barcode: 'camera_${DateTime.now().millisecondsSinceEpoch}',
      productName: _lastResult!.foodName,
      brand: 'Camera Scan',
      category: 'Unknown',
      calories: _lastResult!.nutrition.calories,
      protein: _lastResult!.nutrition.protein,
      carbs: _lastResult!.nutrition.carbs,
      fat: _lastResult!.nutrition.fat,
      servingSize: '100g',
      timestamp: DateTime.now(),
      source: ScanSource.smartCamera,
    );
    
    await SmartCameraService.instance.addToHistory(scan);
    
    setState(() {
      _lastResult = null;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Result saved to history!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _dismissResult() {
    setState(() {
      _lastResult = null;
    });
  }

  Future<void> _toggleFlash() async {
    try {
      final cameraController = SmartCameraService.instance.cameraController;
      if (cameraController != null && cameraController.value.isInitialized) {
        if (cameraController.value.flashMode == FlashMode.off) {
          await cameraController.setFlashMode(FlashMode.torch);
        } else {
          await cameraController.setFlashMode(FlashMode.off);
        }
      }
    } catch (e) {
      print('Error toggling flash: $e');
    }
  }
}

enum CornerPosition {
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
}
