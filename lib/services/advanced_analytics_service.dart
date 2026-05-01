import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import 'api_config.dart';
import 'auth_service.dart';

class AdvancedAnalyticsService {
  static final AdvancedAnalyticsService instance = AdvancedAnalyticsService._init();
  AdvancedAnalyticsService._init();

  static const String _baseUrl = ApiConfig.baseUrl;
  static const String _cacheKey = 'analytics_cache';
  static const String _goalsKey = 'user_goals';

  List<DailyStats> _dailyStats = [];
  List<WeeklyStats> _weeklyStats = [];
  List<MonthlyStats> _monthlyStats = [];
  NutritionGoals _goals = NutritionGoals();
  DateTime? _lastUpdated;

  List<DailyStats> get dailyStats => _dailyStats;
  List<WeeklyStats> get weeklyStats => _weeklyStats;
  List<MonthlyStats> get monthlyStats => _monthlyStats;
  NutritionGoals get goals => _goals;
  DateTime? get lastUpdated => _lastUpdated;

  // Load cached analytics data
  Future<void> loadCachedAnalytics() async {
    final prefs = await SharedPreferences.getInstance();
    final cacheJson = prefs.getString(_cacheKey);
    
    if (cacheJson != null) {
      final cache = jsonDecode(cacheJson) as Map<String, dynamic>;
      _lastUpdated = DateTime.parse(cache['last_updated']);
      
      _dailyStats = (cache['daily_stats'] as List)
          .map((e) => DailyStats.fromJson(e))
          .toList();
      
      _weeklyStats = (cache['weekly_stats'] as List)
          .map((e) => WeeklyStats.fromJson(e))
          .toList();
      
      _monthlyStats = (cache['monthly_stats'] as List)
          .map((e) => MonthlyStats.fromJson(e))
          .toList();
    }

    // Load goals
    final goalsJson = prefs.getString(_goalsKey);
    if (goalsJson != null) {
      _goals = NutritionGoals.fromJson(jsonDecode(goalsJson));
    }
  }

  // Save analytics to cache
  Future<void> _saveAnalyticsCache() async {
    final prefs = await SharedPreferences.getInstance();
    
    final cache = {
      'last_updated': DateTime.now().toIso8601String(),
      'daily_stats': _dailyStats.map((e) => e.toJson()).toList(),
      'weekly_stats': _weeklyStats.map((e) => e.toJson()).toList(),
      'monthly_stats': _monthlyStats.map((e) => e.toJson()).toList(),
    };
    
    await prefs.setString(_cacheKey, jsonEncode(cache));
    await prefs.setString(_goalsKey, jsonEncode(_goals.toJson()));
  }

