import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'auth_service.dart';
import 'notification_service.dart';
import 'settings_service.dart';

class GamificationService extends ChangeNotifier {
  static final GamificationService instance = GamificationService._init();
  GamificationService._init();

  static const String _pointsKey = 'user_points';
  static const String _levelKey = 'user_level';
  static const String _badgesKey = 'user_badges';
  static const String _streakFreezesKey = 'streak_freezes';
  static const String _powerUpsKey = 'power_ups';
  static const String _achievementsKey = 'gamification_achievements';

  int _points = 0;
  int _level = 1;
  List<Badge> _badges = [];
  List<Achievement> _achievements = [];
  int _streakFreezes = 3;
  Map<PowerUpType, int> _powerUps = {};
  List<LeaderboardEntry> _leaderboard = [];
  List<Challenge> _activeChallenges = [];

  // Getters
  int get points => _points;
  int get level => _level;
  List<Badge> get badges => _badges;
  List<Achievement> get achievements => _achievements;
  int get streakFreezes => _streakFreezes;
  Map<PowerUpType, int> get powerUps => _powerUps;
  List<LeaderboardEntry> get leaderboard => _leaderboard;
  List<Challenge> get activeChallenges => _activeChallenges;

  // Initialize gamification system
  Future<void> initialize() async {
    await loadGameData();
    await _checkForNewAchievements();
    await _refreshLeaderboard();
  }

  // Load game data from storage
  Future<void> loadGameData() async {
    final prefs = await SharedPreferences.getInstance();
    
    _points = prefs.getInt(_pointsKey) ?? 0;
    _level = prefs.getInt(_levelKey) ?? 1;
    _streakFreezes = prefs.getInt(_streakFreezesKey) ?? 3;
    
    // Load badges
    final badgesJson = prefs.getString(_badgesKey);
    if (badgesJson != null) {
      final badgesList = jsonDecode(badgesJson) as List;
      _badges = badgesList.map((e) => Badge.fromJson(e)).toList();
    }
    
    // Load achievements
    final achievementsJson = prefs.getString(_achievementsKey);
    if (achievementsJson != null) {
      final achievementsList = jsonDecode(achievementsJson) as List;
      _achievements = achievementsList.map((e) => Achievement.fromJson(e)).toList();
    }
    
    // Load power-ups
    final powerUpsJson = prefs.getString(_powerUpsKey);
    if (powerUpsJson != null) {
      final powerUpsMap = jsonDecode(powerUpsJson) as Map<String, dynamic>;
      _powerUps = powerUpsMap.map((key, value) => 
        MapEntry(PowerUpType.values[int.parse(key)], value as int));
    }
    
    notifyListeners();
  }

  // Save game data to storage
  Future<void> _saveGameData() async {
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.setInt(_pointsKey, _points);
    await prefs.setInt(_levelKey, _level);
    await prefs.setInt(_streakFreezesKey, _streakFreezes);
    await prefs.setString(_badgesKey, jsonEncode(_badges.map((e) => e.toJson()).toList()));
    await prefs.setString(_achievementsKey, jsonEncode(_achievements.map((e) => e.toJson()).toList()));
    await prefs.setString(_powerUpsKey, jsonEncode(
      _powerUps.map((key, value) => MapEntry(key.index.toString(), value))
    ));
  }

  // Award points to user
  Future<void> awardPoints(int points, {String? reason, bool showNotification = true}) async {
    _points += points;
    
    // Check for level up
    await _checkLevelUp();
    
    // Save and notify
    await _saveGameData();
    
    if (showNotification && reason != null) {
      await NotificationService.instance.showAchievement(
        'Points Earned!',
        '+$points points - $reason',
      );
    }
    
    notifyListeners();
  }

  // Check if user leveled up
  Future<void> _checkLevelUp() async {
    final newLevel = _calculateLevel(_points);
    if (newLevel > _level) {
      _level = newLevel;
      
      // Award level-up bonus
      await awardPoints(_level * 10, reason: 'Level $_level bonus!');
      
      // Check for level-based badges
      await _checkLevelBadges();
      
      await NotificationService.instance.showAchievement(
        'Level Up!',
        'Congratulations! You reached level $_level',
      );
    }
  }

  // Calculate level based on points
  int _calculateLevel(int points) {
    // Level formula: 100 * level^2 points needed
    return ((sqrt(points / 100)) + 1).floor();
  }

