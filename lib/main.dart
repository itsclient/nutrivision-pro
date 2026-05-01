import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'services/theme_service.dart';
import 'services/notification_service.dart';
import 'services/offline_service.dart';
import 'services/security_service.dart';
import 'services/gamification_service.dart';
import 'services/social_service.dart';
import 'services/advanced_analytics_service.dart';
import 'services/ai_recommendations_service.dart';
import 'services/goal_tracking_service.dart';
import 'services/performance_service.dart';
import 'services/gesture_service.dart';
import 'services/fitness_integration_service.dart';
import 'services/barcode_scanner_service.dart';
import 'services/auth_service.dart';
import 'services/settings_service.dart';
import 'services/allergy_scanner_service.dart';
import 'services/nutritionist_ai_service.dart';
import 'services/group_challenges_service.dart';
import 'services/smart_camera_service.dart';

import 'screens/splash_screen.dart';
import 'screens/interactive_dashboard.dart';
import 'screens/recipe_discovery_feed.dart';
import 'screens/metabolic_calculator.dart';
import 'screens/allergy_scanner.dart';
import 'screens/ai_nutritionist_chat.dart';
import 'screens/group_challenges.dart';
import 'screens/smart_camera_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize services
  await _initializeServices();
  
  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  runApp(const SmartTrackerApp());
}

Future<void> _initializeServices() async {
  // Initialize Hive for local storage
  await Hive.initFlutter();
  
  // Initialize core services
  await ThemeService.instance.loadTheme();
  await NotificationService.instance.initialize();
  await OfflineService.instance.initialize();
  await SecurityService.instance.initialize();
  await GamificationService.instance.initialize();
  await SocialService.instance.loadSocialData();
  await AdvancedAnalyticsService.instance.loadCachedAnalytics();
  await AIRecommendationsService.instance.loadCachedRecommendations();
  await GoalTrackingService.instance.loadGoals();
  await PerformanceService.instance.initialize();
  await FitnessIntegrationService.instance.initialize();
  await BarcodeScannerService.instance.initialize();
  
  // Initialize new services
  await AllergyScannerService.instance.initialize();
  await NutritionistAIService.instance.initialize();
  await GroupChallengesService.instance.initialize();
  await SmartCameraService.instance.initialize();
  
  // Initialize auth and settings
  await AuthService.instance.checkSession();
  await SettingsService.instance.loadSettings();
}

class SmartTrackerApp extends StatelessWidget {
  const SmartTrackerApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeService.instance),
        ChangeNotifierProvider(create: (_) => NotificationService.instance),
        ChangeNotifierProvider(create: (_) => OfflineService.instance),
        ChangeNotifierProvider(create: (_) => SecurityService.instance),
        ChangeNotifierProvider(create: (_) => GamificationService.instance),
        ChangeNotifierProvider(create: (_) => SocialService.instance),
        ChangeNotifierProvider(create: (_) => AdvancedAnalyticsService.instance),
        ChangeNotifierProvider(create: (_) => AIRecommendationsService.instance),
        ChangeNotifierProvider(create: (_) => GoalTrackingService.instance),
        ChangeNotifierProvider(create: (_) => PerformanceService.instance),
        ChangeNotifierProvider(create: (_) => FitnessIntegrationService.instance),
        ChangeNotifierProvider(create: (_) => BarcodeScannerService.instance),
        ChangeNotifierProvider(create: (_) => AuthService.instance),
        ChangeNotifierProvider(create: (_) => SettingsService.instance),
        ChangeNotifierProvider(create: (_) => AllergyScannerService.instance),
        ChangeNotifierProvider(create: (_) => NutritionistAIService.instance),
        ChangeNotifierProvider(create: (_) => GroupChallengesService.instance),
        ChangeNotifierProvider(create: (_) => SmartCameraService.instance),
      ],
      child: Consumer<ThemeService>(
        builder: (context, themeService, child) {
          return MaterialApp(
            title: 'Smart Tracker',
            debugShowCheckedModeBanner: false,
            theme: themeService.getThemeData(context, false),
            darkTheme: themeService.getThemeData(context, true),
            themeMode: ThemeMode.system,
            home: const SplashScreen(),
            routes: {
              '/dashboard': (context) => const InteractiveDashboard(),
              '/recipes': (context) => const RecipeDiscoveryFeed(),
              '/metabolic': (context) => const MetabolicCalculator(),
              '/allergy': (context) => const AllergyScanner(),
              '/ai_chat': (context) => const AINutritionistChat(),
              '/challenges': (context) => const GroupChallenges(),
              '/smart_camera': (context) => const SmartCameraScreen(),
            },
          );
        },
      ),
    );
  }
}
