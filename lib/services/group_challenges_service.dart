import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'api_config.dart';
import 'auth_service.dart';
import 'gamification_service.dart';
import 'social_service.dart';

class GroupChallengesService {
  static final GroupChallengesService instance = GroupChallengesService._init();
  GroupChallengesService._init();

  static const String _activeChallengesKey = 'group_challenges';
  static const String _userTeamsKey = 'user_teams';
  static const String _tournamentHistoryKey = 'tournament_history';
  static const String _challengeInvitesKey = 'challenge_invites';

  List<GroupChallenge> _activeChallenges = [];
  List<Team> _userTeams = [];
  List<Tournament> _tournamentHistory = [];
  List<ChallengeInvite> _challengeInvites = [];

  // Getters
  List<GroupChallenge> get activeChallenges => _activeChallenges;
  List<Team> get userTeams => _userTeams;
  List<Tournament> get tournamentHistory => _tournamentHistory;
  List<ChallengeInvite> get challengeInvites => _challengeInvites;

  // Initialize service
  Future<void> initialize() async {
    await _loadActiveChallenges();
    await _loadUserTeams();
    await _loadTournamentHistory();
    await _loadChallengeInvites();
    await _refreshChallenges();
  }

  // Load active challenges
  Future<void> _loadActiveChallenges() async {
    final prefs = await SharedPreferences.getInstance();
    final challengesJson = prefs.getString(_activeChallengesKey);
    
    if (challengesJson != null) {
      final challengesList = jsonDecode(challengesJson) as List;
      _activeChallenges = challengesList.map((e) => GroupChallenge.fromJson(e)).toList();
    }
  }

  // Load user teams
  Future<void> _loadUserTeams() async {
    final prefs = await SharedPreferences.getInstance();
    final teamsJson = prefs.getString(_userTeamsKey);
    
    if (teamsJson != null) {
      final teamsList = jsonDecode(teamsJson) as List;
      _userTeams = teamsList.map((e) => Team.fromJson(e)).toList();
    }
  }

  // Load tournament history
  Future<void> _loadTournamentHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getString(_tournamentHistoryKey);
    