  // Get points needed for next level
  int getPointsToNextLevel() {
    final nextLevel = _level + 1;
    return (nextLevel * nextLevel * 100) - _points;
  }

  // Get progress to next level (0.0 to 1.0)
  double getLevelProgress() {
    final currentLevelPoints = _level * _level * 100;
    final nextLevelPoints = (_level + 1) * (_level + 1) * 100;
    final pointsInLevel = nextLevelPoints - currentLevelPoints;
    final pointsEarned = _points - currentLevelPoints;
    
    return pointsEarned / pointsInLevel;
  }

  // Award badge to user
  Future<void> awardBadge(Badge badge, {bool showNotification = true}) async {
    if (!_hasBadge(badge.id)) {
      _badges.add(badge);
      await _saveGameData();
      
      if (showNotification) {
        await NotificationService.instance.showAchievement(
          'Badge Earned!',
          '${badge.name} - ${badge.description}',
        );
      }
      
      notifyListeners();
    }
  }

  // Check if user has badge
  bool _hasBadge(String badgeId) {
    return _badges.any((b) => b.id == badgeId);
  }

  // Check for level-based badges
  Future<void> _checkLevelBadges() async {
    final levelBadges = [
      Badge(
        id: 'level_5',
        name: 'Rising Star',
        description: 'Reached level 5',
        icon: 'star',
        rarity: BadgeRarity.common,
        pointsAwarded: 50,
      ),
      Badge(
        id: 'level_10',
        name: 'Expert Tracker',
        description: 'Reached level 10',
        icon: 'expert',
        rarity: BadgeRarity.uncommon,
        pointsAwarded: 100,
      ),
      Badge(
        id: 'level_25',
        name: 'Master Scanner',
        description: 'Reached level 25',
        icon: 'master',
        rarity: BadgeRarity.rare,
        pointsAwarded: 250,
      ),
    ];
    
    for (final badge in levelBadges) {
      final requiredLevel = int.parse(badge.id.split('_').last);
      if (_level >= requiredLevel) {
        await awardBadge(badge, showNotification: false);
      }
    }
  }

  // Check for new achievements
  Future<void> _checkForNewAchievements() async {
    final currentStreak = SettingsService.instance.scanStreak;
    
    // Streak achievements
    await _checkStreakAchievements(currentStreak);
    
    // Points achievements
    await _checkPointsAchievements();
    
    // Badge collection achievements
    await _checkBadgeCollectionAchievements();
  }

  Future<void> _checkStreakAchievements(int streak) async {
    final streakAchievements = [
      Achievement(
        id: 'streak_3',
        title: 'Three Day Streak',
        description: 'Maintained a 3-day scanning streak',
        pointsAwarded: 30,
        type: AchievementType.streak,
      ),
      Achievement(
        id: 'streak_7',
        title: 'Week Warrior',
        description: 'Maintained a 7-day scanning streak',
        pointsAwarded: 100,
        type: AchievementType.streak,
      ),
      Achievement(
        id: 'streak_30',
        title: 'Monthly Master',
        description: 'Maintained a 30-day scanning streak',
        pointsAwarded: 500,
        type: AchievementType.streak,
      ),
    ];
    
    for (final achievement in streakAchievements) {
      final requiredStreak = int.parse(achievement.id.split('_').last);
      if (streak >= requiredStreak && !_hasAchievement(achievement.id)) {
        await _unlockAchievement(achievement);
      }
    }
  }

  Future<void> _checkPointsAchievements() async {
    final pointsAchievements = [
      Achievement(
        id: 'points_100',
        title: 'Century Club',
        description: 'Earned 100 points',
        pointsAwarded: 50,
        type: AchievementType.points,
      ),
      Achievement(
        id: 'points_500',
        title: 'Point Master',
        description: 'Earned 500 points',
        pointsAwarded: 200,
        type: AchievementType.points,
      ),
      Achievement(
        id: 'points_1000',
        title: 'Point Legend',
        description: 'Earned 1000 points',
        pointsAwarded: 500,
        type: AchievementType.points,
      ),
    ];
    
    for (final achievement in pointsAchievements) {
      final requiredPoints = int.parse(achievement.id.split('_').last);
      if (_points >= requiredPoints && !_hasAchievement(achievement.id)) {
        await _unlockAchievement(achievement);
      }
    }
  }

