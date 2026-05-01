import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService extends ChangeNotifier {
  static final ThemeService instance = ThemeService._init();
  ThemeService._init();

  static const String _themeKey = 'app_theme';
  static const String _accentColorKey = 'accent_color';
  static const String _fontSizeKey = 'font_size';
  static const String _animationSpeedKey = 'animation_speed';

  AppTheme _currentTheme = AppTheme.system;
  Color _accentColor = Colors.blue;
  double _fontSize = 1.0;
  AnimationSpeed _animationSpeed = AnimationSpeed.normal;

  AppTheme get currentTheme => _currentTheme;
  Color get accentColor => _accentColor;
  double get fontSize => _fontSize;
  AnimationSpeed get animationSpeed => _animationSpeed;

  // Load theme preferences
  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    
    final themeIndex = prefs.getInt(_themeKey) ?? 0;
    _currentTheme = AppTheme.values[themeIndex];
    
    final accentColorValue = prefs.getInt(_accentColorKey);
    if (accentColorValue != null) {
      _accentColor = Color(accentColorValue);
    }
    
    _fontSize = prefs.getDouble(_fontSizeKey) ?? 1.0;
    
    final speedIndex = prefs.getInt(_animationSpeedKey) ?? 1;
    _animationSpeed = AnimationSpeed.values[speedIndex];
    
    notifyListeners();
  }

  // Save theme preferences
  Future<void> _saveTheme() async {
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.setInt(_themeKey, _currentTheme.index);
    await prefs.setInt(_accentColorKey, _accentColor.value);
    await prefs.setDouble(_fontSizeKey, _fontSize);
    await prefs.setInt(_animationSpeedKey, _animationSpeed.index);
  }

  // Set theme
  Future<void> setTheme(AppTheme theme) async {
    _currentTheme = theme;
    await _saveTheme();
    notifyListeners();
  }

  // Set accent color
  Future<void> setAccentColor(Color color) async {
    _accentColor = color;
    await _saveTheme();
    notifyListeners();
  }

  // Set font size
  Future<void> setFontSize(double size) async {
    _fontSize = size.clamp(0.8, 1.5);
    await _saveTheme();
    notifyListeners();
  }

  // Set animation speed
  Future<void> setAnimationSpeed(AnimationSpeed speed) async {
    _animationSpeed = speed;
    await _saveTheme();
    notifyListeners();
  }

  // Get theme data
  ThemeData getThemeData(BuildContext context, bool isDarkMode) {
    final brightness = _getBrightness(isDarkMode);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _accentColor,
      brightness: brightness,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      primarySwatch: _accentColor,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconColor: colorScheme.onPrimary,
        ),
      ),
      cardTheme: CardTheme(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        color: colorScheme.surface,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _accentColor, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      textTheme: TextTheme(
        displayLarge: TextStyle(
          fontSize: 32 * _fontSize,
          fontWeight: FontWeight.bold,
          color: colorScheme.onSurface,
        ),
        displayMedium: TextStyle(
          fontSize: 28 * _fontSize,
          fontWeight: FontWeight.bold,
          color: colorScheme.onSurface,
        ),
        displaySmall: TextStyle(
          fontSize: 24 * _fontSize,
          fontWeight: FontWeight.bold,
          color: colorScheme.onSurface,
        ),
        headlineLarge: TextStyle(
          fontSize: 22 * _fontSize,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
        headlineMedium: TextStyle(
          fontSize: 20 * _fontSize,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
        headlineSmall: TextStyle(
          fontSize: 18 * _fontSize,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
        titleLarge: TextStyle(
          fontSize: 16 * _fontSize,
          fontWeight: FontWeight.w500,
          color: colorScheme.onSurface,
        ),
        titleMedium: TextStyle(
          fontSize: 14 * _fontSize,
          fontWeight: FontWeight.w500,
          color: colorScheme.onSurface,
        ),
        titleSmall: TextStyle(
          fontSize: 12 * _fontSize,
          fontWeight: FontWeight.w500,
          color: colorScheme.onSurface,
        ),
        bodyLarge: TextStyle(
          fontSize: 16 * _fontSize,
          color: colorScheme.onSurface,
        ),
        bodyMedium: TextStyle(
          fontSize: 14 * _fontSize,
          color: colorScheme.onSurface,
        ),
        bodySmall: TextStyle(
          fontSize: 12 * _fontSize,
          color: colorScheme.onSurfaceVariant,
        ),
        labelLarge: TextStyle(
          fontSize: 14 * _fontSize,
          fontWeight: FontWeight.w500,
          color: colorScheme.onSurface,
        ),
        labelMedium: TextStyle(
          fontSize: 12 * _fontSize,
          fontWeight: FontWeight.w500,
          color: colorScheme.onSurface,
        ),
        labelSmall: TextStyle(
          fontSize: 10 * _fontSize,
          fontWeight: FontWeight.w500,
          color: colorScheme.onSurface,
        ),
      ),
    );
  }

  Brightness _getBrightness(bool isDarkMode) {
    switch (_currentTheme) {
      case AppTheme.light:
        return Brightness.light;
      case AppTheme.dark:
        return Brightness.dark;
      case AppTheme.system:
        return isDarkMode ? Brightness.dark : Brightness.light;
    }
  }

  // Get animation duration
  Duration getAnimationDuration() {
    switch (_animationSpeed) {
      case AnimationSpeed.slow:
        return const Duration(milliseconds: 500);
      case AnimationSpeed.normal:
        return const Duration(milliseconds: 300);
      case AnimationSpeed.fast:
        return const Duration(milliseconds: 150);
    }
  }

  // Get available accent colors
  List<Color> getAvailableAccentColors() {
    return [
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.pink,
      Colors.teal,
      Colors.indigo,
      Colors.amber,
      Colors.cyan,
    ];
  }

  // Get preset themes
  List<ThemePreset> getPresetThemes() {
    return [
      ThemePreset(
        name: 'Ocean Blue',
        accentColor: Colors.blue,
        description: 'Calm and professional blue theme',
      ),
      ThemePreset(
        name: 'Sunset Orange',
        accentColor: Colors.orange,
        description: 'Warm and energetic orange theme',
      ),
      ThemePreset(
        name: 'Forest Green',
        accentColor: Colors.green,
        description: 'Natural and refreshing green theme',
      ),
      ThemePreset(
        name: 'Royal Purple',
        accentColor: Colors.purple,
        description: 'Elegant and sophisticated purple theme',
      ),
      ThemePreset(
        name: 'Cherry Pink',
        accentColor: Colors.pink,
        description: 'Playful and vibrant pink theme',
      ),
    ];
  }

  // Apply preset theme
  Future<void> applyPresetTheme(ThemePreset preset) async {
    await setAccentColor(preset.accentColor);
  }

  // Reset to default theme
  Future<void> resetToDefault() async {
    _currentTheme = AppTheme.system;
    _accentColor = Colors.blue;
    _fontSize = 1.0;
    _animationSpeed = AnimationSpeed.normal;
    await _saveTheme();
    notifyListeners();
  }
}

enum AppTheme {
  light,
  dark,
  system,
}

enum AnimationSpeed {
  slow,
  normal,
  fast,
}

class ThemePreset {
  final String name;
  final Color accentColor;
  final String description;

  ThemePreset({
    required this.name,
    required this.accentColor,
    required this.description,
  });
}
