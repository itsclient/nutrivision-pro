import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_config.dart';
import 'auth_service.dart';

class SocialService {
  static final SocialService instance = SocialService._init();
  SocialService._init();

  static const String _baseUrl = ApiConfig.baseUrl;
  static const String _friendsKey = 'friends_list';
  static const String _challengesKey = 'active_challenges';
  static const String _achievementsKey = 'user_achievements';

  List<User> _friends = [];
  List<Challenge> _activeChallenges = [];
  List<Achievement> _achievements = [];
  int _points = 0;

  List<User> get friends => _friends;
  List<Challenge> get activeChallenges => _activeChallenges;
  List<Achievement> get achievements => _achievements;
  int get points => _points;

  // Load social data from local storage
  Future<void> loadSocialData() async {
    final prefs = await SharedPreferences.getInstance();
    
    final friendsJson = prefs.getString(_friendsKey);
    if (friendsJson != null) {
      final friendsList = jsonDecode(friendsJson) as List;
      _friends = friendsList.map((e) => User.fromJson(e)).toList();
    }

    final challengesJson = prefs.getString(_challengesKey);
    if (challengesJson != null) {
      final challengesList = jsonDecode(challengesJson) as List;
      _activeChallenges = challengesList.map((e) => Challenge.fromJson(e)).toList();
    }

    final achievementsJson = prefs.getString(_achievementsKey);
    if (achievementsJson != null) {
      final achievementsList = jsonDecode(achievementsJson) as List;
      _achievements = achievementsList.map((e) => Achievement.fromJson(e)).toList();
    }

    _points = prefs.getInt('user_points') ?? 0;
  }

  // Save social data to local storage
  Future<void> _saveSocialData() async {
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.setString(_friendsKey, jsonEncode(_friends.map((e) => e.toJson()).toList()));
    await prefs.setString(_challengesKey, jsonEncode(_activeChallenges.map((e) => e.toJson()).toList()));
    await prefs.setString(_achievementsKey, jsonEncode(_achievements.map((e) => e.toJson()).toList()));
    await prefs.setInt('user_points', _points);
  }