  Future<void> _checkBadgeCollectionAchievements() async {
    final badgeCountAchievements = [
      Achievement(
        id: 'badges_5',
        title: 'Collector',
        description: 'Collected 5 badges',
        pointsAwarded: 100,
        type: AchievementType.collection,
      ),
      Achievement(
        id: 'badges_10',
        title: 'Badge Hunter',
        description: 'Collected 10 badges',
        pointsAwarded: 250,
        type: AchievementType.collection,
      ),
      Achievement(
        id: 'badges_25',
        title: 'Badge Master',
        description: 'Collected 25 badges',
        pointsAwarded: 1000,
        type: AchievementType.collection,
      ),
    ];
    
    for (final achievement in badgeCountAchievements) {
      final requiredBadges = int.parse(achievement.id.split('_').last);
      if (_badges.length >= requiredBadges && !_hasAchievement(achievement.id)) {
        await _unlockAchievement(achievement);
      }
    }
  }

  bool _hasAchievement(String achievementId) {
    return _achievements.any((a) => a.id == achievementId);
  }

  Future<void> _unlockAchievement(Achievement achievement) async {
    _achievements.add(achievement);
    await awardPoints(achievement.pointsAwarded, reason: achievement.title);
    
    await NotificationService.instance.showAchievement(
      achievement.title,
      achievement.description,
    );
    
    notifyListeners();
  }

  // Use streak freeze
  Future<bool> useStreakFreeze() async {
    if (_streakFreezes > 0) {
      _streakFreezes--;
      await _saveGameData();
      notifyListeners();
      return true;
    }
    return false;
  }

  // Add streak freeze
  Future<void> addStreakFreeze({int count = 1}) async {
    _streakFreezes += count;
    await _saveGameData();
    notifyListeners();
  }

  // Use power-up
  Future<bool> usePowerUp(PowerUpType type) async {
    final count = _powerUps[type] ?? 0;
    if (count > 0) {
      _powerUps[type] = count - 1;
      await _saveGameData();
      notifyListeners();
      return true;
    }
    return false;
  }

  // Add power-up
  Future<void> addPowerUp(PowerUpType type, {int count = 1}) async {
    _powerUps[type] = (_powerUps[type] ?? 0) + count;
    await _saveGameData();
    notifyListeners();
  }

  // Complete daily challenge
  Future<void> completeDailyChallenge(Challenge challenge) async {
    await awardPoints(challenge.pointsReward, reason: 'Daily challenge: ${challenge.title}');
    
    // Random power-up reward
    if (Random().nextDouble() < 0.3) { // 30% chance
      final randomPowerUp = PowerUpType.values[Random().nextInt(PowerUpType.values.length)];
      await addPowerUp(randomPowerUp);
      
      await NotificationService.instance.showAchievement(
        'Power-Up Earned!',
        'Got a ${randomPowerUp.displayName} power-up!',
      );
    }
    
    // Remove from active challenges
    _activeChallenges.removeWhere((c) => c.id == challenge.id);
    notifyListeners();
  }

  // Get daily challenges
  Future<void> generateDailyChallenges() async {
    final today = DateTime.now();
    final todayKey = '${today.year}-${today.month}-${today.day}';
    
    // Check if we already have challenges for today
    if (_activeChallenges.isNotEmpty && 
        _activeChallenges.first.id.startsWith(todayKey)) {
      return;
    }
    
    _activeChallenges.clear();
    
    // Generate 3 daily challenges
    final challengeTypes = [
      ChallengeType.scanCount,
      ChallengeType.calorieLimit,
      ChallengeType.categoryVariety,
      ChallengeType.streakMaintain,
    ];
    
    for (int i = 0; i < 3; i++) {
      final type = challengeTypes[Random().nextInt(challengeTypes.length)];
      final challenge = _generateChallenge(type, todayKey);
      _activeChallenges.add(challenge);
    }
    
    notifyListeners();
  }

