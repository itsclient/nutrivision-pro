import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'ai_config.dart';
import 'advanced_analytics_service.dart';
import 'auth_service.dart';

class AIRecommendationsService {
  static final AIRecommendationsService instance = AIRecommendationsService._init();
  AIRecommendationsService._init();

  static const String _cacheKey = 'ai_recommendations_cache';
  static const String _userPreferencesKey = 'ai_user_preferences';
  
  List<DessertRecommendation> _recommendations = [];
  List<HealthyAlternative> _alternatives = [];
  MealPlan? _currentMealPlan;
  UserPreferences _preferences = UserPreferences();
  DateTime? _lastUpdated;

  List<DessertRecommendation> get recommendations => _recommendations;
  List<HealthyAlternative> get alternatives => _alternatives;
  MealPlan? get currentMealPlan => _currentMealPlan;
  UserPreferences get preferences => _preferences;
  DateTime? get lastUpdated => _lastUpdated;

  // Load cached recommendations
  Future<void> loadCachedRecommendations() async {
    final prefs = await SharedPreferences.getInstance();
    final cacheJson = prefs.getString(_cacheKey);
    
    if (cacheJson != null) {
      final cache = jsonDecode(cacheJson) as Map<String, dynamic>;
      _lastUpdated = DateTime.parse(cache['last_updated']);
      
      _recommendations = (cache['recommendations'] as List)
          .map((e) => DessertRecommendation.fromJson(e))
          .toList();
      
      _alternatives = (cache['alternatives'] as List)
          .map((e) => HealthyAlternative.fromJson(e))
          .toList();
      
      if (cache['meal_plan'] != null) {
        _currentMealPlan = MealPlan.fromJson(cache['meal_plan']);
      }
    }

    // Load user preferences
    final prefsJson = prefs.getString(_userPreferencesKey);
    if (prefsJson != null) {
      _preferences = UserPreferences.fromJson(jsonDecode(prefsJson));
    }
  }

  // Save recommendations to cache
  Future<void> _saveRecommendationsCache() async {
    final prefs = await SharedPreferences.getInstance();
    
    final cache = {
      'last_updated': DateTime.now().toIso8601String(),
      'recommendations': _recommendations.map((e) => e.toJson()).toList(),
      'alternatives': _alternatives.map((e) => e.toJson()).toList(),
      'meal_plan': _currentMealPlan?.toJson(),
    };
    
    await prefs.setString(_cacheKey, jsonEncode(cache));
    await prefs.setString(_userPreferencesKey, jsonEncode(_preferences.toJson()));
  }

  // Generate personalized recommendations
  Future<bool> generateRecommendations({bool forceRefresh = false}) async {
    // Check if we need to refresh (cache is older than 6 hours or force refresh)
    if (!forceRefresh && 
        _lastUpdated != null && 
        DateTime.now().difference(_lastUpdated!).inHours < 6) {
      return true;
    }

    try {
      // Get user's analytics data
      await AdvancedAnalyticsService.instance.fetchAnalytics();
      final userGoals = AdvancedAnalyticsService.instance.goals;
      final recentStats = AdvancedAnalyticsService.instance.dailyStats;

      // Generate recommendations based on user data
      _recommendations = await _generateDessertRecommendations(userGoals, recentStats);
      _alternatives = await _generateHealthyAlternatives(recentStats);
      _currentMealPlan = await _generateMealPlan(userGoals);

      _lastUpdated = DateTime.now();
      await _saveRecommendationsCache();
      return true;
    } catch (e) {
      print('Error generating recommendations: $e');
      return false;
    }
  }

  Future<List<DessertRecommendation>> _generateDessertRecommendations(
    NutritionGoals goals,
    List<DailyStats> recentStats,
  ) async {
    final recommendations = <DessertRecommendation>[];
    
    // Analyze user preferences from recent scans
    final favoriteCategories = _getFavoriteCategories(recentStats);
    final avgCaloriesPerDessert = _getAvgCaloriesPerDessert(recentStats);
    
    // Generate recommendations based on different strategies
    recommendations.addAll(await _getLowCalorieOptions(goals, favoriteCategories));
    recommendations.addAll(await _getHighProteinOptions(goals, favoriteCategories));
    recommendations.addAll(await _getTrendingOptions());
    recommendations.addAll(await _getSeasonalOptions());
    
    // Sort by relevance score
    recommendations.sort((a, b) => b.relevanceScore.compareTo(a.relevanceScore));
    
    return recommendations.take(10).toList();
  }

