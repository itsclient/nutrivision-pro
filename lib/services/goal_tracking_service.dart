import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'auth_service.dart';
import 'notification_service.dart';
import 'settings_service.dart';

class GoalTrackingService extends ChangeNotifier {
  static final GoalTrackingService instance = GoalTrackingService._init();
  GoalTrackingService._init();

  static const String _goalsKey = 'comprehensive_goals';
  static const String _goalHistoryKey = 'goal_history';
  static const String _achievementsKey = 'goal_achievements';

  List<Goal> _activeGoals = [];
  List<GoalHistory> _goalHistory = [];
  List<Achievement> _achievements = [];
  Map<String, GoalProgress> _progress = {};

  List<Goal> get activeGoals => _activeGoals;
  List<GoalHistory> get goalHistory => _goalHistory;
  List<Achievement> get achievements => _achievements;
  Map<String, GoalProgress> get progress => _progress;

  // Load all goal data
  Future<void> loadGoals() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load active goals
    final goalsJson = prefs.getString(_goalsKey);
    if (goalsJson != null) {
      final goalsList = jsonDecode(goalsJson) as List;
      _activeGoals = goalsList.map((e) => Goal.fromJson(e)).toList();
    }

    // Load goal history
    final historyJson = prefs.getString(_goalHistoryKey);
    if (historyJson != null) {
      final historyList = jsonDecode(historyJson) as List;
      _goalHistory = historyList.map((e) => GoalHistory.fromJson(e)).toList();
    }

    // Load achievements
    final achievementsJson = prefs.getString(_achievementsKey);
    if (achievementsJson != null) {
      final achievementsList = jsonDecode(achievementsJson) as List;
      _achievements = achievementsList.map((e) => Achievement.fromJson(e)).toList();
    }