  // Send friend request
  Future<bool> sendFriendRequest(String friendEmail) async {
    try {
      final currentUser = AuthService.instance.currentUser;
      if (currentUser == null) return false;

      final response = await http.post(
        Uri.parse('$_baseUrl/social/friend-request'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'from_email': currentUser.email,
          'to_email': friendEmail,
        }),
      );

      if (response.statusCode == 200) {
        return true;
      }
    } catch (e) {
      print('Error sending friend request: $e');
    }
    return false;
  }

  // Accept friend request
  Future<bool> acceptFriendRequest(String friendEmail) async {
    try {
      final currentUser = AuthService.instance.currentUser;
      if (currentUser == null) return false;

      final response = await http.post(
        Uri.parse('$_baseUrl/social/accept-friend'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_email': currentUser.email,
          'friend_email': friendEmail,
        }),
      );

      if (response.statusCode == 200) {
        // Add to local friends list
        final friendData = jsonDecode(response.body);
        final friend = User.fromJson(friendData);
        _friends.add(friend);
        await _saveSocialData();
        return true;
      }
    } catch (e) {
      print('Error accepting friend request: $e');
    }
    return false;
  }

  // Get friend requests
  Future<List<FriendRequest>> getFriendRequests() async {
    try {
      final currentUser = AuthService.instance.currentUser;
      if (currentUser == null) return [];

      final response = await http.get(
        Uri.parse('$_baseUrl/social/friend-requests/${currentUser.email}'),
      );

      if (response.statusCode == 200) {
        final requests = jsonDecode(response.body) as List;
        return requests.map((e) => FriendRequest.fromJson(e)).toList();
      }
    } catch (e) {
      print('Error getting friend requests: $e');
    }
    return [];
  }

  // Get leaderboard
  Future<List<LeaderboardEntry>> getLeaderboard({String type = 'weekly'}) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/social/leaderboard?type=$type'),
      );

      if (response.statusCode == 200) {
        final entries = jsonDecode(response.body) as List;
        return entries.map((e) => LeaderboardEntry.fromJson(e)).toList();
      }
    } catch (e) {
      print('Error getting leaderboard: $e');
    }
    return [];
  }

  // Create challenge
  Future<bool> createChallenge(Challenge challenge) async {
    try {
      final currentUser = AuthService.instance.currentUser;
      if (currentUser == null) return false;

      final response = await http.post(
        Uri.parse('$_baseUrl/social/create-challenge'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          ...challenge.toJson(),
          'creator_email': currentUser.email,
        }),
      );

      if (response.statusCode == 200) {
        _activeChallenges.add(challenge);
        await _saveSocialData();
        return true;
      }
    } catch (e) {
      print('Error creating challenge: $e');
    }
    return false;
  }

  // Join challenge
  Future<bool> joinChallenge(String challengeId) async {
    try {
      final currentUser = AuthService.instance.currentUser;
      if (currentUser == null) return false;

      final response = await http.post(
        Uri.parse('$_baseUrl/social/join-challenge'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'challenge_id': challengeId,
          'user_email': currentUser.email,
        }),
      );

      if (response.statusCode == 200) {
        final challengeData = jsonDecode(response.body);
        final challenge = Challenge.fromJson(challengeData);
        _activeChallenges.add(challenge);
        await _saveSocialData();
        return true;
      }
    } catch (e) {
      print('Error joining challenge: $e');
    }
    return false;
  }

  // Share achievement
  Future<bool> shareAchievement(Achievement achievement, {String? message}) async {
    try {
      final currentUser = AuthService.instance.currentUser;
      if (currentUser == null) return false;

      final response = await http.post(
        Uri.parse('$_baseUrl/social/share-achievement'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_email': currentUser.email,
          'achievement': achievement.toJson(),
          'message': message,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error sharing achievement: $e');
    }
    return false;
  }

  // Get friends' activity feed
  Future<List<ActivityFeedItem>> getActivityFeed() async {
    try {
      final currentUser = AuthService.instance.currentUser;
      if (currentUser == null) return [];

      final response = await http.get(
        Uri.parse('$_baseUrl/social/feed/${currentUser.email}'),
      );

      if (response.statusCode == 200) {
        final feed = jsonDecode(response.body) as List;
        return feed.map((e) => ActivityFeedItem.fromJson(e)).toList();
      }
    } catch (e) {
      print('Error getting activity feed: $e');
    }
    return [];
  }

  // Award points to user
  Future<void> awardPoints(int points, {String? reason}) async {
    _points += points;
    await _saveSocialData();

    // Check for new achievements
    await _checkAchievements();
  }

  // Check and unlock achievements
  Future<void> _checkAchievements() async {
    final newAchievements = <Achievement>[];

    // Points-based achievements
    if (_points >= 100 && !_hasAchievement('centurion')) {
      newAchievements.add(Achievement(
        id: 'centurion',
        title: 'Centurion',
        description: 'Earned 100 points!',
        icon: 'trophy',
        pointsAwarded: 50,
      ));
    }

    if (_points >= 500 && !_hasAchievement('point_master')) {
      newAchievements.add(Achievement(
        id: 'point_master',
        title: 'Point Master',
        description: 'Earned 500 points!',
        icon: 'star',
        pointsAwarded: 100,
      ));
    }

    // Add achievements and award bonus points
    for (final achievement in newAchievements) {
      _achievements.add(achievement);
      _points += achievement.pointsAwarded;
    }

    if (newAchievements.isNotEmpty) {
      await _saveSocialData();
    }
  }

  bool _hasAchievement(String achievementId) {
    return _achievements.any((a) => a.id == achievementId);
  }

  // Remove friend
  Future<bool> removeFriend(String friendEmail) async {
    try {
      final currentUser = AuthService.instance.currentUser;
      if (currentUser == null) return false;

      final response = await http.delete(
        Uri.parse('$_baseUrl/social/remove-friend'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_email': currentUser.email,
          'friend_email': friendEmail,
        }),
      );

      if (response.statusCode == 200) {
        _friends.removeWhere((f) => f.email == friendEmail);
        await _saveSocialData();
        return true;
      }
    } catch (e) {
      print('Error removing friend: $e');
    }
    return false;
  }
}