  Future<List<DessertRecommendation>> _getLowCalorieOptions(
    NutritionGoals goals,
    List<String> favoriteCategories,
  ) async {
    final prompt = '''
    Generate 3 low-calorie dessert recommendations under ${goals.maxCaloriesPerDessert} calories.
    Focus on these categories: ${favoriteCategories.join(', ')}.
    
    For each recommendation, provide:
    - Name
    - Estimated calories
    - Protein content
    - Category
    - Brief description
    - Why it's a good choice
    ''';

    final response = await _callAI(prompt);
    return _parseDessertRecommendations(response, 'low_calorie');
  }

  Future<List<DessertRecommendation>> _getHighProteinOptions(
    NutritionGoals goals,
    List<String> favoriteCategories,
  ) async {
    final prompt = '''
    Generate 3 high-protein dessert recommendations with at least ${(goals.dailyProtein / 3).round()}g protein.
    Focus on these categories: ${favoriteCategories.join(', ')}.
    
    For each recommendation, provide:
    - Name
    - Estimated calories
    - Protein content
    - Category
    - Brief description
    - Why it's a good choice for protein
    ''';

    final response = await _callAI(prompt);
    return _parseDessertRecommendations(response, 'high_protein');
  }

  Future<List<DessertRecommendation>> _getTrendingOptions() async {
    final prompt = '''
    Generate 3 trending dessert recommendations that are popular right now.
    
    For each recommendation, provide:
    - Name
    - Estimated calories
    - Protein content
    - Category
    - Brief description
    - Why it's trending
    ''';

    final response = await _callAI(prompt);
    return _parseDessertRecommendations(response, 'trending');
  }

  Future<List<DessertRecommendation>> _getSeasonalOptions() async {
    final currentMonth = DateTime.now().month;
    final season = _getSeason(currentMonth);
    
    final prompt = '''
    Generate 3 seasonal dessert recommendations perfect for $season.
    
    For each recommendation, provide:
    - Name
    - Estimated calories
    - Protein content
    - Category
    - Brief description
    - Why it's perfect for $season
    ''';

    final response = await _callAI(prompt);
    return _parseDessertRecommendations(response, 'seasonal');
  }

  Future<List<HealthyAlternative>> _generateHealthyAlternatives(List<DailyStats> recentStats) async {
    final alternatives = <HealthyAlternative>[];
    
    // Get user's most frequently scanned high-calorie desserts
    final highCalorieScans = _getHighCalorieScans(recentStats);
    
    for (final scan in highCalorieScans.take(5)) {
      final prompt = '''
      Suggest 2 healthy alternatives for "$scan" that have at least 30% fewer calories.
      
      For each alternative, provide:
      - Name
      - Estimated calories (must be less than ${scan.calories * 0.7})
      - Brief description
      - Why it's a healthier choice
      - Taste comparison
      ''';

      final response = await _callAI(prompt);
      alternatives.addAll(_parseHealthyAlternatives(response, scan.name));
    }
    
    return alternatives;
  }

  Future<MealPlan?> _generateMealPlan(NutritionGoals goals) async {
    final prompt = '''
    Create a 1-day dessert meal plan that stays within ${goals.dailyCalories} calories
    and includes at least ${goals.dailyProtein}g protein. Include ${goals.dailyScans} desserts.
    
    For each meal/snack, provide:
    - Time of day
    - Dessert name
    - Calories
    - Protein
    - Brief description
    - Preparation notes
    ''';

    final response = await _callAI(prompt);
    return _parseMealPlan(response);
  }

