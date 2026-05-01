import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../services/theme_service.dart';
import '../services/auth_service.dart';
import '../services/settings_service.dart';
import '../services/gamification_service.dart';
import '../services/notification_service.dart';
import '../services/offline_service.dart';
import '../services/security_service.dart';
import '../services/advanced_analytics_service.dart';
import '../services/ai_recommendations_service.dart';
import '../services/goal_tracking_service.dart';
import '../services/performance_service.dart';
import '../services/social_service.dart';
import '../services/fitness_integration_service.dart';
import '../services/barcode_scanner_service.dart';
import '../services/allergy_scanner_service.dart';
import '../services/nutritionist_ai_service.dart';
import '../services/group_challenges_service.dart';
import '../services/smart_camera_service.dart';
import '../services/gesture_service.dart';

import 'interactive_dashboard.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotateAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeApp();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.5, curve: Curves.easeInOut),
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.5, curve: Curves.elasticOut),
    ));

    _rotateAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.5, 1.0, curve: Curves.easeInOut),
    ));

    _animationController.forward();
  }

  Future<void> _initializeApp() async {
    try {
      // Initialize all services
      await _initializeServices();
      
      // Navigate to main screen after initialization
      _navigateToMain();
    } catch (e) {
      print('Error initializing app: $e');
      // Still navigate even if there's an error
      _navigateToMain();
    }
  }

  Future<void> _initializeServices() async {
    // Core services
    await ThemeService.instance.loadTheme();
    await NotificationService.instance.initialize();
    await AuthService.instance.checkSession();
    await SettingsService.instance.loadSettings();
    
    // Advanced features
    await OfflineService.instance.initialize();
    await SecurityService.instance.initialize();
    await GamificationService.instance.initialize();
    await SocialService.instance.loadSocialData();
    await AdvancedAnalyticsService.instance.loadCachedAnalytics();
    await AIRecommendationsService.instance.loadCachedRecommendations();
    await GoalTrackingService.instance.loadGoals();
    await PerformanceService.instance.initialize();
    
    // Integrations
    await FitnessIntegrationService.instance.initialize();
    await BarcodeScannerService.instance.initialize();
    await AllergyScannerService.instance.initialize();
    await NutritionistAIService.instance.initialize();
    await GroupChallengesService.instance.initialize();
    await SmartCameraService.instance.initialize();
    
    // UI services
    // GestureService doesn't need initialization
  }

  void _navigateToMain() {
    // Delay for splash screen animation
    Future.delayed(const Duration(milliseconds: 3500), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const InteractiveDashboard(),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.primary.withOpacity(0.8),
              Theme.of(context).colorScheme.secondary.withOpacity(0.6),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo and icon animation
                AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return FadeTransition(
                      opacity: _fadeAnimation,
                      child: ScaleTransition(
                        scale: _scaleAnimation,
                        child: _buildLogo(),
                      ),
                    );
                  },
                ),
                
                const SizedBox(height: 40),
                
                // App name
                AnimatedBuilder(
                  animation: _fadeAnimation,
                  builder: (context, child) {
                    return FadeTransition(
                      opacity: _fadeAnimation,
                      child: Column(
                        children: [
                          Text(
                            'Smart Tracker',
                            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 32,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'AI-Powered Nutrition Tracking',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                
                const SizedBox(height: 60),
                
                // Loading animation
                AnimatedBuilder(
                  animation: _rotateAnimation,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: _rotateAnimation.value * 2 * 3.14159,
                      child: _buildLoadingIndicator(),
                    );
                  },
                ),
                
                const SizedBox(height: 40),
                
                // Features showcase
                AnimatedBuilder(
                  animation: _fadeAnimation,
                  builder: (context, child) {
                    return FadeTransition(
                      opacity: _fadeAnimation,
                      child: _buildFeaturesShowcase(),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.2),
        border: Border.all(
          color: Colors.white.withOpacity(0.5),
          width: 3,
        ),
      ),
      child: Icon(
        FontAwesomeIcons.utensils,
        color: Colors.white,
        size: 50,
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withOpacity(0.5),
          width: 2,
        ),
      ),
      child: Icon(
        FontAwesomeIcons.spinner,
        color: Colors.white,
        size: 20,
      ),
    );
  }

  Widget _buildFeaturesShowcase() {
    final features = [
      {'icon': FontAwesomeIcons.brain, 'label': 'AI Recognition'},
      {'icon': FontAwesomeIcons.chartLine, 'label': 'Advanced Analytics'},
      {'icon': FontAwesomeUsers.users, 'label': 'Social Features'},
      {'icon': FontAwesomeIcons.trophy, 'label': 'Gamification'},
      {'icon': FontAwesomeIcons.camera, 'label': 'Smart Camera'},
      {'icon': FontAwesomeComments.comments, 'label': 'AI Chat'},
    ];

    return Column(
      children: [
        Text(
          'Features',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Colors.white.withOpacity(0.9),
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          alignment: WrapAlignment.center,
          children: features.map((feature) {
            return _buildFeatureChip(feature['icon']!, feature['label']!);
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildFeatureChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: Colors.white,
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