    if (historyJson != null) {
      final historyList = jsonDecode(historyJson) as List;
      _tournamentHistory = historyList.map((e) => Tournament.fromJson(e)).toList();
    }
  }

  // Load challenge invites
  Future<void> _loadChallengeInvites() async {
    final prefs = await SharedPreferences.getInstance();
    final invitesJson = prefs.getString(_challengeInvitesKey);
    
    if (invitesJson != null) {
      final invitesList = jsonDecode(invitesJson) as List;
      _challengeInvites = invitesList.map((e) => ChallengeInvite.fromJson(e)).toList();
    }
  }

  // Save active challenges
  Future<void> _saveActiveChallenges() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeChallengesKey, jsonEncode(
      _activeChallenges.map((e) => e.toJson()).toList()
    ));
  }

  // Save user teams
  Future<void> _saveUserTeams() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userTeamsKey, jsonEncode(
      _userTeams.map((e) => e.toJson()).toList()
    ));
  }

  // Save tournament history
  Future<void> _saveTournamentHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tournamentHistoryKey, jsonEncode(
      _tournamentHistory.map((e) => e.toJson()).toList()
    ));
  }

  // Save challenge invites
  Future<void> _saveChallengeInvites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_challengeInvitesKey, jsonEncode(
      _challengeInvites.map((e) => e.toJson()).toList()
    ));
  }

  // Refresh challenges from server
  Future<void> _refreshChallenges() async {
    try {
      final currentUser = AuthService.instance.currentUser;
      if (currentUser == null) return;

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/challenges/active/${currentUser.email}'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final challenges = (data['challenges'] as List)
            .map((e) => GroupChallenge.fromJson(e))
            .toList();
        
        _activeChallenges = challenges;
        await _saveActiveChallenges();
      }
    } catch (e) {
      print('Error refreshing challenges: $e');
      // Generate mock challenges for demo
      _generateMockChallenges();
    }
  }

  // Generate mock challenges for demo
  void _generateMockChallenges() {
    _activeChallenges = [
      GroupChallenge(
        id: '1',
        name: '30-Day Streak Challenge',
        description: 'Maintain a daily scanning streak for 30 days',
        type: ChallengeType.streak,
        difficulty: ChallengeDifficulty.medium,
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 30)),
        maxParticipants: 100,
        currentParticipants: 45,
        prizePool: 500,
        requirements: [
          'Scan at least 1 dessert daily',
          'Maintain streak for 30 consecutive days',
          'No missed days allowed',
        ],
        rewards: [
          '500 points for completion',
          'Exclusive badge',
          'Entry into monthly raffle',
        ],
        createdBy: 'system',
        isActive: true,
      ),
      GroupChallenge(
        id: '2',
        name: 'Calorie Crusher Tournament',
        description: 'Stay under your calorie goal for 7 days straight',
        type: ChallengeType.calorie,
        difficulty: ChallengeDifficulty.hard,
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 7)),
        maxParticipants: 50,
        currentParticipants: 32,
        prizePool: 1000,
        requirements: [
          'Stay under daily calorie goal',
          'Log all meals and snacks',
          'Complete daily check-ins',
        ],
        rewards: [
          '1000 points for winner',
          '500 points for 2nd place',
          '250 points for 3rd place',
          'Trophy badge',
        ],
        createdBy: 'system',
        isActive: true,
      ),
      GroupChallenge(
        id: '3',
        name: 'Protein Power Week',
        description: 'Hit your protein goal every day for one week',
        type: ChallengeType.protein,
        difficulty: ChallengeDifficulty.easy,
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 7)),
        maxParticipants: 200,
        currentParticipants: 87,
        prizePool: 300,
        requirements: [
          'Meet daily protein goal',
          'Track protein intake',
          'Share progress with team',
        ],
        rewards: [
          '300 points for completion',
          'Protein champion badge',
          'Recipe collection',
        ],
        createdBy: 'system',
        isActive: true,
      ),
    ];
  }

  // Create new challenge
  Future<bool> createChallenge({
    required String name,
    required String description,
    required ChallengeType type,
    required ChallengeDifficulty difficulty,
    required DateTime startDate,
    required DateTime endDate,
    required int maxParticipants,
    required int prizePool,
    required List<String> requirements,
    required List<String> rewards,
  }) async {
    try {
      final currentUser = AuthService.instance.currentUser;
      if (currentUser == null) return false;

      final challenge = GroupChallenge(
        id: const Uuid().v4(),
        name: name,
        description: description,
        type: type,
        difficulty: difficulty,
        startDate: startDate,
        endDate: endDate,
        maxParticipants: maxParticipants,
        currentParticipants: 1, // Creator joins automatically
        prizePool: prizePool,
        requirements: requirements,
        rewards: rewards,
        createdBy: currentUser.email,
        isActive: true,
      );

      // Save to backend
      await _saveChallengeToBackend(challenge);
      
      // Add to local list
      _activeChallenges.add(challenge);
      await _saveActiveChallenges();

      // Award points for creating challenge
      await GamificationService.instance.awardPoints(
        50,
        reason: 'Created group challenge',
      );

      return true;
    } catch (e) {
      print('Error creating challenge: $e');
      return false;
    }
  }

  // Join challenge
  Future<bool> joinChallenge(String challengeId) async {
    try {
      final challenge = _activeChallenges.firstWhere((c) => c.id == challengeId);
      
      if (challenge.currentParticipants >= challenge.maxParticipants) {
        throw Exception('Challenge is full');
      }

      if (challenge.endDate.isBefore(DateTime.now())) {
        throw Exception('Challenge has ended');
      }

      // Update participant count
      challenge.currentParticipants++;
      await _saveActiveChallenges();

      // Save to backend
      await _joinChallengeOnBackend(challengeId);

      // Award points for joining
      await GamificationService.instance.awardPoints(
        10,
        reason: 'Joined group challenge',
      );

      return true;
    } catch (e) {
      print('Error joining challenge: $e');
      return false;
    }
  }

  // Leave challenge
  Future<bool> leaveChallenge(String challengeId) async {
    try {
      final challenge = _activeChallenges.firstWhere((c) => c.id == challengeId);
      
      // Update participant count
      challenge.currentParticipants = (challenge.currentParticipants - 1).clamp(0, double.infinity).toInt();
      await _saveActiveChallenges();

      // Save to backend
      await _leaveChallengeOnBackend(challengeId);

      return true;
    } catch (e) {
      print('Error leaving challenge: $e');
      return false;
    }
  }

  // Create team
  Future<bool> createTeam({
    required String name,
    required String description,
    required int maxSize,
    required ChallengeType challengeType,
  }) async {
    try {
      final currentUser = AuthService.instance.currentUser;
      if (currentUser == null) return false;

      final team = Team(
        id: const Uuid().v4(),
        name: name,
        description: description,
        maxSize: maxSize,
        currentSize: 1,
        challengeType: challengeType,
        createdBy: currentUser.email,
        members: [
          TeamMember(
            userId: currentUser.email,
            userName: currentUser.name,
            role: TeamRole.leader,
            joinedAt: DateTime.now(),
          ),
        ],
        createdAt: DateTime.now(),
        isActive: true,
      );

      _userTeams.add(team);
      await _saveUserTeams();

      // Award points for creating team
      await GamificationService.instance.awardPoints(
        25,
        reason: 'Created team',
      );

      return true;
    } catch (e) {
      print('Error creating team: $e');
      return false;
    }
  }

  // Join team
  Future<bool> joinTeam(String teamId) async {
    try {
      final team = _userTeams.firstWhere((t) => t.id == teamId);
      final currentUser = AuthService.instance.currentUser;
      
      if (currentUser == null) return false;
      if (team.currentSize >= team.maxSize) {
        throw Exception('Team is full');
      }

      // Add member
      team.members.add(TeamMember(
        userId: currentUser.email,
        userName: currentUser.name,
        role: TeamRole.member,
        joinedAt: DateTime.now(),
      ));
      team.currentSize++;
      
      await _saveUserTeams();

      // Award points for joining team
      await GamificationService.instance.awardPoints(
        15,
        reason: 'Joined team',
      );

      return true;
    } catch (e) {
      print('Error joining team: $e');
      return false;
    }
  }

  // Invite to challenge
  Future<bool> inviteToChallenge(String challengeId, String userEmail) async {
    try {
      final invite = ChallengeInvite(
        id: const Uuid().v4(),
        challengeId: challengeId,
        inviterEmail: AuthService.instance.currentUser?.email ?? '',
        inviteeEmail: userEmail,
        status: InviteStatus.pending,
        createdAt: DateTime.now(),
      );

      _challengeInvites.add(invite);
      await _saveChallengeInvites();

      // Send notification (would integrate with notification service)
      
      return true;
    } catch (e) {
      print('Error sending invite: $e');
      return false;
    }
  }

  // Respond to challenge invite
  Future<bool> respondToInvite(String inviteId, bool accept) async {
    try {
      final invite = _challengeInvites.firstWhere((i) => i.id == inviteId);
      
      invite.status = accept ? InviteStatus.accepted : InviteStatus.declined;
      invite.respondedAt = DateTime.now();
      
      await _saveChallengeInvites();

      if (accept) {
        await joinChallenge(invite.challengeId);
      }

      return true;
    } catch (e) {
      print('Error responding to invite: $e');
      return false;
    }
  }

  // Get challenge leaderboard
  List<ChallengeParticipant> getChallengeLeaderboard(String challengeId) {
    final challenge = _activeChallenges.firstWhere((c) => c.id == challengeId);
    
    // Mock leaderboard data
    final leaderboard = <ChallengeParticipant>[];
    final names = ['Alex Johnson', 'Sarah Smith', 'Mike Chen', 'Emma Wilson', 'David Brown'];
    
    for (int i = 0; i < min(5, challenge.currentParticipants); i++) {
      leaderboard.add(ChallengeParticipant(
        userId: 'user_$i',
        userName: names[i],
        score: (5 - i) * 100,
        rank: i + 1,
        progress: 1.0 - (i * 0.2),
        joinedAt: DateTime.now().subtract(Duration(days: i)),
      ));
    }
    
    return leaderboard;
  }

  // Get team leaderboard
  List<TeamLeaderboardEntry> getTeamLeaderboard(String challengeId) {
    // Mock team leaderboard data
    final teams = [
      'Protein Warriors',
      'Calorie Crushers',
      'Streak Masters',
      'Health Heroes',
      'Fitness Fanatics',
    ];
    
    return teams.asMap().entries.map((entry) {
      final index = entry.key;
      final teamName = entry.value;
      
      return TeamLeaderboardEntry(
        teamId: 'team_$index',
        teamName: teamName,
        score: (5 - index) * 150,
        rank: index + 1,
        memberCount: 3 + Random().nextInt(5),
        averageProgress: 1.0 - (index * 0.15),
      );
    }).toList();
  }

  // Update challenge progress
  Future<void> updateChallengeProgress(String challengeId, double progress) async {
    try {
      // This would update the user's progress in the challenge
      // For now, we'll just save it locally
      
      // Award points for progress
      if (progress >= 1.0) {
        await GamificationService.instance.awardPoints(
          100,
          reason: 'Completed challenge milestone',
        );
      }
    } catch (e) {
      print('Error updating challenge progress: $e');
    }
  }

  // Get available challenges
  List<GroupChallenge> getAvailableChallenges() {
    final currentUser = AuthService.instance.currentUser;
    
    return _activeChallenges.where((challenge) {
      // Filter out challenges the user has already joined
      // and challenges that are full or ended
      return challenge.isActive &&
             challenge.currentParticipants < challenge.maxParticipants &&
             challenge.endDate.isAfter(DateTime.now());
    }).toList();
  }

  // Get user's active challenges
  List<GroupChallenge> getUserChallenges() {
    // This would check which challenges the user has joined
    // For now, return a subset
    return _activeChallenges.take(2).toList();
  }

  // Get challenge statistics
  Map<String, dynamic> getChallengeStatistics() {
    final totalChallenges = _activeChallenges.length;
    final totalParticipants = _activeChallenges.fold<int>(
      0, (sum, challenge) => sum + challenge.currentParticipants
    );
    final totalPrizePool = _activeChallenges.fold<int>(
      0, (sum, challenge) => sum + challenge.prizePool
    );
    
    final challengesByType = <ChallengeType, int>{};
    for (final challenge in _activeChallenges) {
      challengesByType[challenge.type] = (challengesByType[challenge.type] ?? 0) + 1;
    }
    
    return {
      'total_challenges': totalChallenges,
      'total_participants': totalParticipants,
      'total_prize_pool': totalPrizePool,
      'challenges_by_type': challengesByType,
      'user_teams_count': _userTeams.length,
      'pending_invites': _challengeInvites.where((i) => i.status == InviteStatus.pending).length,
    };
  }

  // Backend integration methods
  Future<void> _saveChallengeToBackend(GroupChallenge challenge) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/challenges'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(challenge.toJson()),
      );
      
      if (response.statusCode != 200) {
        print('Error saving challenge to backend: ${response.body}');
      }
    } catch (e) {
      print('Error saving challenge to backend: $e');
    }
  }

  Future<void> _joinChallengeOnBackend(String challengeId) async {
    try {
      final currentUser = AuthService.instance.currentUser;
      if (currentUser == null) return;

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/challenges/$challengeId/join'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_email': currentUser.email}),
      );
      
      if (response.statusCode != 200) {
        print('Error joining challenge on backend: ${response.body}');
      }
    } catch (e) {
      print('Error joining challenge on backend: $e');
    }
  }

  Future<void> _leaveChallengeOnBackend(String challengeId) async {
    try {
      final currentUser = AuthService.instance.currentUser;
      if (currentUser == null) return;

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/challenges/$challengeId/leave'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_email': currentUser.email}),
      );
      
      if (response.statusCode != 200) {
        print('Error leaving challenge on backend: ${response.body}');
      }
    } catch (e) {
      print('Error leaving challenge on backend: $e');
    }
  }
}

