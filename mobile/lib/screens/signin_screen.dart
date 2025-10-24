import 'dart:convert';
import 'package:flutter/material.dart';
import 'signup_screen.dart';
import 'chatbot_page.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// single secure storage instance
final FlutterSecureStorage secureStorage = const FlutterSecureStorage();

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool loading = false;
  bool hidePassword = true; // <-- added for show/hide

  Future<void> signin() async {
    setState(() => loading = true);

    final url = Uri.parse('http://192.168.100.147:3000/api/users/signin');
    final body = jsonEncode({
      "email": emailController.text.trim(),
      "password": passwordController.text,
    });

    try {
      final res = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: body,
      );

      final data = res.body.isNotEmpty ? jsonDecode(res.body) : {};

      if (res.statusCode == 200) {
        // Expecting server to return { accessToken, user: {...} }
        final accessToken = data['accessToken'] as String?;
        if (accessToken != null && accessToken.isNotEmpty) {
          // store access token securely for later (logout, authenticated calls)
          await secureStorage.write(key: 'accessToken', value: accessToken);
        }

        // Navigate to ChatBotPage (preserve your UI/navigation behavior)
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const ChatBotPage()),
          );
        }
      } else {
        final errMsg = (data is Map && (data['error'] != null))
            ? data['error'].toString()
            : 'Signin failed';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errMsg)));
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Server error")));
    } finally {
      setState(() => loading = false);
    }
  }

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
                "Welcome Back ",
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF006400),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Sign in to continue to LegalMate",
                style: TextStyle(color: Colors.black54, fontSize: 14),
              ),
              const SizedBox(height: 40),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: "Email"),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: hidePassword,
                decoration: InputDecoration(
                  labelText: "Password",
                  suffixIcon: IconButton(
                    icon: Icon(hidePassword ? Icons.visibility_off : Icons.visibility),
                    onPressed: () {
                      setState(() {
                        hidePassword = !hidePassword;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: loading ? null : signin,
                child: loading
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
                    : const Text("Sign In"),
              ),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: () {},
                icon: Image.asset('assets/google.png', height: 22),
                label: const Text("Sign in with Google"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF006400),
                  side: const BorderSide(color: Color(0xFF006400)),
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const SignUpScreen()));
                  },
                  child: const Text(
                    "Don't have an account? Sign Up",
                    style: TextStyle(color: Color(0xFF006400)),
                  ),
                ),
              ),
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const ChatBotPage()),
                    );
                  },
                  child: const Text(
                    "Continue as Guest",
                    style: TextStyle(color: Colors.black54),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