  Future<String> _callAI(String prompt) async {
    if (AIConfig.groqApiKey == 'YOUR_GROQ_API_KEY_HERE') {
      // Return mock response if no API key
      return _generateMockResponse(prompt);
    }

    try {
      final response = await http.post(
        Uri.parse('${AIConfig.groqBaseUrl}/chat/completions'),
        headers: {
          'Authorization': 'Bearer ${AIConfig.groqApiKey}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': AIConfig.groqModel,
          'messages': [
            {
              'role': 'system',
              'content': 'You are a nutrition and dessert expert. Provide accurate, helpful recommendations in JSON format.',
            },
            {
              'role': 'user',
              'content': prompt,
            },
          ],
          'temperature': 0.7,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'];
      }
    } catch (e) {
      print('AI API call failed: $e');
    }

    return _generateMockResponse(prompt);
  }

  String _generateMockResponse(String prompt) {
    // Generate reasonable mock responses based on the prompt
    if (prompt.contains('low-calorie')) {
      return '''
      [
        {
          "name": "Greek Yogurt Parfait",
          "calories": 120,
          "protein": 15,
          "category": "Yogurt",
          "description": "Layered Greek yogurt with berries and a drizzle of honey",
          "reason": "High protein, low calories, and satisfies sweet cravings"
        },
        {
          "name": "Chocolate Avocado Mousse",
          "calories": 150,
          "protein": 4,
          "category": "Mousse",
          "description": "Creamy mousse made with avocado, cocoa, and natural sweetener",
          "reason": "Healthy fats, rich chocolate flavor, minimal calories"
        },
        {
          "name": "Berry Sorbet",
          "calories": 80,
          "protein": 1,
          "category": "Sorbet",
          "description": "Refreshing frozen berry blend with no added sugar",
          "reason": "Virtually fat-free, natural sweetness, hydrating"
        }
      ]
      ''';
    } else if (prompt.contains('healthy alternatives')) {
      return '''
      [
        {
          "name": "Baked Apple with Cinnamon",
          "calories": 95,
          "description": "Warm baked apple sprinkled with cinnamon and a touch of honey",
          "reason": "Natural sweetness, fiber-rich, much lower calories",
          "taste_comparison": "Same cinnamon-spice flavor, more natural sweetness"
        },
        {
          "name": "Chia Seed Pudding",
          "calories": 110,
          "description": "Creamy pudding made with chia seeds, almond milk, and vanilla",
          "reason": "High fiber, omega-3s, satisfying texture",
          "taste_comparison": "Similar creaminess with added nutritional benefits"
        }
      ]
      ''';
    } else if (prompt.contains('meal plan')) {
      return '''
      {
        "date": "${DateTime.now().toIso8601String().split('T')[0]}",
        "totalCalories": 1850,
        "totalProtein": 52,
        "meals": [
          {
            "time": "09:00",
            "name": "Protein Smoothie Bowl",
            "calories": 280,
            "protein": 18,
            "description": "Thick smoothie bowl with protein powder, berries, and granola",
            "prep_notes": "Blend frozen berries, protein powder, and milk. Top with granola."
          },
          {
            "time": "14:00",
            "name": "Greek Yogurt with Nuts",
            "calories": 200,
            "protein": 15,
            "description": "Creamy Greek yogurt with mixed nuts and seeds",
            "prep_notes": "Top plain Greek yogurt with almonds, walnuts, and chia seeds."
          },
          {
            "time": "19:00",
            "name": "Dark Chocolate Avocado Mousse",
            "calories": 180,
            "protein": 4,
            "description": "Rich chocolate mousse made with avocado",
            "prep_notes": "Blend avocado, cocoa powder, and sweetener until smooth."
          }
        ]
      }
      ''';
    }
    
    return '{"recommendations": []}';
  }

  List<DessertRecommendation> _parseDessertRecommendations(String response, String type) {
    try {
      final List<dynamic> data = jsonDecode(response);
      return data.map((item) => DessertRecommendation.fromJson(item, type)).toList();
    } catch (e) {
      print('Error parsing dessert recommendations: $e');
      return [];
    }
  }

  List<HealthyAlternative> _parseHealthyAlternatives(String response, String originalDessert) {
    try {
      final List<dynamic> data = jsonDecode(response);
      return data.map((item) => HealthyAlternative.fromJson(item, originalDessert)).toList();
    } catch (e) {
      print('Error parsing healthy alternatives: $e');
      return [];
    }
  }

  MealPlan? _parseMealPlan(String response) {
    try {
      final data = jsonDecode(response);
      return MealPlan.fromJson(data);
    } catch (e) {
      print('Error parsing meal plan: $e');
      return null;
    }
  }

  List<String> _getFavoriteCategories(List<DailyStats> recentStats) {
    final categoryCount = <String, int>{};
    
    for (final stat in recentStats) {
      for (final category in stat.topCategories.keys) {
        categoryCount[category] = (categoryCount[category] ?? 0) + stat.topCategories[category]!;
      }
    }
    
    return categoryCount.entries
        .toList()
        ..sort((a, b) => b.value.compareTo(a.value))
        ..map((e) => e.key)
        .toList()
        .take(3)
        .toList();
  }

  double _getAvgCaloriesPerDessert(List<DailyStats> recentStats) {
    if (recentStats.isEmpty) return 0;
    
    final totalCalories = recentStats.fold<int>(0, (sum, stat) => sum + stat.totalCalories);
    final totalScans = recentStats.fold<int>(0, (sum, stat) => sum + stat.scanCount);
    
    return totalScans > 0 ? totalCalories / totalScans : 0;
  }

  List<Map<String, dynamic>> _getHighCalorieScans(List<DailyStats> recentStats) {
    final highCalorieScans = <Map<String, dynamic>>[];
    
    // Mock high-calorie scans (in real app, this would come from actual scan data)
    highCalorieScans.addAll([
      {'name': 'Chocolate Cake', 'calories': 350},
      {'name': 'Ice Cream Sundae', 'calories': 420},
      {'name': 'Cheesecake', 'calories': 380},
      {'name': 'Tiramisu', 'calories': 290},
      {'name': 'Brownie ala Mode', 'calories': 450},
    ]);
    
    return highCalorieScans;
  }

  String _getSeason(int month) {
    switch (month) {
      case 12:
      case 1:
      case 2:
        return 'Winter';
      case 3:
      case 4:
      case 5:
        return 'Spring';
      case 6:
      case 7:
      case 8:
        return 'Summer';
      case 9:
      case 10:
      case 11:
        return 'Fall';
      default:
        return 'All seasons';
    }
  }

  // Update user preferences
  Future<void> updatePreferences(UserPreferences newPreferences) async {
    _preferences = newPreferences;
    await _saveRecommendationsCache();
    
    // Regenerate recommendations with new preferences
    await generateRecommendations(forceRefresh: true);
  }

  // Get personalized insights
  List<String> getPersonalizedInsights() {
    final insights = <String>[];
    
    if (_recommendations.isNotEmpty) {
      final topRecommendation = _recommendations.first;
      insights.add('Based on your preferences, try "${topRecommendation.name}" - it\'s a perfect match!');
    }
    
    if (_alternatives.isNotEmpty) {
      insights.add('Found ${_alternatives.length} healthier alternatives to your favorite treats.');
    }
    
    if (_currentMealPlan != null) {
      insights.add('We\'ve created a personalized meal plan that fits your goals perfectly.');
    }
    
    return insights;
  }
}

// Data models
class DessertRecommendation {
  final String name;
  final int calories;
  final double protein;
  final String category;
  final String description;
  final String reason;
  final String type;
  final double relevanceScore;