// Data models
class GroupChallenge {
  final String id;
  final String name;
  final String description;
  final ChallengeType type;
  final ChallengeDifficulty difficulty;
  final DateTime startDate;
  final DateTime endDate;
  final int maxParticipants;
  int currentParticipants;
  final int prizePool;
  final List<String> requirements;
  final List<String> rewards;
  final String createdBy;
  final bool isActive;

  GroupChallenge({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.difficulty,
    required this.startDate,
    required this.endDate,
    required this.maxParticipants,
    required this.currentParticipants,
    required this.prizePool,
    required this.requirements,
    required this.rewards,
    required this.createdBy,
    required this.isActive,
  });

  factory GroupChallenge.fromJson(Map<String, dynamic> json) {
    return GroupChallenge(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      type: ChallengeType.values.firstWhere(
        (e) => e.toString() == 'ChallengeType.${json['type']}',
        orElse: () => ChallengeType.streak,
      ),
      difficulty: ChallengeDifficulty.values.firstWhere(
        (e) => e.toString() == 'ChallengeDifficulty.${json['difficulty']}',
        orElse: () => ChallengeDifficulty.easy,
      ),
      startDate: DateTime.parse(json['start_date']),
      endDate: DateTime.parse(json['end_date']),
      maxParticipants: json['max_participants'] ?? 0,
      currentParticipants: json['current_participants'] ?? 0,
      prizePool: json['prize_pool'] ?? 0,
      requirements: List<String>.from(json['requirements'] ?? []),
      rewards: List<String>.from(json['rewards'] ?? []),
      createdBy: json['created_by'] ?? '',
      isActive: json['is_active'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'type': type.toString().split('.').last,
      'difficulty': difficulty.toString().split('.').last,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'max_participants': maxParticipants,
      'current_participants': currentParticipants,
      'prize_pool': prizePool,
      'requirements': requirements,
      'rewards': rewards,
      'created_by': createdBy,
      'is_active': isActive,
    };
  }

  double get progressPercentage {
    final now = DateTime.now();
    final total = endDate.difference(startDate).inMilliseconds;
    final elapsed = now.difference(startDate).inMilliseconds;
    return (elapsed / total).clamp(0.0, 1.0);
  }

  int get daysRemaining {
    return endDate.difference(DateTime.now()).inDays.clamp(0, double.infinity).toInt();
  }
}

class Team {
  final String id;
  final String name;
  final String description;
  final int maxSize;
  int currentSize;
  final ChallengeType challengeType;
  final String createdBy;
  final List<TeamMember> members;
  final DateTime createdAt;
  final bool isActive;