// Data models
class User {
  final String email;
  final String? username;
  final String? name;
  final String? avatar;
  final int points;
  final int streak;

  User({
    required this.email,
    this.username,
    this.name,
    this.avatar,
    this.points = 0,
    this.streak = 0,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      email: json['email'] ?? '',
      username: json['username'],
      name: json['name'],
      avatar: json['avatar'],
      points: json['points'] ?? 0,
      streak: json['streak'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'username': username,
      'name': name,
      'avatar': avatar,
      'points': points,
      'streak': streak,
    };
  }
}

class Challenge {
  final String id;
  final String title;
  final String description;
  final String type;
  final DateTime startDate;
  final DateTime endDate;
  final List<String> participants;
  final Map<String, dynamic> rules;
  final String? creatorEmail;

  Challenge({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.startDate,
    required this.endDate,
    required this.participants,
    required this.rules,
    this.creatorEmail,
  });

  factory Challenge.fromJson(Map<String, dynamic> json) {
    return Challenge(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      type: json['type'] ?? '',
      startDate: DateTime.parse(json['start_date']),
      endDate: DateTime.parse(json['end_date']),
      participants: List<String>.from(json['participants'] ?? []),
      rules: json['rules'] ?? {},
      creatorEmail: json['creator_email'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'type': type,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'participants': participants,
      'rules': rules,
      'creator_email': creatorEmail,
    };
  }
}

class Achievement {
  final String id;
  final String title;
  final String description;
  final String icon;
  final int pointsAwarded;
  final DateTime? unlockedAt;

  Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.pointsAwarded,
    this.unlockedAt,
  });

  factory Achievement.fromJson(Map<String, dynamic> json) {
    return Achievement(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      icon: json['icon'] ?? '',
      pointsAwarded: json['points_awarded'] ?? 0,
      unlockedAt: json['unlocked_at'] != null 
          ? DateTime.parse(json['unlocked_at']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'icon': icon,
      'points_awarded': pointsAwarded,
      'unlocked_at': unlockedAt?.toIso8601String(),
    };
  }
}

class FriendRequest {
  final String fromEmail;
  final String? fromName;
  final DateTime sentAt;

  FriendRequest({
    required this.fromEmail,
    this.fromName,
    required this.sentAt,
  });

  factory FriendRequest.fromJson(Map<String, dynamic> json) {
    return FriendRequest(
      fromEmail: json['from_email'] ?? '',
      fromName: json['from_name'],
      sentAt: DateTime.parse(json['sent_at']),
    );
  }
}

class LeaderboardEntry {
  final String userEmail;
  final String? userName;
  final int score;
  final int rank;

  LeaderboardEntry({
    required this.userEmail,
    this.userName,
    required this.score,
    required this.rank,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      userEmail: json['user_email'] ?? '',
      userName: json['user_name'],
      score: json['score'] ?? 0,
      rank: json['rank'] ?? 0,
    );
  }
}

class ActivityFeedItem {
  final String type;
  final String userEmail;
  final String? userName;
  final String message;
  final Map<String, dynamic>? data;
  final DateTime timestamp;

  ActivityFeedItem({
    required this.type,
    required this.userEmail,
    this.userName,
    required this.message,
    this.data,
    required this.timestamp,
  });

  factory ActivityFeedItem.fromJson(Map<String, dynamic> json) {
    return ActivityFeedItem(
      type: json['type'] ?? '',
      userEmail: json['user_email'] ?? '',
      userName: json['user_name'],
      message: json['message'] ?? '',
      data: json['data'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}
