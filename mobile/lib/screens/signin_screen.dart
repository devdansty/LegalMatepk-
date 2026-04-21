import 'dart:convert';
import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'role_selection_screen.dart';
import '../config/api_config.dart';

// single secure storage instance
final FlutterSecureStorage secureStorage = const FlutterSecureStorage();

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen>
    with TickerProviderStateMixin {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool loading = false;
  bool hidePassword = true;
  
  // Animation controllers for staggered entrance
  late AnimationController _entranceController;
  late Animation<double> _headingAnimation;
  late Animation<double> _subtitleAnimation;
  late Animation<double> _emailAnimation;
  late Animation<double> _passwordAnimation;
  late Animation<double> _buttonAnimation;
  late Animation<double> _dividerAnimation;
  late Animation<double> _socialAnimation;
  late Animation<double> _linkAnimation;
  
  // Button scale animations
  late AnimationController _loginButtonController;
  late AnimationController _googleButtonController;
  late AnimationController _facebookButtonController;
  
  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }
  
  void _setupAnimations() {
    _entranceController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    // Staggered entrance animations
    _headingAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
      ),
    );
    
    _subtitleAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.1, 0.4, curve: Curves.easeOut),
      ),
    );
    
    _emailAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.2, 0.5, curve: Curves.easeOut),
      ),
    );
    
    _passwordAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.3, 0.6, curve: Curves.easeOut),
      ),
    );
    
    _buttonAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.4, 0.7, curve: Curves.easeOut),
      ),
    );
    
    _dividerAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.5, 0.8, curve: Curves.easeOut),
      ),
    );
    
    _socialAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.6, 0.9, curve: Curves.easeOut),
      ),
    );
    
    _linkAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.7, 1.0, curve: Curves.easeOut),
      ),
    );
    
    // Button scale controllers for micro-interactions
    _loginButtonController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    
    _googleButtonController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    
    _facebookButtonController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    
    // Start entrance animation
    _entranceController.forward();
  }

  Future<void> _quickLoginAsRole(String role) async {
    if (role == 'lawyer') {
      try {
        final response = await http.post(
          ApiConfig.uri('/api/lawyers/dev-login'),
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
      // Guest login - new guest user created each time
      try {
        final response = await http.post(
          ApiConfig.uri('/api/users/dev-guest-login'),
          headers: {'Content-Type': 'application/json'},
        );

        final data = response.body.isNotEmpty ? jsonDecode(response.body) : {};

        if (response.statusCode == 200) {
          final accessToken = data['access_token'];
          final user = data['user'];
          final callLimit = data['call_limit'] ?? 5;

          if (accessToken != null) {
            await secureStorage.write(key: 'accessToken', value: accessToken.toString());
          }

          await secureStorage.write(
            key: 'role',
            value: (user?['role'] ?? 'guest').toString(),
          );

          // Store guest session info
          await secureStorage.write(key: 'is_guest', value: 'true');
          await secureStorage.write(key: 'call_limit', value: callLimit.toString());
          await secureStorage.write(key: 'remaining_calls', value: callLimit.toString());
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

    final url = ApiConfig.uri('/api/users/signin');
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
        
        // Mark as non-guest for regular signin
        await secureStorage.write(key: 'is_guest', value: 'false');

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
    _entranceController.dispose();
    _loginButtonController.dispose();
    _googleButtonController.dispose();
    _facebookButtonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.height < 600;
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9F9),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 24,
            vertical: isSmallScreen ? 30 : 60,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Heading - Fade & Slide Up
              FadeAndSlideUp(
                animation: _headingAnimation,
                child: const Text(
                  "Welcome Back!",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF10300C),
                    height: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              
              // Subtitle - Fade & Slide Up
              FadeAndSlideUp(
                animation: _subtitleAnimation,
                child: const Text(
                  "Enter your email to start getting law\nconsultancies at just one click.",
                  style: TextStyle(
                    color: Color(0xFF666666),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 40),
              
              // Email Field - Fade & Slide Up
              FadeAndSlideUp(
                animation: _emailAnimation,
                child: _buildEmailField(),
              ),
              const SizedBox(height: 20),
              
              // Password Field - Fade & Slide Up
              FadeAndSlideUp(
                animation: _passwordAnimation,
                child: _buildPasswordField(),
              ),
              const SizedBox(height: 12),
              
              // Forgot Password Link - Fade & Slide Up
              FadeAndSlideUp(
                animation: _passwordAnimation,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      // TODO: Navigate to forgot password screen
                    },
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      "Forgot your password?",
                      style: TextStyle(
                        color: Color(0xFF10300C),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              
              // Sign In Button - Fade & Slide Up with Scale Animation
              FadeAndSlideUp(
                animation: _buttonAnimation,
                child: ScaleOnTap(
                  controller: _loginButtonController,
                  onTap: loading ? null : signin,
                  child: Container(
                    width: double.infinity,
                    height: 50,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10300C),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF10300C).withOpacity(0.2),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Text(
                              "Log In",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Divider with OR - Fade & Slide Up
              FadeAndSlideUp(
                animation: _dividerAnimation,
                child: Row(
                  children: [
                    const Expanded(
                      child: Divider(
                        color: Color(0xFFDDDDDD),
                        thickness: 1,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        "OR",
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const Expanded(
                      child: Divider(
                        color: Color(0xFFDDDDDD),
                        thickness: 1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              // Google Sign In Button - Fade & Slide Up with Scale Animation
              FadeAndSlideUp(
                animation: _socialAnimation,
                child: ScaleOnTap(
                  controller: _googleButtonController,
                  onTap: () {
                    // TODO: Implement Google Sign In
                  },
                  child: Container(
                    width: double.infinity,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(
                        color: const Color(0xFF10300C),
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          'assets/google.png',
                          height: 20,
                          width: 20,
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          "Log in with Google",
                          style: TextStyle(
                            color: Color(0xFF10300C),
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              
              // Facebook Sign In Button - Fade & Slide Up with Scale Animation
              FadeAndSlideUp(
                animation: _socialAnimation,
                child: ScaleOnTap(
                  controller: _facebookButtonController,
                  onTap: () {
                    // TODO: Implement Facebook Sign In
                  },
                  child: Container(
                    width: double.infinity,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(
                        color: const Color(0xFF10300C),
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.facebook,
                          color: Color(0xFF1877F2),
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          "Log in with Facebook",
                          style: TextStyle(
                            color: Color(0xFF10300C),
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Sign Up Link - Fade & Slide Up
              FadeAndSlideUp(
                animation: _linkAnimation,
                child: Center(
                  child: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const RoleSelectionScreen(),
                        ),
                      );
                    },
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: RichText(
                      text: const TextSpan(
                        text: "Don't have an account? ",
                        style: TextStyle(
                          color: Color(0xFF666666),
                          fontSize: 14,
                        ),
                        children: [
                          TextSpan(
                            text: "Register",
                            style: TextStyle(
                              color: Color(0xFF10300C),
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Test Account Links - Fade & Slide Up
              FadeAndSlideUp(
                animation: _linkAnimation,
                child: Column(
                  children: [
                    Center(
                      child: TextButton(
                        onPressed: () => _quickLoginAsRole("citizen"),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          "Continue as Guest (Limited Access - 5 API calls)",
                          style: TextStyle(
                            color: Color(0xFF999999),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    Center(
                      child: TextButton(
                        onPressed: () => _quickLoginAsRole("lawyer"),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          "Test Lawyer Account",
                          style: TextStyle(
                            color: Color(0xFF999999),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // Email field builder
  Widget _buildEmailField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: emailController,
        keyboardType: TextInputType.emailAddress,
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
              color: Color(0xFFE0E0E0),
              width: 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
              color: Color(0xFF10300C),
              width: 2,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
              color: Color(0xFFE0E0E0),
              width: 1,
            ),
          ),
          prefixIcon: const Icon(
            Icons.mail_outline,
            color: Color(0xFF10300C),
            size: 22,
          ),
          labelText: "Email",
          labelStyle: const TextStyle(
            color: Color(0xFF999999),
            fontSize: 14,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
        style: const TextStyle(
          fontSize: 14,
          color: Color(0xFF333333),
        ),
      ),
    );
  }
  
  // Password field builder
  Widget _buildPasswordField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: passwordController,
        obscureText: hidePassword,
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
              color: Color(0xFFE0E0E0),
              width: 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
              color: Color(0xFF10300C),
              width: 2,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
              color: Color(0xFFE0E0E0),
              width: 1,
            ),
          ),
          prefixIcon: const Icon(
            Icons.lock_outline,
            color: Color(0xFF10300C),
            size: 22,
          ),
          suffixIcon: AnimatedOpacity(
            opacity: hidePassword ? 1.0 : 1.0,
            duration: const Duration(milliseconds: 200),
            child: IconButton(
              icon: Icon(
                hidePassword ? Icons.visibility_off : Icons.visibility,
                color: const Color(0xFF10300C),
                size: 22,
              ),
              onPressed: () {
                setState(() {
                  hidePassword = !hidePassword;
                });
              },
            ),
          ),
          labelText: "Password",
          labelStyle: const TextStyle(
            color: Color(0xFF999999),
            fontSize: 14,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
        style: const TextStyle(
          fontSize: 14,
          color: Color(0xFF333333),
        ),
      ),
    );
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

// Custom widget for button tap scale animation (micro-interaction)
class ScaleOnTap extends StatefulWidget {
  final AnimationController controller;
  final VoidCallback? onTap;
  final Widget child;

  const ScaleOnTap({
    required this.controller,
    required this.onTap,
    required this.child,
    super.key,
  });

  @override
  State<ScaleOnTap> createState() => _ScaleOnTapState();
}

class _ScaleOnTapState extends State<ScaleOnTap> {
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(
        parent: widget.controller,
        curve: Curves.easeInOut,
      ),
    );
  }

  void _onTapDown(TapDownDetails details) {
    widget.controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    widget.controller.reverse();
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onTap != null ? _onTapDown : null,
      onTapUp: widget.onTap != null ? _onTapUp : null,
      onTapCancel: widget.onTap != null
          ? () {
              widget.controller.reverse();
            }
          : null,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}

