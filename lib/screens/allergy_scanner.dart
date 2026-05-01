import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../services/theme_service.dart';
import '../services/allergy_scanner_service.dart';
import '../services/barcode_scanner_service.dart';
import '../services/gesture_service.dart';
import '../services/gamification_service.dart';

class AllergyScanner extends StatefulWidget {
  const AllergyScanner({Key? key}) : super(key: key);

  @override
  State<AllergyScanner> createState() => _AllergyScannerState();
}

class _AllergyScannerState extends State<AllergyScanner>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  bool _isScanning = false;
  bool _showSettings = false;
  String? _lastScannedBarcode;
  AllergyScanResult? _lastScanResult;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
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

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    _animationController.forward();
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
            colors: [
              Theme.of(context).colorScheme.primary.withOpacity(0.05),
              Theme.of(context).colorScheme.secondary.withOpacity(0.05),
            ],
          ),
        ),
        child: CustomScrollView(
          slivers: [
            _buildAppBar(),
            if (!_showSettings) ...[
              _buildScannerSection(),
              _buildQuickActions(),
              _buildRecentScans(),
            ] else ...[
              _buildSettingsSection(),
            ],
          ],
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Allergy Scanner',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            Text(
              'Scan products for allergens & dietary restrictions',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
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
                Theme.of(context).colorScheme.error.withOpacity(0.8),
                Theme.of(context).colorScheme.error.withOpacity(0.4),
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
      actions: [
        IconButton(
          icon: Icon(
            _showSettings ? FontAwesomeIcons.times : FontAwesomeIcons.cog,
          ),
          onPressed: () => setState(() => _showSettings = !_showSettings),
        ),
      ],
    );
  }

  Widget _buildScannerSection() {
    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverToBoxAdapter(
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: child,
              ),
            );
          },
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Container(
              height: 300,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Theme.of(context).colorScheme.surface,
                    Theme.of(context).colorScheme.surface.withOpacity(0.8),
                  ],
                ),
              ),
              child: Stack(
                children: [
                  if (_isScanning)
                    _buildScannerView()
                  else
                    _buildScannerPlaceholder(),
                  if (_lastScanResult != null)
                    _buildScanResultOverlay(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScannerView() {
    return MobileScanner(
      controller: MobileScannerController(
        detectionSpeed: DetectionSpeed.normal,
        facing: CameraFacing.back,
        torchEnabled: false,
      ),
      onDetect: (capture) {
        if (!_isScanning) return;
        
        final String? scannedValue = capture.raw?.toString();
        if (scannedValue != null && scannedValue != _lastScannedBarcode) {
          _lastScannedBarcode = scannedValue;
          _processScan(scannedValue);
        }
      },
    );
  }

  Widget _buildScannerPlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(50),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary,
              width: 3,
            ),
          ),
          child: Icon(
            FontAwesomeIcons.barcode,
            color: Theme.of(context).colorScheme.primary,
            size: 40,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Ready to Scan',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Position barcode in the frame',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: _startScanning,
          icon: const Icon(FontAwesomeIcons.camera),
          label: const Text('Start Scanning'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildScanResultOverlay() {
    if (_lastScanResult == null) return const SizedBox.shrink();

    final isSafe = _lastScanResult!.isSafe;
    
    return Positioned(
      bottom: 20,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSafe ? Colors.green.withOpacity(0.9) : Colors.red.withOpacity(0.9),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isSafe ? FontAwesomeIcons.checkCircle : FontAwesomeIcons.exclamationTriangle,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                  _lastScanResult!.warning,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              ],
            ),
            if (!isSafe && _lastScanResult!.detectedAllergens.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Allergens: ${_lastScanResult!.detectedAllergens.map((a) => a.displayName).join(', ')}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ],
            if (!isSafe && _lastScanResult!.dietaryViolations.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Violations: ${_lastScanResult!.dietaryViolations.map((v) => v.restriction.displayName).join(', ')}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _processScan(String barcode) async {
    setState(() {
      _isScanning = false;
    });

    try {
      final result = await AllergyScannerService.instance.scanProduct(barcode);
      
      setState(() {
        _lastScanResult = result;
      });

      // Award points for scanning
      await GamificationService.instance.awardPoints(
        5,
        reason: 'Product allergy scan',
      );

      // Show detailed results
      _showScanResults(result);
    } catch (e) {
      print('Error processing scan: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error scanning product. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _startScanning() {
    setState(() {
      _isScanning = true;
      _lastScanResult = null;
      _lastScannedBarcode = null;
    });
  }

  void _showScanResults(AllergyScanResult result) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildScanResultsSheet(result),
    );
  }

  Widget _buildScanResultsSheet(AllergyScanResult result) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: result.isSafe ? Colors.green : Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    result.isSafe ? FontAwesomeIcons.check : FontAwesomeIcons.times,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        result.isSafe ? 'Safe to Consume' : 'Not Safe',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: result.isSafe ? Colors.green : Colors.red,
                        ),
                      ),
                      Text(
                        result.warning,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (result.detectedAllergens.isNotEmpty) ...[
                    Text(
                      'Detected Allergens',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...result.detectedAllergens.map((allergen) => _buildAllergenChip(allergen)),
                    const SizedBox(height: 24),
                  ],
                  if (result.dietaryViolations.isNotEmpty) ...[
                    Text(
                      'Dietary Violations',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...result.dietaryViolations.map((violation) => _buildViolationCard(violation)),
                    const SizedBox(height: 24),
                  ],
                  Text(
                    'Recommendations',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...result.recommendations.map((recommendation) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          FontAwesomeIcons.infoCircle,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            recommendation,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllergenChip(Allergen allergen) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: allergen.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: allergen.color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(
            FontAwesomeIcons.exclamationTriangle,
            color: allergen.color,
            size: 20,
          ),
          const SizedBox(width: 12),
          Text(
            allergen.displayName,
            style: TextStyle(
              color: allergen.color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViolationCard(DietaryViolation violation) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
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
                    color: violation.severity.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    FontAwesomeIcons.alert,
                    color: violation.severity.color,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        violation.restriction.displayName,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        violation.details,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: violation.severity.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    violation.severity.displayName,
                    style: TextStyle(
                      color: violation.severity.color,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Actions',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildQuickActionButton(
                    icon: FontAwesomeIcons.history,
                    label: 'Scan History',
                    color: Colors.blue,
                    onTap: _showScanHistory,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickActionButton(
                    icon: FontAwesomeIcons.user,
                    label: 'My Profile',
                    color: Colors.green,
                    onTap: _showUserSettings,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickActionButton(
                    icon: FontAwesomeIcons.search,
                    label: 'Manual Search',
                    color: Colors.orange,
                    onTap: _showManualSearch,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
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
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentScans() {
    final scanHistory = AllergyScannerService.instance.scanHistory;
    
    if (scanHistory.isEmpty) {
      return SliverPadding(
        padding: const EdgeInsets.all(16),
        sliver: SliverToBoxAdapter(
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(
                    FontAwesomeIcons.barcode,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No scans yet',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Start scanning products to build your history',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[500],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          Text(
            'Recent Scans',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...scanHistory.take(5).map((scan) => _buildScanHistoryItem(scan)),
        ]),
      ),
    );
  }

  Widget _buildScanHistoryItem(AllergyScan scan) {
    return GestureService.instance.slideToDelete(
      onDelete: () => _deleteScan(scan.id),
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: scan.isSafe ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              scan.isSafe ? FontAwesomeIcons.check : FontAwesomeIcons.times,
              color: scan.isSafe ? Colors.green : Colors.red,
              size: 20,
            ),
          ),
          title: Text(
            scan.productName,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            '${scan.timestamp.day}/${scan.timestamp.month}/${scan.timestamp.year}',
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
      ),
    );
  }

  Widget _buildSettingsSection() {
    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          _buildAllergenSettings(),
          const SizedBox(height: 24),
          _buildDietarySettings(),
        ]),
      ),
    );
  }

  Widget _buildAllergenSettings() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  FontAwesomeIcons.exclamationTriangle,
                  color: Colors.red,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'My Allergies',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: Allergen.values.map((allergen) {
                final isSelected = AllergyScannerService.instance.userAllergies.contains(allergen);
                return FilterChip(
                  label: Text(allergen.displayName),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      AllergyScannerService.instance.addAllergy(allergen);
                    } else {
                      AllergyScannerService.instance.removeAllergy(allergen);
                    }
                    setState(() {});
                  },
                  backgroundColor: isSelected ? allergen.color.withOpacity(0.1) : null,
                  selectedColor: allergen.color,
                  checkmarkColor: Colors.white,
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDietarySettings() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  FontAwesomeIcons.leaf,
                  color: Colors.green,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Dietary Restrictions',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: DietaryRestriction.values.map((restriction) {
                final isSelected = AllergyScannerService.instance.dietaryRestrictions.contains(restriction);
                return FilterChip(
                  label: Text(restriction.displayName),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      AllergyScannerService.instance.addDietaryRestriction(restriction);
                    } else {
                      AllergyScannerService.instance.removeDietaryRestriction(restriction);
                    }
                    setState(() {});
                  },
                  backgroundColor: isSelected ? restriction.color.withOpacity(0.1) : null,
                  selectedColor: restriction.color,
                  checkmarkColor: Colors.white,
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return GestureService.instance.hapticGestureDetector(
      onTap: _startScanning,
      hapticType: HapticType.medium,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.error,
              Theme.of(context).colorScheme.error.withOpacity(0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).colorScheme.error.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: _isScanning
            ? const CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              )
            : const Icon(
                FontAwesomeIcons.barcode,
                color: Colors.white,
                size: 24,
              ),
      ),
    );
  }

  void _showScanHistory() {
    // Navigate to scan history screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ScanHistoryScreen(),
      ),
    );
  }

  void _showUserSettings() {
    // Navigate to user settings screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const UserAllergyProfileScreen(),
      ),
    );
  }

  void _showManualSearch() {
    // Show manual search dialog
    showDialog(
      context: context,
      builder: (context) => _buildManualSearchDialog(),
    );
  }

  Widget _buildManualSearchDialog() {
    final controller = TextEditingController();
    
    return AlertDialog(
      title: const Text('Manual Product Search'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Product Name or Barcode',
              hintText: 'Enter product details',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            // Implement manual search
          },
          child: const Text('Search'),
        ),
      ],
    );
  }

  void _deleteScan(String scanId) {
    // Implement delete functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Scan deleted'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            // Restore scan
          },
        ),
      ),
    );
  }
}

