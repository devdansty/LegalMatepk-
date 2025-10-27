import 'package:flutter/material.dart';
import 'signin_screen.dart';

class SignUpScreen extends StatelessWidget {
  const SignUpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9F9),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Create Account ✨",
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF006400),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Fill in your details to get started.",
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 40),
              TextField(decoration: const InputDecoration(labelText: "Full Name")),
              const SizedBox(height: 16),
              TextField(decoration: const InputDecoration(labelText: "Email")),
              const SizedBox(height: 16),
              TextField(decoration: const InputDecoration(labelText: "Phone Number")),
              const SizedBox(height: 16),
              TextField(
                  obscureText: true,
                  decoration: const InputDecoration(labelText: "Password")),
              const SizedBox(height: 16),
              TextField(
                  obscureText: true,
                  decoration: const InputDecoration(labelText: "Confirm Password")),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushReplacement(context,
                      MaterialPageRoute(builder: (_) => const SignInScreen()));
                },
                child: const Text("Sign Up"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