    // Calculate current progress
    await _calculateProgress();
    notifyListeners();
  }

  // Save all goal data
  Future<void> _saveGoals() async {
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.setString(_goalsKey, jsonEncode(_activeGoals.map((e) => e.toJson()).toList()));
    await prefs.setString(_goalHistoryKey, jsonEncode(_goalHistory.map((e) => e.toJson()).toList()));
    await prefs.setString(_achievementsKey, jsonEncode(_achievements.map((e) => e.toJson()).toList()));
  }

  // Create new goal
  Future<bool> createGoal(Goal goal) async {
    try {
      // Validate goal
      if (!_validateGoal(goal)) {
        return false;
      }

      // Add to active goals
      _activeGoals.add(goal);
      
      // Initialize progress
      _progress[goal.id] = GoalProgress(
        goalId: goal.id,
        current: 0.0,
        target: goal.target,
        startDate: DateTime.now(),
        lastUpdated: DateTime.now(),
      );

      // Save to backend
      await _saveGoalToBackend(goal);
      
      // Save locally
      await _saveGoals();
      
      // Schedule notifications
      await _scheduleGoalNotifications(goal);
      
      notifyListeners();
      return true;
    } catch (e) {
      print('Error creating goal: $e');
      return false;
    }
  }

  // Update existing goal
  Future<bool> updateGoal(String goalId, Goal updatedGoal) async {
    try {
      final index = _activeGoals.indexWhere((g) => g.id == goalId);
      if (index == -1) return false;

      _activeGoals[index] = updatedGoal;
      
      // Update progress target if changed
      if (_progress.containsKey(goalId)) {
        _progress[goalId]!.target = updatedGoal.target;
      }

      // Save to backend
      await _saveGoalToBackend(updatedGoal);
      
      // Save locally
      await _saveGoals();
      
      notifyListeners();
      return true;
    } catch (e) {
      print('Error updating goal: $e');
      return false;
    }
  }

  // Delete goal
  Future<bool> deleteGoal(String goalId) async {
    try {
      _activeGoals.removeWhere((g) => g.id == goalId);
      _progress.remove(goalId);

      // Archive in history
      final archivedGoal = GoalHistory(
        goalId: goalId,
        completed: false,
        archivedDate: DateTime.now(),
      );
      _goalHistory.add(archivedGoal);

      // Delete from backend
      await _deleteGoalFromBackend(goalId);
      
      // Save locally
      await _saveGoals();
      
      notifyListeners();
      return true;
    } catch (e) {
      print('Error deleting goal: $e');
      return false;
    }
  }

  // Mark goal as completed
  Future<bool> completeGoal(String goalId) async {
    try {
      final goal = _activeGoals.firstWhere((g) => g.id == goalId);
      
      // Add to history
      final completedGoal = GoalHistory(
        goalId: goalId,
        completed: true,
        completedDate: DateTime.now(),
        archivedDate: DateTime.now(),
      );
      _goalHistory.add(completedGoal);

      // Remove from active goals
      _activeGoals.removeWhere((g) => g.id == goalId);

      // Award achievement
      await _awardGoalCompletionAchievement(goal);

      // Save to backend
      await _completeGoalOnBackend(goalId);
      
      // Save locally
      await _saveGoals();
      
      notifyListeners();
      return true;
    } catch (e) {
      print('Error completing goal: $e');
      return false;
    }
  }

  // Update progress for a goal
  Future<void> updateProgress(String goalId, double value) async {
    if (!_progress.containsKey(goalId)) return;

    final progress = _progress[goalId]!;
    progress.current = value;
    progress.lastUpdated = DateTime.now();

    // Check if goal is completed
    if (value >= progress.target) {
      await completeGoal(goalId);
    } else {
      // Check for milestones
      await _checkMilestones(goalId);
    }

    await _saveGoals();
    notifyListeners();
  }

  // Get progress percentage
  double getProgressPercentage(String goalId) {
    if (!_progress.containsKey(goalId)) return 0.0;
    
    final progress = _progress[goalId]!;
    return (progress.current / progress.target).clamp(0.0, 1.0);
  }

  // Get goals by category
  List<Goal> getGoalsByCategory(GoalCategory category) {
    return _activeGoals.where((g) => g.category == category).toList();
  }

  // Get overdue goals
  List<Goal> getOverdueGoals() {
    final now = DateTime.now();
    return _activeGoals.where((g) => g.deadline != null && g.deadline!.isBefore(now)).toList();
  }

  // Get goals due soon
  List<Goal> getGoalsDueSoon({int days = 3}) {
    final soon = DateTime.now().add(Duration(days: days));
    return _activeGoals.where((g) => 
        g.deadline != null && 
        g.deadline!.isAfter(DateTime.now()) && 
        g.deadline!.isBefore(soon)
    ).toList();
  }

  // Get goal statistics
  Map<String, dynamic> getGoalStatistics() {
    final totalGoals = _activeGoals.length;
    final completedGoals = _goalHistory.where((h) => h.completed).length;
    final overdueGoals = getOverdueGoals().length;
    final onTrackGoals = _activeGoals.where((g) => _isOnTrack(g)).length;

    return {
      'total_active': totalGoals,
      'total_completed': completedGoals,
      'overdue': overdueGoals,
      'on_track': onTrackGoals,
      'completion_rate': totalGoals > 0 ? (completedGoals / (completedGoals + totalGoals)) * 100 : 0,
    };
  }

  // Validate goal
  bool _validateGoal(Goal goal) {
    // Check required fields
    if (goal.title.isEmpty || goal.target <= 0) return false;
    
    // Check deadline is in future
    if (goal.deadline != null && goal.deadline!.isBefore(DateTime.now())) {
      return false;
    }
    
    // Check for duplicates
    if (_activeGoals.any((g) => g.title.toLowerCase() == goal.title.toLowerCase())) {
      return false;
    }
    
    return true;
  }

  // Calculate current progress for all goals
  Future<void> _calculateProgress() async {
    for (final goal in _activeGoals) {
      double current = 0.0;
      
      switch (goal.type) {
        case GoalType.dailyCalories:
          current = await _getTodayCalories();
          break;
        case GoalType.dailyScans:
          current = await _getTodayScans();
          break;
        case GoalType.weeklyStreak:
          current = SettingsService.instance.scanStreak.toDouble();
          break;
        case GoalType.weightLoss:
          current = await _getCurrentWeight();
          break;
        case GoalType.custom:
          current = _progress[goal.id]?.current ?? 0.0;
          break;
      }
      
      _progress[goal.id] = GoalProgress(
        goalId: goal.id,
        current: current,
        target: goal.target,
        startDate: DateTime.now(),
        lastUpdated: DateTime.now(),
      );
    }
  }

  Future<double> _getTodayCalories() async {
    // This would integrate with your analytics service
    // For now, return mock data
    return 450.0;
  }

  Future<double> _getTodayScans() async {
    // This would integrate with your database service
    // For now, return mock data
    return 2.0;
  }

  Future<double> _getCurrentWeight() async {
    // This would integrate with a weight tracking feature
    // For now, return mock data
    return 70.0;
  }

  // Check if goal is on track
  bool _isOnTrack(Goal goal) {
    if (!_progress.containsKey(goal.id)) return false;
    
    final progress = _progress[goal.id]!;
    final percentage = progress.current / progress.target;
    
    if (goal.deadline == null) {
      return percentage >= 0.5; // 50% progress for goals without deadline
    }
    
    final totalDays = goal.deadline!.difference(goal.createdAt).inDays;
    final daysPassed = DateTime.now().difference(goal.createdAt).inDays;
    final expectedProgress = daysPassed / totalDays;
    
    return percentage >= expectedProgress;
  }

  // Check for milestones
  Future<void> _checkMilestones(String goalId) async {
    final goal = _activeGoals.firstWhere((g) => g.id == goalId);
    final progress = getProgressPercentage(goalId);
    
    // Check 25%, 50%, 75% milestones
    final milestones = [0.25, 0.5, 0.75];
    
    for (final milestone in milestones) {
      if (progress >= milestone && !_hasMilestoneAchievement(goalId, milestone)) {
        await _awardMilestoneAchievement(goal, milestone);
      }
    }
  }

  bool _hasMilestoneAchievement(String goalId, double milestone) {
    return _achievements.any((a) => 
        a.goalId == goalId && 
        a.type == AchievementType.milestone && 
        a.progress >= milestone);
  }

  Future<void> _awardMilestoneAchievement(Goal goal, double milestone) async {
    final achievement = Achievement(
      id: '${goal.id}_milestone_${(milestone * 100).toInt()}',
      title: '${(milestone * 100).toInt()}% Milestone',
      description: 'Reached ${(milestone * 100).toInt()}% of your goal: ${goal.title}',
      type: AchievementType.milestone,
      goalId: goal.id,
      progress: milestone,
      pointsAwarded: (milestone * 20).round(),
      unlockedAt: DateTime.now(),
    );
    
    _achievements.add(achievement);
    await NotificationService.instance.showAchievement(
      achievement.title,
      achievement.description,
    );
  }

  Future<void> _awardGoalCompletionAchievement(Goal goal) async {
    final achievement = Achievement(
      id: '${goal.id}_completed',
      title: 'Goal Completed!',
      description: 'Congratulations! You completed: ${goal.title}',
      type: AchievementType.goalCompletion,
      goalId: goal.id,
      progress: 1.0,
      pointsAwarded: 100,
      unlockedAt: DateTime.now(),
    );
    
    _achievements.add(achievement);
    await NotificationService.instance.showAchievement(
      achievement.title,
      achievement.description,
    );
  }

  // Backend integration methods
  Future<void> _saveGoalToBackend(Goal goal) async {
    try {
      final currentUser = AuthService.instance.currentUser;
      if (currentUser == null) return;

      await http.post(
        Uri.parse('$_baseUrl/goals'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_email': currentUser.email,
          'goal': goal.toJson(),
        }),
      );
    } catch (e) {
      print('Error saving goal to backend: $e');
    }
  }

  Future<void> _deleteGoalFromBackend(String goalId) async {
    try {
      final currentUser = AuthService.instance.currentUser;
      if (currentUser == null) return;

      await http.delete(
        Uri.parse('$_baseUrl/goals/$goalId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_email': currentUser.email}),
      );
    } catch (e) {
      print('Error deleting goal from backend: $e');
    }
  }

  Future<void> _completeGoalOnBackend(String goalId) async {
    try {
      final currentUser = AuthService.instance.currentUser;
      if (currentUser == null) return;

      await http.post(
        Uri.parse('$_baseUrl/goals/$goalId/complete'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_email': currentUser.email}),
      );
    } catch (e) {
      print('Error completing goal on backend: $e');
    }
  }

  Future<void> _scheduleGoalNotifications(Goal goal) async {
    if (goal.deadline == null) return;

    // Schedule reminder 1 day before deadline
    final reminderDate = goal.deadline!.subtract(const Duration(days: 1));
    
    await NotificationService.instance._notifications.zonedSchedule(
      goal.id.hashCode,
      'Goal Deadline Tomorrow!',
      'Your goal "${goal.title}" is due tomorrow. Keep going!',
      reminderDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_goals',
          'Daily Goals',
          channelDescription: 'Goal deadline reminders',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  // Get recommended goals based on user behavior
  List<Goal> getRecommendedGoals() {
    final recommendations = <Goal>[];
    
    // Analyze user's current patterns and suggest goals
    final avgCalories = 450; // Mock data
    final avgScans = 2; // Mock data
    final currentStreak = SettingsService.instance.scanStreak;
    
    if (avgCalories > 500) {
      recommendations.add(Goal(
        id: 'rec_reduce_calories',
        title: 'Reduce Daily Calories',
        description: 'Limit daily dessert calories to 400',
        type: GoalType.dailyCalories,
        target: 400,
        category: GoalCategory.nutrition,
        createdAt: DateTime.now(),
      ));
    }
    
    if (avgScans < 3) {
      recommendations.add(Goal(
        id: 'rec_increase_scans',
        title: 'Daily Scanning Habit',
        description: 'Scan at least 3 desserts daily',
        type: GoalType.dailyScans,
        target: 3,
        category: GoalCategory.habit,
        createdAt: DateTime.now(),
      ));
    }
    
    if (currentStreak < 7) {
      recommendations.add(Goal(
        id: 'rec_week_streak',
        title: 'One Week Streak',
        description: 'Maintain scanning streak for 7 days',
        type: GoalType.weeklyStreak,
        target: 7,
        category: GoalCategory.habit,
        createdAt: DateTime.now(),
      ));
    }
    
    return recommendations;
  }
}

// Data models
class Goal {
  final String id;
  final String title;
  final String description;
  final GoalType type;
  final double target;
  final GoalCategory category;
  final DateTime createdAt;
  final DateTime? deadline;
  final bool isPrivate;
  final List<String> tags;

  Goal({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.target,
    required this.category,
    required this.createdAt,
    this.deadline,
    this.isPrivate = true,
    this.tags = const [],
  });

  factory Goal.fromJson(Map<String, dynamic> json) {
    return Goal(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      type: GoalType.values.firstWhere(
        (e) => e.toString() == 'GoalType.${json['type']}',
        orElse: () => GoalType.custom,
      ),
      target: (json['target'] ?? 0.0).toDouble(),
      category: GoalCategory.values.firstWhere(
        (e) => e.toString() == 'GoalCategory.${json['category']}',
        orElse: () => GoalCategory.other,
      ),
      createdAt: DateTime.parse(json['created_at']),
      deadline: json['deadline'] != null ? DateTime.parse(json['deadline']) : null,
      isPrivate: json['is_private'] ?? true,
      tags: List<String>.from(json['tags'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'type': type.toString().split('.').last,
      'target': target,
      'category': category.toString().split('.').last,
      'created_at': createdAt.toIso8601String(),
      'deadline': deadline?.toIso8601String(),
      'is_private': isPrivate,
      'tags': tags,
    };
  }
}

class GoalProgress {
  final String goalId;
  double current;
  final double target;
  final DateTime startDate;
  final DateTime lastUpdated;

  GoalProgress({
    required this.goalId,
    required this.current,
    required this.target,
    required this.startDate,
    required this.lastUpdated,
  });
}

class GoalHistory {
  final String goalId;
  final bool completed;
  final DateTime? completedDate;
  final DateTime archivedDate;

  GoalHistory({
    required this.goalId,
    required this.completed,
    this.completedDate,
    required this.archivedDate,
  });

  factory GoalHistory.fromJson(Map<String, dynamic> json) {
    return GoalHistory(
      goalId: json['goal_id'] ?? '',
      completed: json['completed'] ?? false,
      completedDate: json['completed_date'] != null 
          ? DateTime.parse(json['completed_date']) 
          : null,
      archivedDate: DateTime.parse(json['archived_date']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'goal_id': goalId,
      'completed': completed,
      'completed_date': completedDate?.toIso8601String(),
      'archived_date': archivedDate.toIso8601String(),
    };
  }
}

class Achievement {
  final String id;
  final String title;
  final String description;
  final AchievementType type;
  final String? goalId;
  final double progress;
  final int pointsAwarded;
  final DateTime unlockedAt;

  Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    this.goalId,
    required this.progress,
    required this.pointsAwarded,
    required this.unlockedAt,
  });

  factory Achievement.fromJson(Map<String, dynamic> json) {
    return Achievement(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      type: AchievementType.values.firstWhere(
        (e) => e.toString() == 'AchievementType.${json['type']}',
        orElse: () => AchievementType.milestone,
      ),
      goalId: json['goal_id'],
      progress: (json['progress'] ?? 0.0).toDouble(),
      pointsAwarded: json['points_awarded'] ?? 0,
      unlockedAt: DateTime.parse(json['unlocked_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'type': type.toString().split('.').last,
      'goal_id': goalId,
      'progress': progress,
      'points_awarded': pointsAwarded,
      'unlocked_at': unlockedAt.toIso8601String(),
    };
  }
}

enum GoalType {
  dailyCalories,
  dailyScans,
  weeklyStreak,
  weightLoss,
  custom,
}

enum GoalCategory {
  nutrition,
  habit,
  fitness,
  weight,
  other,
}

enum AchievementType {
  milestone,
  goalCompletion,
  streak,
  special,
}