// Additional screens for the allergy scanner
class ScanHistoryScreen extends StatelessWidget {
  const ScanHistoryScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final scanHistory = AllergyScannerService.instance.scanHistory;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan History'),
      ),
      body: scanHistory.isEmpty
          ? const Center(
              child: Text('No scans yet'),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: scanHistory.length,
              itemBuilder: (context, index) {
                final scan = scanHistory[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: scan.isSafe ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        scan.isSafe ? FontAwesomeIcons.check : FontAwesomeIcons.times,
                        color: scan.isSafe ? Colors.green : Colors.red,
                        size: 20,
                      ),
                    ),
                    title: Text(scan.productName),
                    subtitle: Text('${scan.timestamp.day}/${scan.timestamp.month}/${scan.timestamp.year}'),
                    trailing: Text(
                      scan.isSafe ? 'Safe' : 'Unsafe',
                      style: TextStyle(
                        color: scan.isSafe ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class UserAllergyProfileScreen extends StatelessWidget {
  const UserAllergyProfileScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final service = AllergyScannerService.instance;
    final stats = service.getScanStatistics();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Allergy Profile'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Scan Statistics',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('Total Scans: ${stats['total_scans']}'),
                    Text('Safe Scans: ${stats['safe_scans']}'),
                    Text('Safety Rate: ${stats['safety_rate']}%'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'My Allergies',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...service.userAllergies.map((allergen) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Icon(
                            FontAwesomeIcons.exclamationTriangle,
                            color: allergen.color,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Text(allergen.displayName),
                        ],
                      ),
                    )),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dietary Restrictions',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...service.dietaryRestrictions.map((restriction) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Icon(
                            FontAwesomeIcons.leaf,
                            color: restriction.color,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Text(restriction.displayName),
                        ],
                      ),
                    )),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
