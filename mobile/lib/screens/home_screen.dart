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
import 'legaltemplate_screen.dart';
import 'user_profile_screen.dart';
import '../config/api_config.dart';

class LegalMateHome extends StatefulWidget {
  const LegalMateHome({super.key});

  @override
  State<LegalMateHome> createState() => _LegalMateHomeState();
}

class _LegalMateHomeState extends State<LegalMateHome> {
  int _selectedIndex = 0;
  bool _isLoading = false; 
  final FlutterSecureStorage secureStorage = const FlutterSecureStorage(); // Added missing instance

  static const Color darkGreen = Color(0xFF004B23);
  static const Color offWhite = Color(0xFFF8F9F9);
  static const Color creamCard = Color(0xFFFDFBF0);

  // Error Helper Method
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  // Smooth Navigation Helper
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
    );
  }

  Future<void> _openLawyerConnect() async {
    final role = await secureStorage.read(key: 'role');
    if (!mounted) return;

    if (role == 'lawyer') {
      _navigateTo(const LawyerDashboard());
      return;
    }

    _navigateTo(const LawyerConnectScreen());
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
    return Scaffold(
      backgroundColor: offWhite,
      appBar: AppBar(
        title: const Text(
          'LegalMate.pk',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: darkGreen,
        elevation: 4,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) async {
              switch (value) {
                case 'logout':
                  setState(() => _isLoading = true);
                  try {
                    final accessToken = await secureStorage.read(key: 'accessToken');

                    if (accessToken == null || accessToken.isEmpty) {
                      await _completeLocalLogout();
                      break;
                    }

                    final headers = <String, String>{
                      'Content-Type': 'application/json',
                      'Authorization': 'Bearer $accessToken',
                    };

                    final response = await http.post(
                      ApiConfig.uri('/api/sessions/logout'),
                      headers: headers,
                    );

                    if (response.statusCode == 200 || response.statusCode == 401) {
                      await _completeLocalLogout();
                    } else {
                      setState(() => _isLoading = false);
                      _showError('Logout failed: ${response.statusCode}');
                    }
                  } catch (e) {
                    setState(() => _isLoading = false);
                    _showError('Network error during logout');
                  }
                  break;
                case 'settings':
                  _showError('Settings clicked');
                  break;
                case 'profile':
                  _showError('Profile clicked');
                  break;
                case 'chat':
                  _showError('Chat clicked');
                  break;
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem(value: 'logout', child: Text('Logout')),
              const PopupMenuItem(value: 'settings', child: Text('Settings')),
              const PopupMenuItem(value: 'profile', child: Text('Profile')),
              const PopupMenuItem(value: 'chat', child: Text('Chat')),
            ],
          )
        ],
      ),
      body: Stack( // Wrapped in Stack to show Loading Indicator over content
        children: [
          Column(
            children: [
              const Spacer(),
              Center(
                child: Text(
                  "Justice Accessible For\nEveryone",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins( // Using GoogleFonts for Poppins
                    color: darkGreen,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
                child: GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 15,
                  mainAxisSpacing: 15,
                  childAspectRatio: 0.85,
                  children: [
                    _buildMenuCard(
                      title: "AI Chatbot",
                      subtitle: "(Law-Grounded Answers)",
                      icon: Icons.psychology_outlined,
                      bgColor: creamCard,
                      iconColor: darkGreen,
                      textColor: Colors.black87,
                      onTap: () => _navigateTo(const ChatBotPage()),
                    ),
                    _buildMenuCard(
                      title: "OCR + Summarization",
                      subtitle: "Scan FIRs & Notices",
                      icon: Icons.document_scanner_outlined,
                      bgColor: darkGreen,
                      iconColor: creamCard,
                      textColor: Colors.white,
                      onTap: () => _navigateTo(const OcrScreen()),
                    ),
                    _buildMenuCard(
                      title: "Document Automation",
                      subtitle: "FIR drafts & Agreements",
                      icon: Icons.description_outlined,
                      bgColor: creamCard,
                      iconColor: darkGreen,
                      textColor: Colors.black87,
                      onTap: () => _navigateTo(const DocumentAutomationScreen()),
                    ),
                    _buildMenuCard(
                      title: "Lawyer Connect",
                      subtitle: "Expert Consultations",
                      icon: Icons.handshake_outlined,
                      bgColor: darkGreen,
                      iconColor: creamCard,
                      textColor: Colors.white,
                      onTap: _openLawyerConnect,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_isLoading) // Show loading spinner during logout
            Container(
              color: Colors.black26,
              child: const Center(
                child: CircularProgressIndicator(color: darkGreen),
              ),
            ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() => _selectedIndex = index);
          
          // Handle profile navigation
          if (index == 3) {
            _navigateTo(const UserProfileScreen());
          }
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: darkGreen,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
          BottomNavigationBarItem(icon: Icon(Icons.notifications), label: 'Updates'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  Widget _buildMenuCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color bgColor,
    required Color iconColor,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: iconColor),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textColor),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, color: textColor.withOpacity(0.7)),
            ),
          ],
        ),
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
        backgroundColor: const Color(0xFF004B23),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(child: Text("Welcome to the $title Screen")),
    );
  }
}
