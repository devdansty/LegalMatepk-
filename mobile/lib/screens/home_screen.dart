import 'package:flutter/material.dart';
import 'chatbot_screen.dart';
import 'ocr_screen.dart';

class LegalMateHome extends StatelessWidget {
  const LegalMateHome({super.key});

  static const Color darkGreen = Color(0xFF004B23);
  static const Color offWhite = Color(0xFFF8F9F9);
  static const Color lightSage = Color(0xFFDDE5D7);
  static const Color creamCard = Color(0xFFFDFBF0);

  // Helper method for smooth page transitions
  void _navigateTo(BuildContext context, Widget targetPage) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => targetPage,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0); // Slide in from right
          const end = Offset.zero;
          const curve = Curves.easeInOutCubic;

          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          var offsetAnimation = animation.drive(tween);

          return SlideTransition(position: offsetAnimation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: offWhite,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: const Text(
          'LegalMate.pk',
          style: TextStyle(color: darkGreen, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 15,
          mainAxisSpacing: 15,
          childAspectRatio: 0.85,
          children: [
           // Inside LegalMateHome GridView
            _buildMenuCard(
              context,
              title: "AI Chatbot",
              subtitle: "(Law-Grounded Answers)",
              icon: Icons.psychology_outlined,
              bgColor: creamCard,
              onTap: () {
                // Navigate to your existing chatbot_page.dart
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ChatBotPage()),
                );
              },
            ),
            _buildMenuCard(
              context,
              title: "OCR + Summarization",
              subtitle: "Scan FIRs & Notices",
              icon: Icons.document_scanner_outlined,
              bgColor: lightSage,
              onTap: () => _navigateTo(context, const OcrScreen()),
            ),
            _buildMenuCard(
              context,
              title: "Document Automation",
              subtitle: "FIR drafts & Agreements",
              icon: Icons.description_outlined,
              bgColor: creamCard,
              onTap: () => _navigateTo(context, const PlaceholderScreen(title: "Docs Generator")),
            ),
             _buildMenuCard(
              context,
              title: "Lawyer Connect",
              subtitle: "Expert Consultations",
              icon: Icons.handshake_outlined,
              bgColor: lightSage,
              onTap: () => _navigateTo(context, const PlaceholderScreen(title: "Lawyer Connect")),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return InkResponse( // Using InkResponse for a better "splash" effect on tap
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: darkGreen),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}

// Temporary placeholder for your future screens
class PlaceholderScreen extends StatelessWidget {
  final String title;
  const PlaceholderScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), backgroundColor: const Color(0xFF004B23)),
      body: Center(child: Text("Welcome to the $title Screen")),
    );
  }
}