  Team({
    required this.id,
    required this.name,
    required this.description,
    required this.maxSize,
    required this.currentSize,
    required this.challengeType,
    required this.createdBy,
    required this.members,
    required this.createdAt,
    required this.isActive,
  });

  factory Team.fromJson(Map<String, dynamic> json) {
    return Team(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      maxSize: json['max_size'] ?? 0,
      currentSize: json['current_size'] ?? 0,
      challengeType: ChallengeType.values.firstWhere(
        (e) => e.toString() == 'ChallengeType.${json['challenge_type']}',
        orElse: () => ChallengeType.streak,
      ),
      createdBy: json['created_by'] ?? '',
      members: (json['members'] as List)
          .map((e) => TeamMember.fromJson(e))
          .toList(),
      createdAt: DateTime.parse(json['created_at']),
      isActive: json['is_active'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'max_size': maxSize,
      'current_size': currentSize,
      'challenge_type': challengeType.toString().split('.').last,
      'created_by': createdBy,
      'members': members.map((e) => e.toJson()).toList(),
      'created_at': createdAt.toIso8601String(),
      'is_active': isActive,
    };
  }
}

class TeamMember {
  final String userId;
  final String userName;
  final TeamRole role;
  final DateTime joinedAt;

  TeamMember({
    required this.userId,
    required this.userName,
    required this.role,
    required this.joinedAt,
  });

