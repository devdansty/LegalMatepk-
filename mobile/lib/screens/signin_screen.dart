import 'dart:convert';
import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'role_selection_screen.dart';

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
  bool hidePassword = true;

  Future<void> _quickLoginAsRole(String role) async {
    if (role == 'lawyer') {
      try {
        final response = await http.post(
          Uri.parse('http://192.168.0.105:3000/api/lawyers/dev-login'),
          headers: {'Content-Type': 'application/json'},
        );

        final data = response.body.isNotEmpty ? jsonDecode(response.body) : {};

        if (response.statusCode == 200) {
          final accessToken = data['access_token'];
          final user = data['user'];

          if (accessToken != null) {
            await secureStorage.write(key: 'accessToken', value: accessToken.toString());
          }

          await secureStorage.write(
            key: 'role',
            value: (user?['role'] ?? 'lawyer').toString(),
          );
        } else {
          final error = (data is Map && data['error'] != null)
              ? data['error'].toString()
              : 'Unable to start lawyer test mode';
          if (!mounted) return;
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(error)));
          return;
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Server error starting lawyer test mode')),
        );
        return;
      }
    } else {
      try {
        final response = await http.post(
          Uri.parse('http://192.168.0.105:3000/api/users/dev-guest-login'),
          headers: {'Content-Type': 'application/json'},
        );

        final data = response.body.isNotEmpty ? jsonDecode(response.body) : {};

        if (response.statusCode == 200) {
          final accessToken = data['access_token'];
          final user = data['user'];

          if (accessToken != null) {
            await secureStorage.write(key: 'accessToken', value: accessToken.toString());
          }

          await secureStorage.write(
            key: 'role',
            value: (user?['role'] ?? 'citizen').toString(),
          );
        } else {
          final error = (data is Map && data['error'] != null)
              ? data['error'].toString()
              : 'Unable to start guest mode';
          if (!mounted) return;
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(error)));
          return;
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Server error starting guest mode')),
        );
        return;
      }
    }

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LegalMateHome()),
    );
  }

  Future<void> signin() async {
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Email and password are required")),
      );
      return;
    }

    setState(() => loading = true);

    final url = Uri.parse('http://192.168.0.105:3000/api/users/signin');
    final body = jsonEncode({
      "email": email,
      "password": password,
    });

    try {
      final res = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: body,
      );

      final data = res.body.isNotEmpty ? jsonDecode(res.body) : {};

      if (res.statusCode == 200) {
        final accessToken = data['access_token'] ?? data['accessToken'];
        final user = data['user'];

        if (accessToken != null) {
          await secureStorage.write(key: 'accessToken', value: accessToken);
        }

        final role = user?['role'] ?? 'citizen';
        await secureStorage.write(key: 'role', value: role);

        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LegalMateHome()),
        );
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
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
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
                      MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
                    );
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
                    _quickLoginAsRole("citizen");
                  },
                  child: const Text(
                    "Log in as Guest",
                    style: TextStyle(color: Colors.black54),
                  ),
                ),
              ),
              Center(
                child: TextButton(
                  onPressed: () {
                    _quickLoginAsRole("lawyer");
                  },
                  child: const Text(
                    "Log in as Lawyer",
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
