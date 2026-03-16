import 'package:flutter/material.dart';
import 'citizen_signup_screen.dart';
import 'lawyer_signup_screen.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9F9),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Join LegalMate",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF006400),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Choose how you want to continue",
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 50),

            // Citizen Card
            _roleCard(
              context,
              title: "I'm a Citizen",
              subtitle: "Get legal help, AI guidance, and connect with lawyers",
              icon: Icons.person,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CitizenSignUpScreen(),
                  ),
                );
              },
            ),

            const SizedBox(height: 20),

            // Lawyer Card
            _roleCard(
              context,
              title: "I'm a Lawyer",
              subtitle: "Register your profile and receive client requests",
              icon: Icons.gavel,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const LawyerSignUpScreen(),
                  ),
                );
              },
            ),

            const Spacer(),

            // Back to login
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  "Already have an account? Login",
                  style: TextStyle(color: Color(0xFF006400)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _roleCard(
      BuildContext context, {
        required String title,
        required String subtitle,
        required IconData icon,
        required VoidCallback onTap,
      }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.green.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 3),
            )
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: const Color(0xFFE8F5E9),
              child: Icon(icon, color: const Color(0xFF006400)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16),
          ],
        ),
      ),
    );
  }
}