  factory TeamMember.fromJson(Map<String, dynamic> json) {
    return TeamMember(
      userId: json['user_id'] ?? '',
      userName: json['user_name'] ?? '',
      role: TeamRole.values.firstWhere(
        (e) => e.toString() == 'TeamRole.${json['role']}',
        orElse: () => TeamRole.member,
      ),
      joinedAt: DateTime.parse(json['joined_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'user_name': userName,
      'role': role.toString().split('.').last,
      'joined_at': joinedAt.toIso8601String(),
    };
  }
}

class ChallengeInvite {
  final String id;
  final String challengeId;
  final String inviterEmail;
  final String inviteeEmail;
  InviteStatus status;
  final DateTime createdAt;
  DateTime? respondedAt;

  ChallengeInvite({
    required this.id,
    required this.challengeId,
    required this.inviterEmail,
    required this.inviteeEmail,
    required this.status,
    required this.createdAt,
    this.respondedAt,
  });

  factory ChallengeInvite.fromJson(Map<String, dynamic> json) {
    return ChallengeInvite(
      id: json['id'] ?? '',
      challengeId: json['challenge_id'] ?? '',
      inviterEmail: json['inviter_email'] ?? '',
      inviteeEmail: json['invitee_email'] ?? '',
      status: InviteStatus.values.firstWhere(
        (e) => e.toString() == 'InviteStatus.${json['status']}',
        orElse: () => InviteStatus.pending,
      ),
      createdAt: DateTime.parse(json['created_at']),
      respondedAt: json['responded_at'] != null 
          ? DateTime.parse(json['responded_at']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'challenge_id': challengeId,
      'inviter_email': inviterEmail,
      'invitee_email': inviteeEmail,
      'status': status.toString().split('.').last,
      'created_at': createdAt.toIso8601String(),
      'responded_at': respondedAt?.toIso8601String(),
    };
  }
}

class Tournament {
  final String id;
  final String name;
  final String description;
  final DateTime startDate;
  final DateTime endDate;
  final List<String> challenges;
  final List<TeamParticipant> participants;
  final TeamParticipant? winner;

  Tournament({
    required this.id,
    required this.name,
    required this.description,
    required this.startDate,
    required this.endDate,
    required this.challenges,
    required this.participants,
    this.winner,
  });

  factory Tournament.fromJson(Map<String, dynamic> json) {
    return Tournament(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      startDate: DateTime.parse(json['start_date']),
      endDate: DateTime.parse(json['end_date']),
      challenges: List<String>.from(json['challenges'] ?? []),
      participants: (json['participants'] as List)
          .map((e) => TeamParticipant.fromJson(e))
          .toList(),
      winner: json['winner'] != null 
          ? TeamParticipant.fromJson(json['winner']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'challenges': challenges,
      'participants': participants.map((e) => e.toJson()).toList(),
      'winner': winner?.toJson(),
    };
  }
}

class ChallengeParticipant {
  final String userId;
  final String userName;
  final int score;
  final int rank;
  final double progress;
  final DateTime joinedAt;

  ChallengeParticipant({
    required this.userId,
    required this.userName,
    required this.score,
    required this.rank,
    required this.progress,
    required this.joinedAt,
  });

  factory ChallengeParticipant.fromJson(Map<String, dynamic> json) {
    return ChallengeParticipant(
      userId: json['user_id'] ?? '',
      userName: json['user_name'] ?? '',
      score: json['score'] ?? 0,
      rank: json['rank'] ?? 0,
      progress: (json['progress'] ?? 0.0).toDouble(),
      joinedAt: DateTime.parse(json['joined_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'user_name': userName,
      'score': score,
      'rank': rank,
      'progress': progress,
      'joined_at': joinedAt.toIso8601String(),
    };
  }
}

class TeamParticipant {
  final String teamId;
  final String teamName;
  final int score;
  final int rank;
  final List<String> memberIds;

  TeamParticipant({
    required this.teamId,
    required this.teamName,
    required this.score,
    required this.rank,
    required this.memberIds,
  });

  factory TeamParticipant.fromJson(Map<String, dynamic> json) {
    return TeamParticipant(
      teamId: json['team_id'] ?? '',
      teamName: json['team_name'] ?? '',
      score: json['score'] ?? 0,
      rank: json['rank'] ?? 0,
      memberIds: List<String>.from(json['member_ids'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'team_id': teamId,
      'team_name': teamName,
      'score': score,
      'rank': rank,
      'member_ids': memberIds,
    };
  }
}

class TeamLeaderboardEntry {
  final String teamId;
  final String teamName;
  final int score;
  final int rank;
  final int memberCount;
  final double averageProgress;

  TeamLeaderboardEntry({
    required this.teamId,
    required this.teamName,
    required this.score,
    required this.rank,
    required this.memberCount,
    required this.averageProgress,
  });
}

enum ChallengeType {
  streak,
  calorie,
  protein,
  scans,
  weight,
  custom,
}

enum ChallengeDifficulty {
  easy,
  medium,
  hard,
  expert,
}

enum TeamRole {
  leader,
  member,
}

enum InviteStatus {
  pending,
  accepted,
  declined,
  expired,
}

extension ChallengeTypeExtension on ChallengeType {
  String get displayName {
    switch (this) {
      case ChallengeType.streak:
        return 'Streak';
      case ChallengeType.calorie:
        return 'Calorie';
      case ChallengeType.protein:
        return 'Protein';
      case ChallengeType.scans:
        return 'Scans';
      case ChallengeType.weight:
        return 'Weight';
      case ChallengeType.custom:
        return 'Custom';
    }
  }

  String get icon {
    switch (this) {
      case ChallengeType.streak:
        return 'bolt';
      case ChallengeType.calorie:
        return 'fire';
      case ChallengeType.protein:
        return 'fitness_center';
      case ChallengeType.scans:
        return 'camera';
      case ChallengeType.weight:
        return 'monitor_weight';
      case ChallengeType.custom:
        return 'star';
    }
  }

  Color get color {
    switch (this) {
      case ChallengeType.streak:
        return Colors.red;
      case ChallengeType.calorie:
        return Colors.orange;
      case ChallengeType.protein:
        return Colors.green;
      case ChallengeType.scans:
        return Colors.blue;
      case ChallengeType.weight:
        return Colors.purple;
      case ChallengeType.custom:
        return Colors.grey;
    }
  }
}

extension ChallengeDifficultyExtension on ChallengeDifficulty {
  String get displayName {
    switch (this) {
      case ChallengeDifficulty.easy:
        return 'Easy';
      case ChallengeDifficulty.medium:
        return 'Medium';
      case ChallengeDifficulty.hard:
        return 'Hard';
      case ChallengeDifficulty.expert:
        return 'Expert';
    }
  }

  Color get color {
    switch (this) {
      case ChallengeDifficulty.easy:
        return Colors.green;
      case ChallengeDifficulty.medium:
        return Colors.orange;
      case ChallengeDifficulty.hard:
        return Colors.red;
      case ChallengeDifficulty.expert:
        return Colors.purple;
    }
  }
}
