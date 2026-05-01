import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../services/theme_service.dart';
import '../services/auth_service.dart';
import '../services/settings_service.dart';
import '../services/advanced_analytics_service.dart';
import '../services/gamification_service.dart';
import '../services/goal_tracking_service.dart';
import '../services/notification_service.dart';
import '../services/smart_camera_service.dart';
import '../services/gesture_service.dart';

class InteractiveDashboard extends StatefulWidget {
  const InteractiveDashboard({Key? key}) : super(key: key);

  @override
  State<InteractiveDashboard> createState() => _InteractiveDashboardState();
}

class _InteractiveDashboardState extends State<InteractiveDashboard>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadDashboardData();
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

    _slideAnimation = Tween<double>(
      begin: 0.3,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));

    _animationController.forward();
  }

  Future<void> _loadDashboardData() async {
    try {
      await AdvancedAnalyticsService.instance.fetchAnalytics();
      await GamificationService.instance.generateDailyChallenges();
    } catch (e) {
      print('Error loading dashboard data: $e');
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: Theme.of(context).colorScheme.surface.withOpacity(0.1),
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              _buildAppBar(),
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.2,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      return AnimatedBuilder(
                        animation: _animationController,
                        builder: (context, child) {
                          return FadeTransition(
                            opacity: _fadeAnimation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: Offset(0, _slideAnimation.value),
                                end: Offset.zero,
                              ).animate(_animationController),
                              child: child,
                            ),
                          );
                        },
                        child: _buildDashboardWidget(index),
                      );
                    },
                    childCount: 6,
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverToBoxAdapter(
                  child: _buildQuickActions(),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverToBoxAdapter(
                  child: _buildProgressSection(),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverToBoxAdapter(
                  child: _buildRecentActivity(),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        title: Consumer<AuthService>(
          builder: (context, authService, child) {
            final user = authService.currentUser;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back!',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(
                  user?.name ?? 'User',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            );
          },
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).colorScheme.primary.withOpacity(0.8),
                Theme.of(context).colorScheme.primary.withOpacity(0.4),
              ],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -50,
                top: -50,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardWidget(int index) {
    switch (index) {
      case 0:
        return _buildCaloriesWidget();
      case 1:
        return _buildStreakWidget();
      case 2:
        return _buildPointsWidget();
      case 3:
        return _buildGoalsWidget();
      case 4:
        return _buildChallengesWidget();
      case 5:
        return _buildAnalyticsWidget();
      default:
        return Container();
    }
  }

  Widget _buildCaloriesWidget() {
    return GestureService.instance.hapticGestureDetector(
      onTap: () => _navigateToAnalytics(),
      child: _buildAnimatedCard(
        icon: FontAwesomeIcons.fire,
        title: 'Calories Today',
        value: '450',
        subtitle: 'of 2000 goal',
        progress: 0.23,
        color: Colors.orange,
      ),
    );
  }

  Widget _buildStreakWidget() {
    return GestureService.instance.hapticGestureDetector(
      onTap: () => _showStreakDetails(),
      child: _buildAnimatedCard(
        icon: FontAwesomeIcons.bolt,
        title: 'Current Streak',
        value: '${SettingsService.instance.scanStreak}',
        subtitle: 'days',
        progress: (SettingsService.instance.scanStreak / 7).clamp(0.0, 1.0),
        color: Colors.red,
      ),
    );
  }

  Widget _buildPointsWidget() {
    return GestureService.instance.hapticGestureDetector(
      onTap: () => _navigateToGamification(),
      child: _buildAnimatedCard(
        icon: FontAwesomeIcons.star,
        title: 'Points',
        value: '${GamificationService.instance.points}',
        subtitle: 'Level ${GamificationService.instance.level}',
        progress: GamificationService.instance.getLevelProgress(),
        color: Colors.amber,
      ),
    );
  }

  Widget _buildGoalsWidget() {
    final activeGoals = GoalTrackingService.instance.activeGoals.length;
    return GestureService.instance.hapticGestureDetector(
      onTap: () => _navigateToGoals(),
      child: _buildAnimatedCard(
        icon: FontAwesomeIcons.bullseye,
        title: 'Active Goals',
        value: '$activeGoals',
        subtitle: 'in progress',
        progress: 0.6,
        color: Colors.green,
      ),
    );
  }

  Widget _buildChallengesWidget() {
    final challenges = GamificationService.instance.activeChallenges;
    final completed = challenges.where((c) => c.completed).length;
    return GestureService.instance.hapticGestureDetector(
      onTap: () => _navigateToChallenges(),
      child: _buildAnimatedCard(
        icon: FontAwesomeIcons.trophy,
        title: 'Challenges',
        value: '$completed/${challenges.length}',
        subtitle: 'completed today',
        progress: challenges.isEmpty ? 0.0 : completed / challenges.length,
        color: Colors.purple,
      ),
    );
  }

  Widget _buildAnalyticsWidget() {
    return GestureService.instance.hapticGestureDetector(
      onTap: () => _navigateToAnalytics(),
      child: _buildAnimatedCard(
        icon: FontAwesomeIcons.chartLine,
        title: 'Analytics',
        value: 'View',
        subtitle: 'detailed stats',
        progress: 0.8,
        color: Colors.blue,
      ),
    );
  }

  Widget _buildAnimatedCard({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    required double progress,
    required Color color,
  }) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(0.1),
              color.withOpacity(0.05),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      icon,
                      color: color,
                      size: 20,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    FontAwesomeIcons.ellipsisV,
                    color: Colors.grey[400],
                    size: 16,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(color),
                borderRadius: BorderRadius.circular(10),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildQuickActionButton(
                icon: FontAwesomeIcons.camera,
                label: 'Scan Food',
                color: Colors.blue,
                onTap: () => _navigateToSmartCamera(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickActionButton(
                icon: FontAwesomeIcons.utensils,
                label: 'Log Meal',
                color: Colors.green,
                onTap: () => _logMeal(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickActionButton(
                icon: FontAwesomeIcons.chartPie,
                label: 'Analytics',
                color: Colors.orange,
                onTap: () => _navigateToAnalytics(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureService.instance.hapticGestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: color,
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Today\'s Progress',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          height: 200,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _buildProgressChart(),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressChart() {
    final data = AdvancedAnalyticsService.instance.getDailyCaloriesChart(days: 7);
    
    return LineChart(
      LineChartData(
        gridData: FlGridData(show: false),
        titlesData: FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: data,
            isCurved: true,
            color: Theme.of(context).colorScheme.primary,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            ),
          ),
        ],
        minX: 0,
        maxX: 6,
        minY: 0,
        maxY: 500,
      ),
    );
  }

  Widget _buildRecentActivity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Activity',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        _buildActivityList(),
      ],
    );
  }

  Widget _buildActivityList() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildActivityItem(
            icon: FontAwesomeIcons.camera,
            title: 'Scanned Chocolate Cake',
            subtitle: '2 hours ago',
            color: Colors.blue,
          ),
          _buildActivityItem(
            icon: FontAwesomeIcons.trophy,
            title: 'Completed Daily Challenge',
            subtitle: '4 hours ago',
            color: Colors.amber,
          ),
          _buildActivityItem(
            icon: FontAwesomeIcons.bolt,
            title: 'Streak Extended to 5 days',
            subtitle: 'Yesterday',
            color: Colors.red,
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return GestureService.instance.slideToDelete(
      onDelete: () => _deleteActivity(title),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: color,
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey[600],
          ),
        ),
        trailing: Icon(
          FontAwesomeIcons.chevronRight,
          color: Colors.grey[400],
          size: 16,
        ),
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return GestureService.instance.hapticGestureDetector(
      onTap: () => _navigateToSmartCamera(),
      hapticType: HapticType.medium,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.primary.withOpacity(0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Icon(
          FontAwesomeIcons.camera,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }

  // Navigation methods
  void _navigateToSmartCamera() {
    Navigator.pushNamed(context, '/smart_camera');
  }

  void _navigateToAnalytics() {
    Navigator.pushNamed(context, '/analytics');
  }

  void _navigateToGamification() {
    Navigator.pushNamed(context, '/gamification');
  }

  void _navigateToGoals() {
    Navigator.pushNamed(context, '/goals');
  }

  void _navigateToChallenges() {
    Navigator.pushNamed(context, '/challenges');
  }

  void _logMeal() {
    // Show meal logging dialog
    showDialog(
      context: context,
      builder: (context) => _buildMealDialog(),
    );
  }

  void _showStreakDetails() {
    // Show streak details dialog
    showDialog(
      context: context,
      builder: (context) => _buildStreakDialog(),
    );
  }

  void _deleteActivity(String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Activity deleted: $title'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            // Restore activity
          },
        ),
      ),
    );
  }

  Widget _buildMealDialog() {
    return AlertDialog(
      title: const Text('Log Meal'),
      content: const Text('Meal logging feature coming soon!'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('OK'),
        ),
      ],
    );
  }

  Widget _buildStreakDialog() {
    final streak = SettingsService.instance.scanStreak;
    return AlertDialog(
      title: Text('Current Streak: $streak days'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Great job maintaining your streak!'),
          const SizedBox(height: 16),
          if (streak >= 7)
            const Text('You\'re on fire! Keep it up!'),
          if (streak >= 30)
            const Text('Amazing dedication! You\'re a true tracker!'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Awesome!'),
        ),
      ],
    );
  }
}
