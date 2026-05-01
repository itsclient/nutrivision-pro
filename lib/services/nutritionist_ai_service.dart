import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'ai_config.dart';
import 'auth_service.dart';
import 'advanced_analytics_service.dart';
import 'goal_tracking_service.dart';
import 'settings_service.dart';

class NutritionistAIService {
  static final NutritionistAIService instance = NutritionistAIService._init();
  NutritionistAIService._init();

  static const String _chatHistoryKey = 'nutritionist_chat_history';
  static const String _userProfileKey = 'nutritionist_user_profile';

  List<ChatMessage> _chatHistory = [];
  UserProfile? _userProfile;
  bool _isLoading = false;

  List<ChatMessage> get chatHistory => _chatHistory;
  UserProfile? get userProfile => _userProfile;
  bool get isLoading => _isLoading;

  // Initialize service
  Future<void> initialize() async {
    await _loadChatHistory();
    await _loadUserProfile();
    await _updateUserProfile();
  }

  // Load chat history
  Future<void> _loadChatHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getString(_chatHistoryKey);
    
    if (historyJson != null) {
      final historyList = jsonDecode(historyJson) as List;
      _chatHistory = historyList.map((e) => ChatMessage.fromJson(e)).toList();
    }
  }

  // Load user profile
  Future<void> _loadUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final profileJson = prefs.getString(_userProfileKey);
    
    if (profileJson != null) {
      _userProfile = UserProfile.fromJson(jsonDecode(profileJson));
    } else {
      _userProfile = UserProfile();
    }
  }

  // Save chat history
  Future<void> _saveChatHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_chatHistoryKey, jsonEncode(
      _chatHistory.map((e) => e.toJson()).toList()
    ));
  }

  // Save user profile
  Future<void> _saveUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userProfileKey, jsonEncode(_userProfile!.toJson()));
  }

  // Update user profile with current data
  Future<void> _updateUserProfile() async {
    if (_userProfile == null) return;

    // Get current analytics data
    await AdvancedAnalyticsService.instance.fetchAnalytics();
    final analytics = AdvancedAnalyticsService.instance;
    
    // Get current goals
    final goals = GoalTrackingService.instance.activeGoals;
    
    // Get current settings
    final settings = SettingsService.instance;

    _userProfile!.updateFromCurrentData(
      dailyCalorieGoal: settings.dailyCalorieGoal,
      dailyProteinGoal: settings.dailyProteinGoal,
      currentStreak: settings.scanStreak,
      recentCalories: analytics.dailyStats.isNotEmpty ? analytics.dailyStats.first.totalCalories : 0,
      activeGoals: goals.length,
      lastUpdated: DateTime.now(),
    );

    await _saveUserProfile();
  }

  // Send message to AI nutritionist
  Future<ChatMessage> sendMessage(String message) async {
    if (_isLoading) throw Exception('Already processing a message');

    _isLoading = true;

    try {
      // Add user message to history
      final userMessage = ChatMessage(
        id: const Uuid().v4(),
        text: message,
        sender: MessageSender.user,
        timestamp: DateTime.now(),
      );
      
      _chatHistory.add(userMessage);
      await _saveChatHistory();

      // Generate AI response
      final aiResponse = await _generateAIResponse(message);
      
      _chatHistory.add(aiResponse);
      await _saveChatHistory();

      _isLoading = false;
      return aiResponse;
    } catch (e) {
      _isLoading = false;
      rethrow;
    }
  }

  // Generate AI response
  Future<ChatMessage> _generateAIResponse(String userMessage) async {
    try {
      // Build context for AI
      final context = _buildAIContext();
      
      // Create prompt
      final prompt = _createPrompt(userMessage, context);
      
      // Call AI API
      final response = await _callAI(prompt);
      
      // Parse response
      final aiMessage = ChatMessage(
        id: const Uuid().v4(),
        text: response,
        sender: MessageSender.ai,
        timestamp: DateTime.now(),
      );
      
      return aiMessage;
    } catch (e) {
      print('Error generating AI response: $e');
      
      // Return fallback response
      return ChatMessage(
        id: const Uuid().v4(),
        text: _getFallbackResponse(userMessage),
        sender: MessageSender.ai,
        timestamp: DateTime.now(),
      );
    }
  }

  // Build AI context
  Map<String, dynamic> _buildAIContext() {
    return {
      'user_profile': _userProfile?.toJson(),
      'current_date': DateTime.now().toIso8601String(),
      'chat_history_length': _chatHistory.length,
      'recent_messages': _chatHistory.takeLast(5).map((m) => {
        'text': m.text,
        'sender': m.sender.toString(),
        'timestamp': m.timestamp.toIso8601String(),
      }).toList(),
    };
  }

  // Create AI prompt
  String _createPrompt(String userMessage, Map<String, dynamic> context) {
    final profile = context['user_profile'];
    final currentDate = context['current_date'];
    
    return '''
You are a professional AI nutritionist and health coach. You're helping a user with their nutrition and health goals.

User Profile:
- Daily Calorie Goal: ${profile?['daily_calorie_goal'] ?? 'Not set'}
- Daily Protein Goal: ${profile?['daily_protein_goal'] ?? 'Not set'}g
- Current Streak: ${profile?['current_streak'] ?? 0} days
- Active Goals: ${profile?['active_goals'] ?? 0}
- Dietary Preferences: ${profile?['dietary_preferences']?.join(', ') ?? 'None specified'}
- Allergies: ${profile?['allergies']?.join(', ') ?? 'None specified'}
- Health Goals: ${profile?['health_goals']?.join(', ') ?? 'None specified'}

Current Date: $currentDate

Recent Chat Context: ${context['recent_messages']}

User Message: "$userMessage"

Please provide a helpful, personalized response that:
1. Addresses their specific question or concern
2. Takes into account their profile and goals
3. Provides actionable advice
4. Is encouraging and supportive
5. Is concise but thorough
6. Includes specific recommendations when appropriate

Keep your response conversational and friendly, like a real nutritionist would speak.
''';
  }

  // Call AI API
  Future<String> _callAI(String prompt) async {
    if (AIConfig.groqApiKey == 'YOUR_GROQ_API_KEY_HERE') {
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
              'content': 'You are a professional AI nutritionist and health coach. Provide helpful, evidence-based nutrition advice.',
            },
            {
              'role': 'user',
              'content': prompt,
            },
          ],
          'temperature': 0.7,
          'max_tokens': 1000,
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

  // Generate mock response when API is not available
  String _generateMockResponse(String prompt) {
    final lowerPrompt = prompt.toLowerCase();
    
    if (lowerPrompt.contains('calorie') || lowerPrompt.contains('calories')) {
      return '''
Based on your profile, I see your daily calorie goal is ${_userProfile?.dailyCalorieGoal ?? 2000} calories. 

Here are some tips to help you stay on track:
- Focus on nutrient-dense foods that keep you full longer
- Try eating smaller, more frequent meals throughout the day
- Stay hydrated - sometimes thirst is mistaken for hunger
- Include protein with each meal to help with satiety

Would you like some specific meal suggestions that fit your calorie goal?
''';
    }
    
    if (lowerPrompt.contains('protein')) {
      return '''
Great question about protein! Your daily protein goal is ${_userProfile?.dailyProteinGoal ?? 50}g.

Protein is essential for:
- Muscle maintenance and growth
- Feeling full and satisfied
- Stable blood sugar levels
- Healthy metabolism

Try incorporating these high-protein options:
- Greek yogurt (15-20g per serving)
- Chicken breast (25g per 3oz)
- Lentils and beans (15-18g per cup)
- Quinoa (8g per cup)
- Eggs (6g per large egg)

How does your current protein intake look?
''';
    }
    
    if (lowerPrompt.contains('weight') || lowerPrompt.contains('lose')) {
      return '''
Weight management is about finding the right balance for your body! 

Since you have a ${_userProfile?.currentStreak ?? 0}-day streak, you're already building great habits.

For healthy weight management:
- Focus on whole, unprocessed foods
- Include plenty of vegetables for volume and nutrients
- Practice mindful eating - slow down and enjoy your food
- Get adequate sleep (7-9 hours per night)
- Stay consistent with your tracking

What specific aspect of weight management would you like to focus on?
''';
    }
    
    if (lowerPrompt.contains('meal') || lowerPrompt.contains('food')) {
      return '''
I'd be happy to help with meal planning! 

Based on your goals, here's a sample day:
- **Breakfast**: Greek yogurt parfait with berries and nuts (~300 calories)
- **Lunch**: Grilled chicken salad with mixed vegetables (~400 calories)
- **Snack**: Apple with almond butter (~150 calories)
- **Dinner**: Baked salmon with quinoa and roasted vegetables (~500 calories)

This gives you about 1350 calories, leaving room for healthy snacks or adjustments.

Would you like more specific meal ideas or help with meal prep?
''';
    }
    
    if (lowerPrompt.contains('help') || lowerPrompt.contains('advice')) {
      return '''
I'm here to help you reach your nutrition goals! 

Based on your profile, I can assist with:
- Meal planning and recipe ideas
- Understanding your nutritional needs
- Setting realistic goals
- Troubleshooting challenges
- Celebrating your progress

You're doing great with your ${_userProfile?.currentStreak ?? 0}-day streak! That consistency is key to long-term success.

What specific nutrition question or challenge can I help you with today?
''';
    }
    
    return '''
I'm here to help with your nutrition journey! Based on your current progress and goals, I can provide personalized advice on meal planning, nutritional guidance, and support to help you succeed.

What specific nutrition question or concern would you like to discuss today?
''';
  }

  // Get fallback response
  String _getFallbackResponse(String userMessage) {
    return '''
I apologize, but I'm having trouble connecting right now. Here's some general advice:

For healthy nutrition:
- Focus on whole, unprocessed foods
- Include plenty of vegetables and fruits
- Choose lean proteins and healthy fats
- Stay hydrated throughout the day
- Listen to your body's hunger cues

Please try again in a moment, and I'll be happy to provide more personalized advice based on your specific goals and profile!
''';
  }

  // Get conversation suggestions
  List<String> getConversationSuggestions() {
    final suggestions = [
      'What should I eat today?',
      'How can I increase my protein intake?',
      'Help me with meal planning',
      'What are healthy snack options?',
      'How do I stay on track with my goals?',
      'Can you suggest some recipes?',
      'How do I read nutrition labels?',
      'What about supplements?',
      'How to handle cravings?',
      'Tips for eating out?',
    ];

    // Add personalized suggestions based on user profile
    if (_userProfile != null) {
      if (_userProfile!.currentStreak >= 7) {
        suggestions.insert(0, 'How can I maintain my streak?');
      }
      
      if (_userProfile!.dailyCalorieGoal > 0) {
        suggestions.insert(0, 'Meal ideas for ${_userProfile!.dailyCalorieGoal} calories');
      }
      
      if (_userProfile!.healthGoals.contains('weight_loss')) {
        suggestions.insert(0, 'Tips for healthy weight loss');
      }
    }

    return suggestions.take(6).toList();
  }

  // Clear chat history
  Future<void> clearChatHistory() async {
    _chatHistory.clear();
    await _saveChatHistory();
  }

  // Export chat history
  String exportChatHistory() {
    final exportData = {
      'export_date': DateTime.now().toIso8601String(),
      'user_profile': _userProfile?.toJson(),
      'chat_history': _chatHistory.map((e) => e.toJson()).toList(),
    };
    
    return jsonEncode(exportData);
  }

  // Get chat statistics
  Map<String, dynamic> getChatStatistics() {
    final totalMessages = _chatHistory.length;
    final userMessages = _chatHistory.where((m) => m.sender == MessageSender.user).length;
    final aiMessages = _chatHistory.where((m) => m.sender == MessageSender.ai).length;
    
    // Calculate average message length
    final avgUserMessageLength = userMessages > 0 
        ? _chatHistory
            .where((m) => m.sender == MessageSender.user)
            .map((m) => m.text.length)
            .reduce((a, b) => a + b) / userMessages
        : 0.0;
    
    // Get most discussed topics (simple keyword analysis)
    final topicCounts = <String, int>{};
    for (final message in _chatHistory) {
      if (message.sender == MessageSender.user) {
        final text = message.text.toLowerCase();
        if (text.contains('calorie')) topicCounts['calories'] = (topicCounts['calories'] ?? 0) + 1;
        if (text.contains('protein')) topicCounts['protein'] = (topicCounts['protein'] ?? 0) + 1;
        if (text.contains('weight')) topicCounts['weight'] = (topicCounts['weight'] ?? 0) + 1;
        if (text.contains('meal')) topicCounts['meals'] = (topicCounts['meals'] ?? 0) + 1;
      }
    }
    
    return {
      'total_messages': totalMessages,
      'user_messages': userMessages,
      'ai_messages': aiMessages,
      'avg_user_message_length': avgUserMessageLength.round(),
      'most_discussed_topics': topicCounts,
      'first_message_date': _chatHistory.isNotEmpty ? _chatHistory.first.timestamp.toIso8601String() : null,
      'last_message_date': _chatHistory.isNotEmpty ? _chatHistory.last.timestamp.toIso8601String() : null,
    };
  }

  // Update user preferences
  Future<void> updateUserPreferences({
    int? dailyCalorieGoal,
    double? dailyProteinGoal,
    List<String>? dietaryPreferences,
    List<String>? allergies,
    List<String>? healthGoals,
  }) async {
    if (_userProfile == null) return;

    if (dailyCalorieGoal != null) _userProfile!.dailyCalorieGoal = dailyCalorieGoal;
    if (dailyProteinGoal != null) _userProfile!.dailyProteinGoal = dailyProteinGoal;
    if (dietaryPreferences != null) _userProfile!.dietaryPreferences = dietaryPreferences;
    if (allergies != null) _userProfile!.allergies = allergies;
    if (healthGoals != null) _userProfile!.healthGoals = healthGoals;

    await _saveUserProfile();
  }
}