  // Fetch comprehensive analytics from server
  Future<bool> fetchAnalytics({bool forceRefresh = false}) async {
    final currentUser = AuthService.instance.currentUser;
    if (currentUser == null) return false;

    // Check if we need to refresh (cache is older than 1 hour or force refresh)
    if (!forceRefresh && 
        _lastUpdated != null && 
        DateTime.now().difference(_lastUpdated!).inHours < 1) {
      return true;
    }

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/analytics/comprehensive/${currentUser.email}'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        
        _dailyStats = (data['daily_stats'] as List)
            .map((e) => DailyStats.fromJson(e))
            .toList();
        
        _weeklyStats = (data['weekly_stats'] as List)
            .map((e) => WeeklyStats.fromJson(e))
            .toList();
        
        _monthlyStats = (data['monthly_stats'] as List)
            .map((e) => MonthlyStats.fromJson(e))
            .toList();
        
        _lastUpdated = DateTime.now();
        await _saveAnalyticsCache();
        return true;
      }
    } catch (e) {
      print('Error fetching analytics: $e');
    }
    return false;
  }

  // Get chart data for daily calories
  List<FlSpot> getDailyCaloriesChart({int days = 30}) {
    final recentStats = _dailyStats.take(days).toList();
    return recentStats.asMap().entries.map((entry) {
      return FlSpot(
        entry.key.toDouble(),
        entry.value.totalCalories.toDouble(),
      );
    }).toList();
  }

  // Get chart data for nutrition breakdown
  Map<String, double> getNutritionBreakdown({int days = 7}) {
    final recentStats = _dailyStats.take(days).toList();
    
    final totalProtein = recentStats.fold<int>(0, (sum, stat) => sum + stat.totalProtein);
    final totalCarbs = recentStats.fold<int>(0, (sum, stat) => sum + stat.totalCarbs);
    final totalFat = recentStats.fold<int>(0, (sum, stat) => sum + stat.totalFat);
    
    final total = totalProtein + totalCarbs + totalFat;
    
    if (total == 0) return {};
    
    return {
      'Protein': (totalProtein / total) * 100,
      'Carbs': (totalCarbs / total) * 100,
      'Fat': (totalFat / total) * 100,
    };
  }

  // Get weekly trend data
  List<FlSpot> getWeeklyTrendChart() {
    return _weeklyStats.asMap().entries.map((entry) {
      return FlSpot(
        entry.key.toDouble(),
        entry.value.avgCalories.toDouble(),
      );
    }).toList();
  }

  // Get category distribution
  Map<String, int> getCategoryDistribution({int days = 30}) {
    final recentStats = _dailyStats.take(days).toList();
    final categoryCount = <String, int>{};
    
    for (final stat in recentStats) {
      for (final category in stat.topCategories.keys) {
        categoryCount[category] = (categoryCount[category] ?? 0) + stat.topCategories[category]!;
      }
    }
    
    return categoryCount;
  }

  // Get goal progress
  double getGoalProgress(String goalType) {
    final todayStats = _dailyStats.isNotEmpty ? _dailyStats.first : null;
    if (todayStats == null) return 0.0;
    
    switch (goalType) {
      case 'calories':
        return (todayStats.totalCalories / _goals.dailyCalories).clamp(0.0, 2.0);
      case 'protein':
        return (todayStats.totalProtein / _goals.dailyProtein).clamp(0.0, 2.0);
      case 'scans':
        return (todayStats.scanCount / _goals.dailyScans).clamp(0.0, 2.0);
      default:
        return 0.0;
    }
  }

  // Get insights and recommendations
  List<String> getInsights() {
    final insights = <String>[];
    
    if (_dailyStats.isEmpty) return insights;
    
    final recentWeek = _dailyStats.take(7).toList();
    final avgCalories = recentWeek.fold<int>(0, (sum, stat) => sum + stat.totalCalories) / recentWeek.length;
    
    // Calorie insights
    if (avgCalories > _goals.dailyCalories * 1.2) {
      insights.add('Your average calorie intake is 20% above your goal. Consider lighter dessert options.');
    } else if (avgCalories < _goals.dailyCalories * 0.8) {
      insights.add('You\'re staying well under your calorie goal! Great self-control.');
    }
    
    // Streak insights
    final currentStreak = _getCurrentStreak();
    if (currentStreak >= 7) {
      insights.add('Amazing! You\'ve maintained a $currentStreak-day streak. Keep it up!');
    } else if (currentStreak >= 3) {
      insights.add('Good progress on your $currentStreak-day streak. You\'re building a healthy habit!');
    }
    
    // Category insights
    final topCategory = _getTopCategory();
    if (topCategory != null) {
      insights.add('Your favorite category is "$topCategory". Try exploring other categories for variety!');
    }
    
    return insights;
  }

  int _getCurrentStreak() {
    int streak = 0;
    for (final stat in _dailyStats) {
      if (stat.scanCount > 0) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  String? _getTopCategory() {
    final categoryCount = <String, int>{};
    
    for (final stat in _dailyStats) {
      for (final category in stat.topCategories.keys) {
        categoryCount[category] = (categoryCount[category] ?? 0) + stat.topCategories[category]!;
      }
    }
    
    if (categoryCount.isEmpty) return null;
    
    return categoryCount.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }

  // Update goals
  Future<void> updateGoals(NutritionGoals newGoals) async {
    _goals = newGoals;
    await _saveAnalyticsCache();
  }

  // Export data as JSON
  String exportData({String format = 'json'}) {
    final exportData = {
      'export_date': DateTime.now().toIso8601String(),
      'daily_stats': _dailyStats.map((e) => e.toJson()).toList(),
      'weekly_stats': _weeklyStats.map((e) => e.toJson()).toList(),
      'monthly_stats': _monthlyStats.map((e) => e.toJson()).toList(),
      'goals': _goals.toJson(),
    };
    
    return jsonEncode(exportData);
  }

  // Get summary statistics
  Map<String, dynamic> getSummaryStats() {
    if (_dailyStats.isEmpty) return {};
    
    final totalDays = _dailyStats.length;
    final totalScans = _dailyStats.fold<int>(0, (sum, stat) => sum + stat.scanCount);
    final totalCalories = _dailyStats.fold<int>(0, (sum, stat) => sum + stat.totalCalories);
    final avgCalories = totalCalories / totalDays;
    
    final bestDay = _dailyStats.reduce((a, b) => 
        a.totalCalories > b.totalCalories ? a : b);
    
    return {
      'total_days': totalDays,
      'total_scans': totalScans,
      'total_calories': totalCalories,
      'avg_daily_calories': avgCalories.round(),
      'best_day': {
        'date': bestDay.date,
        'calories': bestDay.totalCalories,
        'scans': bestDay.scanCount,
      },
      'current_streak': _getCurrentStreak(),
    };
  }
}

// Data models
class DailyStats {
  final DateTime date;
  final int scanCount;
  final int totalCalories;
  final int totalProtein;
  final int totalCarbs;
  final int totalFat;
  final Map<String, int> topCategories;
  final double avgConfidence;

  DailyStats({
    required this.date,
    required this.scanCount,
    required this.totalCalories,
    required this.totalProtein,
    required this.totalCarbs,
    required this.totalFat,
    required this.topCategories,
    required this.avgConfidence,
  });

  factory DailyStats.fromJson(Map<String, dynamic> json) {
    return DailyStats(
      date: DateTime.parse(json['date']),
      scanCount: json['scan_count'] ?? 0,
      totalCalories: json['total_calories'] ?? 0,
      totalProtein: json['total_protein'] ?? 0,
      totalCarbs: json['total_carbs'] ?? 0,
      totalFat: json['total_fat'] ?? 0,
      topCategories: Map<String, int>.from(json['top_categories'] ?? {}),
      avgConfidence: (json['avg_confidence'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'scan_count': scanCount,
      'total_calories': totalCalories,
      'total_protein': totalProtein,
      'total_carbs': totalCarbs,
      'total_fat': totalFat,
      'top_categories': topCategories,
      'avg_confidence': avgConfidence,
    };
  }
}

class WeeklyStats {
  final DateTime weekStart;
  final int totalScans;
  final int totalCalories;
  final double avgCalories;
  final int avgDailyScans;
  final Map<String, int> categoryBreakdown;

  WeeklyStats({
    required this.weekStart,
    required this.totalScans,
    required this.totalCalories,
    required this.avgCalories,
    required this.avgDailyScans,
    required this.categoryBreakdown,
  });

  factory WeeklyStats.fromJson(Map<String, dynamic> json) {
    return WeeklyStats(
      weekStart: DateTime.parse(json['week_start']),
      totalScans: json['total_scans'] ?? 0,
      totalCalories: json['total_calories'] ?? 0,
      avgCalories: (json['avg_calories'] ?? 0.0).toDouble(),
      avgDailyScans: json['avg_daily_scans'] ?? 0,
      categoryBreakdown: Map<String, int>.from(json['category_breakdown'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'week_start': weekStart.toIso8601String(),
      'total_scans': totalScans,
      'total_calories': totalCalories,
      'avg_calories': avgCalories,
      'avg_daily_scans': avgDailyScans,
      'category_breakdown': categoryBreakdown,
    };
  }
}

class MonthlyStats {
  final DateTime month;
  final int totalScans;
  final int totalCalories;
  final double avgDailyCalories;
  final int activeDays;
  final Map<String, int> topCategories;

  MonthlyStats({
    required this.month,
    required this.totalScans,
    required this.totalCalories,
    required this.avgDailyCalories,
    required this.activeDays,
    required this.topCategories,
  });

  factory MonthlyStats.fromJson(Map<String, dynamic> json) {
    return MonthlyStats(
      month: DateTime.parse(json['month']),
      totalScans: json['total_scans'] ?? 0,
      totalCalories: json['total_calories'] ?? 0,
      avgDailyCalories: (json['avg_daily_calories'] ?? 0.0).toDouble(),
      activeDays: json['active_days'] ?? 0,
      topCategories: Map<String, int>.from(json['top_categories'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'month': month.toIso8601String(),
      'total_scans': totalScans,
      'total_calories': totalCalories,
      'avg_daily_calories': avgDailyCalories,
      'active_days': activeDays,
      'top_categories': topCategories,
    };
  }
}

class NutritionGoals {
  int dailyCalories = 2000;
  double dailyProtein = 50.0;
  int dailyScans = 3;
  int maxCaloriesPerDessert = 500;
  List<String> preferredCategories = [];

  NutritionGoals({
    this.dailyCalories = 2000,
    this.dailyProtein = 50.0,
    this.dailyScans = 3,
    this.maxCaloriesPerDessert = 500,
    this.preferredCategories = const [],
  });

  factory NutritionGoals.fromJson(Map<String, dynamic> json) {
    return NutritionGoals(
      dailyCalories: json['daily_calories'] ?? 2000,
      dailyProtein: (json['daily_protein'] ?? 50.0).toDouble(),
      dailyScans: json['daily_scans'] ?? 3,
      maxCaloriesPerDessert: json['max_calories_per_dessert'] ?? 500,
      preferredCategories: List<String>.from(json['preferred_categories'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'daily_calories': dailyCalories,
      'daily_protein': dailyProtein,
      'daily_scans': dailyScans,
      'max_calories_per_dessert': maxCaloriesPerDessert,
      'preferred_categories': preferredCategories,
    };
  }
}