  Challenge _generateChallenge(ChallengeType type, String dateKey) {
    switch (type) {
      case ChallengeType.scanCount:
        final target = Random().nextInt(3) + 2; // 2-4 scans
        return Challenge(
          id: '${dateKey}_scan_count',
          title: 'Scan Master',
          description: 'Scan $target desserts today',
          type: type,
          target: target.toDouble(),
          progress: 0,
          pointsReward: target * 20,
          completed: false,
        );
      
      case ChallengeType.calorieLimit:
        final target = Random().nextInt(200) + 300; // 300-500 calories
        return Challenge(
          id: '${dateKey}_calorie_limit',
          title: 'Calorie Counter',
          description: 'Stay under $target calories today',
          type: type,
          target: target.toDouble(),
          progress: 0,
          pointsReward: 50,
          completed: false,
        );
      
      case ChallengeType.categoryVariety:
        final target = Random().nextInt(2) + 2; // 2-3 categories
        return Challenge(
          id: '${dateKey}_category_variety',
          title: 'Variety Explorer',
          description: 'Scan desserts from $target different categories',
          type: type,
          target: target.toDouble(),
          progress: 0,
          pointsReward: 40,
          completed: false,
        );
      
      case ChallengeType.streakMaintain:
        return Challenge(
          id: '${dateKey}_streak_maintain',
          title: 'Streak Keeper',
          description: 'Maintain your scanning streak today',
          type: type,
          target: 1,
          progress: 0,
          pointsReward: 30,
          completed: false,
        );
    }
  }

  // Update challenge progress
  Future<void> updateChallengeProgress(String challengeId, double progress) async {
    final challenge = _activeChallenges.firstWhere((c) => c.id == challengeId);
    challenge.progress = progress;
    
    if (progress >= challenge.target && !challenge.completed) {
      challenge.completed = true;
      await completeDailyChallenge(challenge);
    }
    
    notifyListeners();
  }

  // Refresh leaderboard
  Future<void> _refreshLeaderboard() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/gamification/leaderboard'),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        _leaderboard = data.map((e) => LeaderboardEntry.fromJson(e)).toList();
      }
    } catch (e) {
      print('Error refreshing leaderboard: $e');
      // Use mock data for now
      _leaderboard = _generateMockLeaderboard();
    }
  }

  List<LeaderboardEntry> _generateMockLeaderboard() {
    final currentUser = AuthService.instance.currentUser;
    
    return [
      LeaderboardEntry(
        rank: 1,
        userEmail: 'player1@example.com',
        userName: 'DessertMaster',
        points: 2500,
        level: 15,
      ),
      LeaderboardEntry(
        rank: 2,
        userEmail: 'player2@example.com',
        userName: 'SweetTooth',
        points: 2100,
        level: 14,
      ),
      LeaderboardEntry(
        rank: 3,
        userEmail: currentUser?.email ?? 'user@example.com',
        userName: currentUser?.name ?? 'You',
        points: _points,
        level: _level,
        isCurrentUser: true,
      ),
    ];
  }

  // Get user rank on leaderboard
  int getUserRank() {
    final userEntry = _leaderboard.firstWhere(
      (entry) => entry.isCurrentUser,
      orElse: () => LeaderboardEntry(
        rank: _leaderboard.length + 1,
        userEmail: AuthService.instance.currentUser?.email ?? '',
        userName: AuthService.instance.currentUser?.name ?? 'You',
        points: _points,
        level: _level,
        isCurrentUser: true,
      ),
    );
    return userEntry.rank;
  }

  // Get statistics
  Map<String, dynamic> getStatistics() {
    return {
      'total_points': _points,
      'level': _level,
      'badges_count': _badges.length,
      'achievements_count': _achievements.length,
      'streak_freezes': _streakFreezes,
      'power_ups_total': _powerUps.values.fold(0, (sum, count) => sum + count),
      'leaderboard_rank': getUserRank(),
      'completed_challenges_today': _activeChallenges.where((c) => c.completed).length,
    };
  }

  // Reset all game data (for testing)
  Future<void> resetGameData() async {
    _points = 0;
    _level = 1;
    _badges = [];
    _achievements = [];
    _streakFreezes = 3;
    _powerUps.clear();
    _activeChallenges.clear();
    
    await _saveGameData();
    notifyListeners();
  }
}

// Data models
class Badge {
  final String id;
  final String name;
  final String description;
  final String icon;
  final BadgeRarity rarity;
  final int pointsAwarded;
  final DateTime? unlockedAt;

  Badge({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.rarity,
    required this.pointsAwarded,
    this.unlockedAt,
  });

