import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'chatbot_screen.dart'; 
import 'ocr_screen.dart';     
import 'signin_screen.dart';
import 'lawyer_dashboard.dart';
import 'lawyer_connect_screen.dart';
import 'lawyers_msgs.dart';
import 'legaltemplate_screen.dart';
import 'user_profile_screen.dart';
import '../config/api_config.dart';

class LegalMateHome extends StatefulWidget {
  const LegalMateHome({super.key});

  @override
  State<LegalMateHome> createState() => _LegalMateHomeState();
}

class _LegalMateHomeState extends State<LegalMateHome>
    with TickerProviderStateMixin {
  int _selectedIndex = 0;
  bool _isLoading = false;
  String? _userRole;
  final FlutterSecureStorage secureStorage = const FlutterSecureStorage();

  // Color Scheme - Consistent with signin/signup
  static const Color primaryGreen = Color(0xFF10300C);
  static const Color offWhite = Color(0xFFF8F9F9);
  static const Color darkGreen = Color(0xFF0A1F0A);
  static const Color textDark = Color(0xFF333333);
  static const Color textMedium = Color(0xFF666666);
  static const Color textLight = Color(0xFF999999);
  static const Color borderColor = Color(0xFFE0E0E0);

  // Animation controllers
  late AnimationController _entranceController;
  late List<Animation<double>> _cardAnimations;
  late Animation<double> _bannerAnimation;
  late Animation<double> _quickHelpAnimation;
  late Animation<double> _servicesAnimation;

  // Button scale animations
  late AnimationController _bannerButtonController;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    final role = await secureStorage.read(key: 'role');
    if (mounted) {
      setState(() => _userRole = role);
    }
  }

  void _setupAnimations() {
    _entranceController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    // Banner entrance
    _bannerAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.25, curve: Curves.easeOut),
      ),
    );

    // Quick help section
    _quickHelpAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.2, 0.5, curve: Curves.easeOut),
      ),
    );

    // Services section
    _servicesAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.4, 0.7, curve: Curves.easeOut),
      ),
    );

    // Card animations - staggered
    _cardAnimations = List.generate(
      4,
      (index) => Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
          parent: _entranceController,
          curve: Interval(
            0.45 + (index * 0.08),
            0.75 + (index * 0.08),
            curve: Curves.easeOut,
          ),
        ),
      ),
    );

    // Button scale animation
    _bannerButtonController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _entranceController.forward();
  }
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _bannerButtonController.dispose();
    super.dispose();
  }

  void _navigateToChatBot(String query) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatBotPage(initialQuery: query),
      ),
    ).then((_) {
      // Reset to home when returning
      setState(() => _selectedIndex = 0);
    });
  }

  void _navigateTo(Widget targetPage) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => targetPage,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOutCubic;
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return SlideTransition(position: animation.drive(tween), child: child);
        },
      ),
    ).then((_) {
      // Reset to home when returning from any navigation
      setState(() => _selectedIndex = 0);
    });
  }

  Future<void> _openLawyerConnect() async {
    final role = await secureStorage.read(key: 'role');
    if (!mounted) return;

    if (role == 'lawyer') {
      _navigateTo(const LawyerDashboard());
      return;
    }

    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const LawyerConnectScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOutCubic;
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return SlideTransition(position: animation.drive(tween), child: child);
        },
      ),
    ).then((_) {
      // Reset to home when returning
      setState(() => _selectedIndex = 0);
    });
  }

  Future<void> _navigateToProfile() async {
    final role = await secureStorage.read(key: 'role');
    if (!mounted) return;

    if (role == 'lawyer') {
      _navigateTo(const LawyerDashboard());
    } else {
      _navigateTo(const UserProfileScreen());
    }
  }

  Future<void> _completeLocalLogout() async {
    await secureStorage.delete(key: 'accessToken');
    await secureStorage.delete(key: 'role');

    if (!mounted) return;

    setState(() => _isLoading = false);
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SignInScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: offWhite,
      appBar: AppBar(
        backgroundColor: primaryGreen,
        elevation: 1,
        toolbarHeight: 70,
        title: const Text(
          'LegalMate',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        centerTitle: false,
        actions: [
          // Profile & Logout Menu
          PopupMenuButton<String>(
            onSelected: (String value) async {
              if (value == 'profile') {
                await _navigateToProfile();
              } else if (value == 'logout') {
                await _completeLocalLogout();
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(
                      Icons.person_outline,
                      color: primaryGreen,
                      size: 20,
                    ),
                    SizedBox(width: 12),
                    Text('Profile'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(
                      Icons.logout,
                      color: Colors.red,
                      size: 20,
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Logout',
                      style: TextStyle(color: Colors.red),
                    ),
                  ],
                ),
              ),
            ],
            icon: const Icon(Icons.more_vert, color: Colors.white),
            offset: const Offset(0, 70),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Banner Section
                  FadeAndSlideUp(
                    animation: _bannerAnimation,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            primaryGreen.withOpacity(0.7),
                            darkGreen,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: primaryGreen.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // const Text(
                              //   'scales',
                              //   style: TextStyle(
                              //     fontSize: 32,
                              //     height: 1.0,
                              //   ),
                              // ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "Don't Worry! We're Here",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        height: 1.2,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Your legal companion',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.9),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 10,
                            runSpacing: 8,
                            children: [
                              _buildFeatureBadge('Secure'),
                              _buildFeatureBadge('Trusted'),
                              _buildFeatureBadge('24/7 Available'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Quick Help Section
                  FadeAndSlideUp(
                    animation: _quickHelpAnimation,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'NEED URGENT HELP?',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: primaryGreen,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildQuickHelpCard(
                          icon: 'person_outline',
                          title: 'Tenant won\'t leave',
                          onTap: () => _navigateToChatBot('Tenant won\'t leave'),
                        ),
                        const SizedBox(height: 10),
                        _buildQuickHelpCard(
                          icon: 'location_on',
                          title: 'Land seized illegally',
                          onTap: () => _navigateToChatBot('Land seized illegally'),
                        ),
                        const SizedBox(height: 10),
                        _buildQuickHelpCard(
                          icon: 'mail_outline',
                          title: 'Received legal notice',
                          onTap: () => _navigateToChatBot('Received legal notice'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Services Section
                  FadeAndSlideUp(
                    animation: _servicesAnimation,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ALL SERVICES',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: primaryGreen,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.1,
                          children: [
                            _buildServiceCard(
                              index: 0,
                              icon: Icons.psychology,
                              title: 'Ask AI Lawyer',
                              subtitle: 'Instant legal help',
                              onTap: () => _navigateTo(const ChatBotPage()),
                            ),
                            _buildServiceCard(
                              index: 1,
                              icon: Icons.document_scanner,
                              title: 'Scan Document',
                              subtitle: 'Understand any paper',
                              onTap: () => _navigateTo(const OcrScreen()),
                            ),
                            _buildServiceCard(
                              index: 2,
                              icon: Icons.handshake,
                              title: 'Find a Lawyer',
                              subtitle: 'Verified lawyers',
                              onTap: _openLawyerConnect,
                            ),
                            _buildServiceCard(
                              index: 3,
                              icon: Icons.description,
                              title: 'Create Document',
                              subtitle: 'Legal documents',
                              onTap: () => _navigateTo(const DocumentAutomationScreen()),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Footer Text
                  FadeAndSlideUp(
                    animation: _servicesAnimation,
                    child: Center(
                      child: Text(
                        'Any question? Ask us freely � we don\'t judge',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: textLight,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black26,
              child: const Center(
                child: CircularProgressIndicator(color: primaryGreen),
              ),
            ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() => _selectedIndex = index);
          switch (index) {
            case 0:
              // Home - already on home
              break;
            case 1:
              _navigateToChatBot('');
              break;
            case 2:
              _navigateTo(const OcrScreen());
              break;
            case 3:
              // Lawyer or Lawyer Connect based on role
              if (_userRole == 'lawyer') {
                _navigateTo(const LawyerMessagesScreen());
              } else {
                _openLawyerConnect();
              }
              break;
            case 4:
              _navigateTo(const DocumentAutomationScreen());
              break;
          }
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: primaryGreen,
        unselectedItemColor: textLight,
        showUnselectedLabels: true,
        elevation: 8,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.chat_outlined),
            label: 'Ask AI',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.document_scanner_outlined),
            label: 'Scan',
          ),
          // Conditional item based on role
          BottomNavigationBarItem(
            icon: Icon(
              _userRole == 'lawyer' ? Icons.mail_outline : Icons.people_outline,
            ),
            label: _userRole == 'lawyer' ? 'Messages' : 'Lawyers',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.description_outlined),
            label: 'Docs',
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildQuickHelpCard({
    required String icon,
    required String title,
    required VoidCallback onTap,
  }) {
    final IconData iconData = _getIconFromString(icon);

    return ScaleOnTap(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              iconData,
              color: primaryGreen,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: textDark,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward,
              color: primaryGreen,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceCard({
    required int index,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return FadeAndSlideUp(
      animation: _cardAnimations[index],
      child: ScaleOnTap(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: primaryGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: primaryGreen,
                  size: 28,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: textDark,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: textLight,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getIconFromString(String icon) {
    switch (icon) {
      case 'person_outline':
        return Icons.person_outline;
      case 'location_on':
        return Icons.location_on;
      case 'mail_outline':
        return Icons.mail_outline;
      default:
        return Icons.help_outline;
    }
  }
}

// Custom animation widget for fade and slide up effect
class FadeAndSlideUp extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;

  const FadeAndSlideUp({
    required this.animation,
    required this.child,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Opacity(
          opacity: animation.value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - animation.value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

// Custom widget for button tap scale animation
class ScaleOnTap extends StatefulWidget {
  final VoidCallback? onTap;
  final Widget child;

  const ScaleOnTap({
    required this.onTap,
    required this.child,
    super.key,
  });

  @override
  State<ScaleOnTap> createState() => _ScaleOnTapState();
}

class _ScaleOnTapState extends State<ScaleOnTap>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _controller.reverse();
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onTap != null ? _onTapDown : null,
      onTapUp: widget.onTap != null ? _onTapUp : null,
      onTapCancel: widget.onTap != null
          ? () {
              _controller.reverse();
            }
          : null,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}

class PlaceholderScreen extends StatelessWidget {
  final String title;
  const PlaceholderScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF10300C),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(child: Text("Welcome to the $title Screen")),
    );
  }
}