// Data models
class ChatMessage {
  final String id;
  final String text;
  final MessageSender sender;
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.text,
    required this.sender,
    required this.timestamp,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] ?? '',
      text: json['text'] ?? '',
      sender: MessageSender.values.firstWhere(
        (e) => e.toString() == 'MessageSender.${json['sender']}',
        orElse: () => MessageSender.user,
      ),
      timestamp: DateTime.parse(json['timestamp']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'sender': sender.toString().split('.').last,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

class UserProfile {
  int dailyCalorieGoal;
  double dailyProteinGoal;
  int currentStreak;
  int recentCalories;
  int activeGoals;
  List<String> dietaryPreferences;
  List<String> allergies;
  List<String> healthGoals;
  DateTime lastUpdated;

  UserProfile({
    this.dailyCalorieGoal = 2000,
    this.dailyProteinGoal = 50.0,
    this.currentStreak = 0,
    this.recentCalories = 0,
    this.activeGoals = 0,
    this.dietaryPreferences = const [],
    this.allergies = const [],
    this.healthGoals = const [],
    DateTime? lastUpdated,
  }) : lastUpdated = lastUpdated ?? DateTime.now();

  void updateFromCurrentData({
    required int dailyCalorieGoal,
    required double dailyProteinGoal,
    required int currentStreak,
    required int recentCalories,
    required int activeGoals,
    required DateTime lastUpdated,
  }) {
    this.dailyCalorieGoal = dailyCalorieGoal;
    this.dailyProteinGoal = dailyProteinGoal;
    this.currentStreak = currentStreak;
    this.recentCalories = recentCalories;
    this.activeGoals = activeGoals;
    this.lastUpdated = lastUpdated;
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      dailyCalorieGoal: json['daily_calorie_goal'] ?? 2000,
      dailyProteinGoal: (json['daily_protein_goal'] ?? 50.0).toDouble(),
      currentStreak: json['current_streak'] ?? 0,
      recentCalories: json['recent_calories'] ?? 0,
      activeGoals: json['active_goals'] ?? 0,
      dietaryPreferences: List<String>.from(json['dietary_preferences'] ?? []),
      allergies: List<String>.from(json['allergies'] ?? []),
      healthGoals: List<String>.from(json['health_goals'] ?? []),
      lastUpdated: DateTime.parse(json['last_updated']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'daily_calorie_goal': dailyCalorieGoal,
      'daily_protein_goal': dailyProteinGoal,
      'current_streak': currentStreak,
      'recent_calories': recentCalories,
      'active_goals': activeGoals,
      'dietary_preferences': dietaryPreferences,
      'allergies': allergies,
      'health_goals': healthGoals,
      'last_updated': lastUpdated.toIso8601String(),
    };
  }
}

enum MessageSender {
  user,
  ai,
}