  factory Badge.fromJson(Map<String, dynamic> json) {
    return Badge(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      icon: json['icon'] ?? '',
      rarity: BadgeRarity.values.firstWhere(
        (e) => e.toString() == 'BadgeRarity.${json['rarity']}',
        orElse: () => BadgeRarity.common,
      ),
      pointsAwarded: json['pointsAwarded'] ?? 0,
      unlockedAt: json['unlockedAt'] != null 
          ? DateTime.parse(json['unlockedAt']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'icon': icon,
      'rarity': rarity.toString().split('.').last,
      'pointsAwarded': pointsAwarded,
      'unlockedAt': unlockedAt?.toIso8601String(),
    };
  }

  Color get rarityColor {
    switch (rarity) {
      case BadgeRarity.common:
        return Colors.grey;
      case BadgeRarity.uncommon:
        return Colors.green;
      case BadgeRarity.rare:
        return Colors.blue;
      case BadgeRarity.epic:
        return Colors.purple;
      case BadgeRarity.legendary:
        return Colors.orange;
    }
  }
}

class Achievement {
  final String id;
  final String title;
  final String description;
  final int pointsAwarded;
  final AchievementType type;
  final DateTime? unlockedAt;

  Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.pointsAwarded,
    required this.type,
    this.unlockedAt,
  });

  factory Achievement.fromJson(Map<String, dynamic> json) {
    return Achievement(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      pointsAwarded: json['pointsAwarded'] ?? 0,
      type: AchievementType.values.firstWhere(
        (e) => e.toString() == 'AchievementType.${json['type']}',
        orElse: () => AchievementType.general,
      ),
      unlockedAt: json['unlockedAt'] != null 
          ? DateTime.parse(json['unlockedAt']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'pointsAwarded': pointsAwarded,
      'type': type.toString().split('.').last,
      'unlockedAt': unlockedAt?.toIso8601String(),
    };
  }
}

class Challenge {
  final String id;
  final String title;
  final String description;
  final ChallengeType type;
  final double target;
  double progress;
  final int pointsReward;
  bool completed;

  Challenge({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.target,
    required this.progress,
    required this.pointsReward,
    required this.completed,
  });

  double get completionPercentage => (progress / target).clamp(0.0, 1.0);
}

class LeaderboardEntry {
  final int rank;
  final String userEmail;
  final String userName;
  final int points;
  final int level;
  final bool isCurrentUser;

  LeaderboardEntry({
    required this.rank,
    required this.userEmail,
    required this.userName,
    required this.points,
    required this.level,
    this.isCurrentUser = false,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      rank: json['rank'] ?? 0,
      userEmail: json['userEmail'] ?? '',
      userName: json['userName'] ?? '',
      points: json['points'] ?? 0,
      level: json['level'] ?? 1,
      isCurrentUser: json['isCurrentUser'] ?? false,
    );
  }
}

enum BadgeRarity {
  common,
  uncommon,
  rare,
  epic,
  legendary,
}

enum AchievementType {
  general,
  streak,
  points,
  collection,
  challenge,
}

enum ChallengeType {
  scanCount,
  calorieLimit,
  categoryVariety,
  streakMaintain,
}

enum PowerUpType {
  doublePoints,
  streakFreeze,
  instantScan,
  calorieShield,
  badgeBoost,
}

extension PowerUpTypeExtension on PowerUpType {
  String get displayName {
    switch (this) {
      case PowerUpType.doublePoints:
        return 'Double Points';
      case PowerUpType.streakFreeze:
        return 'Streak Freeze';
      case PowerUpType.instantScan:
        return 'Instant Scan';
      case PowerUpType.calorieShield:
        return 'Calorie Shield';
      case PowerUpType.badgeBoost:
        return 'Badge Boost';
    }
  }

  String get icon {
    switch (this) {
      case PowerUpType.doublePoints:
        return '2x';
      case PowerUpType.streakFreeze:
        return 'snowflake';
      case PowerUpType.instantScan:
        return 'camera';
      case PowerUpType.calorieShield:
        return 'shield';
      case PowerUpType.badgeBoost:
        return 'star';
    }
  }

  Color get color {
    switch (this) {
      case PowerUpType.doublePoints:
        return Colors.amber;
      case PowerUpType.streakFreeze:
        return Colors.cyan;
      case PowerUpType.instantScan:
        return Colors.green;
      case PowerUpType.calorieShield:
        return Colors.blue;
      case PowerUpType.badgeBoost:
        return Colors.purple;
    }
  }
}
