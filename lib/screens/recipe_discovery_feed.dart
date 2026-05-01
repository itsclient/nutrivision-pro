import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../services/theme_service.dart';
import '../services/ai_recommendations_service.dart';
import '../services/gesture_service.dart';
import '../services/gamification_service.dart';
import '../services/settings_service.dart';

class RecipeDiscoveryFeed extends StatefulWidget {
  const RecipeDiscoveryFeed({Key? key}) : super(key: key);

  @override
  State<RecipeDiscoveryFeed> createState() => _RecipeDiscoveryFeedState();
}

class _RecipeDiscoveryFeedState extends State<RecipeDiscoveryFeed>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _animationController;
  List<Recipe> _recipes = [];
  List<Recipe> _savedRecipes = [];
  List<String> _categories = ['All', 'Desserts', 'Healthy', 'Low Calorie', 'High Protein', 'Quick'];
  String _selectedCategory = 'All';
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadRecipes();
  }

  void _initializeControllers() {
    _tabController = TabController(length: 3, vsync: this);
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  Future<void> _loadRecipes() async {
    setState(() => _isLoading = true);
    
    try {
      // Load AI recommendations
      await AIRecommendationsService.instance.generateRecommendations();
      final recommendations = AIRecommendationsService.instance.recommendations;
      
      // Convert to recipes
      _recipes = recommendations.map((rec) => Recipe(
        id: rec.name.hashCode.toString(),
        name: rec.name,
        description: rec.description,
        calories: rec.calories,
        protein: rec.protein,
        carbs: 30.0, // Mock data
        fat: 8.0, // Mock data
        prepTime: 30, // Mock data
        difficulty: 'Easy',
        category: _getCategoryFromRecommendation(rec),
        imageUrl: 'https://picsum.photos/seed/${rec.name}/400/300',
        ingredients: ['Flour', 'Sugar', 'Eggs', 'Butter', 'Vanilla'],
        instructions: 'Mix ingredients and bake until golden brown.',
        rating: 4.5,
        reviews: 128,
        isSaved: false,
      )).toList();
      
      // Add more mock recipes for variety
      _recipes.addAll(_getMockRecipes());
      
      _savedRecipes = [];
    } catch (e) {
      print('Error loading recipes: $e');
      _recipes = _getMockRecipes();
    }
    
    setState(() => _isLoading = false);
  }

  String _getCategoryFromRecommendation(DessertRecommendation rec) {
    if (rec.type == 'low_calorie') return 'Low Calorie';
    if (rec.type == 'high_protein') return 'High Protein';
    if (rec.type == 'trending') return 'Desserts';
    return 'Healthy';
  }

  List<Recipe> _getMockRecipes() {
    return [
      Recipe(
        id: '1',
        name: 'Chocolate Avocado Mousse',
        description: 'Creamy, rich chocolate mousse with a healthy twist using avocado.',
        calories: 150,
        protein: 4.0,
        carbs: 12.0,
        fat: 10.0,
        prepTime: 15,
        difficulty: 'Easy',
        category: 'Healthy',
        imageUrl: 'https://picsum.photos/seed/chocolate_mousse/400/300',
        ingredients: ['Avocado', 'Cocoa powder', 'Maple syrup', 'Vanilla extract'],
        instructions: 'Blend all ingredients until smooth and refrigerate for 2 hours.',
        rating: 4.8,
        reviews: 256,
        isSaved: false,
      ),
      Recipe(
        id: '2',
        name: 'Protein-Rich Pancakes',
        description: 'Fluffy pancakes packed with protein to start your day right.',
        calories: 280,
        protein: 22.0,
        carbs: 35.0,
        fat: 8.0,
        prepTime: 20,
        difficulty: 'Easy',
        category: 'High Protein',
        imageUrl: 'https://picsum.photos/seed/pancakes/400/300',
        ingredients: ['Protein powder', 'Eggs', 'Oat flour', 'Milk', 'Banana'],
        instructions: 'Mix ingredients and cook on griddle until bubbles form.',
        rating: 4.6,
        reviews: 189,
        isSaved: false,
      ),
      Recipe(
        id: '3',
        name: 'Berry Chia Pudding',
        description: 'Overnight chia pudding with fresh berries - perfect meal prep.',
        calories: 180,
        protein: 6.0,
        carbs: 22.0,
        fat: 8.0,
        prepTime: 5,
        difficulty: 'Easy',
        category: 'Quick',
        imageUrl: 'https://picsum.photos/seed/chia_pudding/400/300',
        ingredients: ['Chia seeds', 'Almond milk', 'Berries', 'Honey', 'Vanilla'],
        instructions: 'Mix chia seeds with milk and refrigerate overnight. Top with berries.',
        rating: 4.7,
        reviews: 342,
        isSaved: false,
      ),
      Recipe(
        id: '4',
        name: 'Greek Yogurt Parfait',
        description: 'Layers of Greek yogurt, granola, and fresh fruits.',
        calories: 220,
        protein: 15.0,
        carbs: 28.0,
        fat: 6.0,
        prepTime: 10,
        difficulty: 'Easy',
        category: 'Healthy',
        imageUrl: 'https://picsum.photos/seed/parfait/400/300',
        ingredients: ['Greek yogurt', 'Granola', 'Mixed berries', 'Honey'],
        instructions: 'Layer ingredients in a glass and serve immediately.',
        rating: 4.5,
        reviews: 128,
        isSaved: false,
      ),
      Recipe(
        id: '5',
        name: 'Baked Apple Cinnamon',
        description: 'Warm baked apple with cinnamon - simple and satisfying.',
        calories: 95,
        protein: 0.5,
        carbs: 25.0,
        fat: 0.3,
        prepTime: 25,
        difficulty: 'Easy',
        category: 'Low Calorie',
        imageUrl: 'https://picsum.photos/seed/baked_apple/400/300',
        ingredients: ['Apple', 'Cinnamon', 'Nutmeg', 'Honey'],
        instructions: 'Core apple and fill with cinnamon mixture. Bake at 375°F for 25 minutes.',
        rating: 4.4,
        reviews: 89,
        isSaved: false,
      ),
    ];
  }

  @override
  void dispose() {
    _tabController.dispose();
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            _buildAppBar(),
            _buildTabBar(),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildDiscoverTab(),
            _buildSavedTab(),
            _buildRecommendedTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recipe Discovery',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Find your perfect healthy treats',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).colorScheme.primary.withOpacity(0.1),
                Theme.of(context).colorScheme.secondary.withOpacity(0.1),
              ],
            ),
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(FontAwesomeIcons.filter),
          onPressed: _showFilterDialog,
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverToBoxAdapter(
        child: TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Theme.of(context).colorScheme.primary,
          tabs: const [
            Tab(text: 'Discover'),
            Tab(text: 'Saved'),
            Tab(text: 'Recommended'),
          ],
        ),
      ),
    );
  }

  Widget _buildDiscoverTab() {
    return Column(
      children: [
        _buildSearchBar(),
        _buildCategoryFilter(),
        Expanded(
          child: _isLoading
              ? _buildLoadingIndicator()
              : _buildRecipeGrid(),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search recipes...',
          prefixIcon: const Icon(FontAwesomeIcons.search),
          suffixIcon: IconButton(
            icon: const Icon(FontAwesomeIcons.slidersH),
            onPressed: _showFilterDialog,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          fillColor: Theme.of(context).colorScheme.surface,
        ),
        onChanged: (value) {
          _filterRecipes(value);
        },
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureService.instance.swipeDetector(
        onSwipeLeft: () => _nextCategory(),
        onSwipeRight: () => _previousCategory(),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: _categories.length,
          itemBuilder: (context, index) {
            final category = _categories[index];
            final isSelected = category == _selectedCategory;
            
            return GestureService.instance.hapticGestureDetector(
              onTap: () => _selectCategory(category),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected 
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected 
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey[300]!,
                  ),
                ),
                child: Center(
                  child: Text(
                    category,
                    style: TextStyle(
                      color: isSelected 
                          ? Theme.of(context).colorScheme.onPrimary
                          : Theme.of(context).colorScheme.onSurface,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  Widget _buildRecipeGrid() {
    final filteredRecipes = _getFilteredRecipes();
    
    if (filteredRecipes.isEmpty) {
      return _buildEmptyState();
    }
    
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.7,
      ),
      itemCount: filteredRecipes.length,
      itemBuilder: (context, index) {
        return _buildRecipeCard(filteredRecipes[index]);
      },
    );
  }

  Widget _buildRecipeCard(Recipe recipe) {
    return GestureService.instance.hapticGestureDetector(
      onTap: () => _showRecipeDetails(recipe),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: CachedNetworkImage(
                      imageUrl: recipe.imageUrl,
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: Colors.grey[200],
                        child: const Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[200],
                        child: const Icon(Icons.error),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureService.instance.hapticGestureDetector(
                      onTap: () => _toggleSaveRecipe(recipe),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          recipe.isSaved ? FontAwesomeIcons.solidHeart : FontAwesomeIcons.heart,
                          color: recipe.isSaved ? Colors.red : Colors.grey[600],
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        recipe.category,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe.name,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          FontAwesomeIcons.clock,
                          size: 12,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${recipe.prepTime} min',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          FontAwesomeIcons.fire,
                          size: 12,
                          color: Colors.orange,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${recipe.calories}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          FontAwesomeIcons.star,
                          size: 12,
                          color: Colors.amber,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          recipe.rating.toString(),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          ' (${recipe.reviews})',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            FontAwesomeIcons.search,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No recipes found',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your filters or search terms',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSavedTab() {
    return _savedRecipes.isEmpty
        ? _buildEmptySavedState()
        : _buildRecipeGrid();
  }

  Widget _buildEmptySavedState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            FontAwesomeIcons.heart,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No saved recipes yet',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the heart icon to save recipes you love',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendedTab() {
    final recommendations = AIRecommendationsService.instance.recommendations;
    
    if (recommendations.isEmpty) {
      return const Center(
        child: Text('Loading recommendations...'),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: recommendations.length,
      itemBuilder: (context, index) {
        final rec = recommendations[index];
        return _buildRecommendationCard(rec);
      },
    );
  }

  Widget _buildRecommendationCard(DessertRecommendation rec) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
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
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    FontAwesomeIcons.lightbulb,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rec.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        rec.description,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildNutrientChip('Calories', '${rec.calories}', Colors.orange),
                const SizedBox(width: 8),
                _buildNutrientChip('Protein', '${rec.protein}g', Colors.green),
                const SizedBox(width: 8),
                _buildNutrientChip('Type', rec.type, Colors.blue),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNutrientChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  List<Recipe> _getFilteredRecipes() {
    var filtered = _recipes.where((recipe) {
      final matchesSearch = recipe.name.toLowerCase().contains(_searchController.text.toLowerCase()) ||
                         recipe.description.toLowerCase().contains(_searchController.text.toLowerCase());
      final matchesCategory = _selectedCategory == 'All' || recipe.category == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();
    
    return filtered;
  }

  void _filterRecipes(String query) {
    setState(() {});
  }

  void _selectCategory(String category) {
    setState(() {
      _selectedCategory = category;
    });
  }

  void _nextCategory() {
    final currentIndex = _categories.indexOf(_selectedCategory);
    final nextIndex = (currentIndex + 1) % _categories.length;
    _selectCategory(_categories[nextIndex]);
  }

  void _previousCategory() {
    final currentIndex = _categories.indexOf(_selectedCategory);
    final prevIndex = (currentIndex - 1 + _categories.length) % _categories.length;
    _selectCategory(_categories[prevIndex]);
  }

  void _toggleSaveRecipe(Recipe recipe) {
    setState(() {
      recipe.isSaved = !recipe.isSaved;
      if (recipe.isSaved) {
        _savedRecipes.add(recipe);
        GamificationService.instance.awardPoints(5, reason: 'Saved recipe');
      } else {
        _savedRecipes.remove(recipe);
      }
    });
  }

  void _showRecipeDetails(Recipe recipe) {
    // Navigate to recipe details
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RecipeDetailScreen(recipe: recipe),
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => _buildFilterDialog(),
    );
  }

  Widget _buildFilterDialog() {
    return AlertDialog(
      title: const Text('Filter Recipes'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Add filter options here
          const Text('Filter options coming soon!'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

// Data models
class Recipe {
  final String id;
  final String name;
  final String description;
  final int calories;
  final double protein;
  final double carbs;
  final double fat;
  final int prepTime;
  final String difficulty;
  final String category;
  final String imageUrl;
  final List<String> ingredients;
  final String instructions;
  final double rating;
  final int reviews;
  bool isSaved;

  Recipe({
    required this.id,
    required this.name,
    required this.description,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.prepTime,
    required this.difficulty,
    required this.category,
    required this.imageUrl,
    required this.ingredients,
    required this.instructions,
    required this.rating,
    required this.reviews,
    required this.isSaved,
  });
}

class RecipeDetailScreen extends StatelessWidget {
  final Recipe recipe;

  const RecipeDetailScreen({Key? key, required this.recipe}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: CachedNetworkImage(
                imageUrl: recipe.imageUrl,
                fit: BoxFit.cover,
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Text(
                  recipe.name,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _buildNutritionInfo(context),
                const SizedBox(height: 16),
                Text(
                  'Ingredients',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ...recipe.ingredients.map((ingredient) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text('· $ingredient'),
                )),
                const SizedBox(height: 16),
                Text(
                  'Instructions',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(recipe.instructions),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNutritionInfo(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNutrientItem('Calories', '${recipe.calories}', Colors.orange),
          _buildNutrientItem('Protein', '${recipe.protein}g', Colors.green),
          _buildNutrientItem('Carbs', '${recipe.carbs}g', Colors.blue),
          _buildNutrientItem('Fat', '${recipe.fat}g', Colors.red),
        ],
      ),
    );
  }

  Widget _buildNutrientItem(String label, String value, Color color) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