  DessertRecommendation({
    required this.name,
    required this.calories,
    required this.protein,
    required this.category,
    required this.description,
    required this.reason,
    required this.type,
    this.relevanceScore = 0.0,
  });

  factory DessertRecommendation.fromJson(Map<String, dynamic> json, String type) {
    return DessertRecommendation(
      name: json['name'] ?? '',
      calories: json['calories'] ?? 0,
      protein: (json['protein'] ?? 0.0).toDouble(),
      category: json['category'] ?? '',
      description: json['description'] ?? '',
      reason: json['reason'] ?? '',
      type: type,
      relevanceScore: _calculateRelevanceScore(json, type),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'calories': calories,
      'protein': protein,
      'category': category,
      'description': description,
      'reason': reason,
      'type': type,
      'relevanceScore': relevanceScore,
    };
  }

  static double _calculateRelevanceScore(Map<String, dynamic> json, String type) {
    double score = Random().nextDouble() * 0.3; // Base randomness
    
    // Adjust score based on type
    switch (type) {
      case 'low_calorie':
        score += (json['calories'] ?? 0) < 200 ? 0.4 : 0.2;
        break;
      case 'high_protein':
        score += (json['protein'] ?? 0) > 10 ? 0.4 : 0.2;
        break;
      case 'trending':
        score += 0.3;
        break;
      case 'seasonal':
        score += 0.3;
        break;
    }
    
    return score.clamp(0.0, 1.0);
  }
}

class HealthyAlternative {
  final String name;
  final int calories;
  final String description;
  final String reason;
  final String tasteComparison;
  final String originalDessert;
  final double calorieReduction;

  HealthyAlternative({
    required this.name,
    required this.calories,
    required this.description,
    required this.reason,
    required this.tasteComparison,
    required this.originalDessert,
    required this.calorieReduction,
  });

  factory HealthyAlternative.fromJson(Map<String, dynamic> json, String originalDessert) {
    return HealthyAlternative(
      name: json['name'] ?? '',
      calories: json['calories'] ?? 0,
      description: json['description'] ?? '',
      reason: json['reason'] ?? '',
      tasteComparison: json['taste_comparison'] ?? '',
      originalDessert: originalDessert,
      calorieReduction: 0.3, // Mock 30% reduction
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'calories': calories,
      'description': description,
      'reason': reason,
      'taste_comparison': tasteComparison,
      'original_dessert': originalDessert,
      'calorie_reduction': calorieReduction,
    };
  }
}

class MealPlan {
  final String date;
  final int totalCalories;
  final double totalProtein;
  final List<MealPlanMeal> meals;

  MealPlan({
    required this.date,
    required this.totalCalories,
    required this.totalProtein,
    required this.meals,
  });

  factory MealPlan.fromJson(Map<String, dynamic> json) {
    return MealPlan(
      date: json['date'] ?? '',
      totalCalories: json['totalCalories'] ?? 0,
      totalProtein: (json['totalProtein'] ?? 0.0).toDouble(),
      meals: (json['meals'] as List)
          .map((e) => MealPlanMeal.fromJson(e))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'totalCalories': totalCalories,
      'totalProtein': totalProtein,
      'meals': meals.map((e) => e.toJson()).toList(),
    };
  }
}

class MealPlanMeal {
  final String time;
  final String name;
  final int calories;
  final double protein;
  final String description;
  final String prepNotes;

  MealPlanMeal({
    required this.time,
    required this.name,
    required this.calories,
    required this.protein,
    required this.description,
    required this.prepNotes,
  });

  factory MealPlanMeal.fromJson(Map<String, dynamic> json) {
    return MealPlanMeal(
      time: json['time'] ?? '',
      name: json['name'] ?? '',
      calories: json['calories'] ?? 0,
      protein: (json['protein'] ?? 0.0).toDouble(),
      description: json['description'] ?? '',
      prepNotes: json['prep_notes'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'time': time,
      'name': name,
      'calories': calories,
      'protein': protein,
      'description': description,
      'prep_notes': prepNotes,
    };
  }
}

class UserPreferences {
  List<String> favoriteCategories = [];
  List<String> dislikedIngredients = [];
  List<String> dietaryRestrictions = [];
  int maxCaloriesPerDessert = 300;
  double minProteinPerDessert = 5.0;
  bool preferHealthyOptions = true;
  bool likeChocolate = true;
  bool likeFruit = true;
  bool likeNuts = true;

  UserPreferences({
    this.favoriteCategories = const [],
    this.dislikedIngredients = const [],
    this.dietaryRestrictions = const [],
    this.maxCaloriesPerDessert = 300,
    this.minProteinPerDessert = 5.0,
    this.preferHealthyOptions = true,
    this.likeChocolate = true,
    this.likeFruit = true,
    this.likeNuts = true,
  });

  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    return UserPreferences(
      favoriteCategories: List<String>.from(json['favoriteCategories'] ?? []),
      dislikedIngredients: List<String>.from(json['dislikedIngredients'] ?? []),
      dietaryRestrictions: List<String>.from(json['dietaryRestrictions'] ?? []),
      maxCaloriesPerDessert: json['maxCaloriesPerDessert'] ?? 300,
      minProteinPerDessert: (json['minProteinPerDessert'] ?? 5.0).toDouble(),
      preferHealthyOptions: json['preferHealthyOptions'] ?? true,
      likeChocolate: json['likeChocolate'] ?? true,
      likeFruit: json['likeFruit'] ?? true,
      likeNuts: json['likeNuts'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'favoriteCategories': favoriteCategories,
      'dislikedIngredients': dislikedIngredients,
      'dietaryRestrictions': dietaryRestrictions,
      'maxCaloriesPerDessert': maxCaloriesPerDessert,
      'minProteinPerDessert': minProteinPerDessert,
      'preferHealthyOptions': preferHealthyOptions,
      'likeChocolate': likeChocolate,
      'likeFruit': likeFruit,
      'likeNuts': likeNuts,
    };
  }
}
