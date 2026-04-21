import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'signin_screen.dart';
import 'home_screen.dart';
import '../config/api_config.dart';

class CitizenSignUpScreen extends StatefulWidget {
  const CitizenSignUpScreen({super.key});

  @override
  State<CitizenSignUpScreen> createState() => _CitizenSignUpScreenState();
}

class _CitizenSignUpScreenState extends State<CitizenSignUpScreen>
    with TickerProviderStateMixin {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmController = TextEditingController();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  bool loading = false;
  bool hidePassword = true;
  bool hideConfirm = true;

  // Animation controllers
  late AnimationController _entranceController;
  late Animation<double> _headingAnimation;
  late Animation<double> _subtitleAnimation;
  late Animation<double> _firstNameAnimation;
  late Animation<double> _lastNameAnimation;
  late Animation<double> _emailAnimation;
  late Animation<double> _passwordAnimation;
  late Animation<double> _confirmAnimation;
  late Animation<double> _termsAnimation;
  late Animation<double> _buttonAnimation;
  late Animation<double> _dividerAnimation;
  late Animation<double> _socialAnimation;
  late Animation<double> _loginLinkAnimation;

  // Button scale animations
  late AnimationController _signupButtonController;
  late AnimationController _googleButtonController;
  late AnimationController _facebookButtonController;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    _entranceController = AnimationController(
      duration: const Duration(milliseconds: 1300),
      vsync: this,
    );

    _headingAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.25, curve: Curves.easeOut),
      ),
    );

    _subtitleAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.08, 0.33, curve: Curves.easeOut),
      ),
    );

    _firstNameAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.15, 0.42, curve: Curves.easeOut),
      ),
    );

    _lastNameAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.22, 0.5, curve: Curves.easeOut),
      ),
    );

    _emailAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.29, 0.57, curve: Curves.easeOut),
      ),
    );

    _passwordAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.36, 0.64, curve: Curves.easeOut),
      ),
    );

    _confirmAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.43, 0.71, curve: Curves.easeOut),
      ),
    );

    _termsAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.5, 0.78, curve: Curves.easeOut),
      ),
    );

    _buttonAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.57, 0.85, curve: Curves.easeOut),
      ),
    );

    _dividerAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.64, 0.92, curve: Curves.easeOut),
      ),
    );

    _socialAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.71, 1.0, curve: Curves.easeOut),
      ),
    );

    _loginLinkAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.78, 1.0, curve: Curves.easeOut),
      ),
    );

    // Button scale controllers
    _signupButtonController = AnimationController(
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

    _entranceController.forward();
  }

  Future<void> signup() async {
    // Validate all fields
    if (nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("First name is required")),
      );
      return;
    }

    if (emailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Email is required")),
      );
      return;
    }

    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(emailController.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid email")),
      );
      return;
    }

    // Validate password length
    if (passwordController.text.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Password must be at least 8 characters")),
      );
      return;
    }

    if (passwordController.text != confirmController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Passwords do not match")),
      );
      return;
    }

    setState(() => loading = true);

    final url = ApiConfig.uri('/api/users/signup');

    final body = jsonEncode({
      "display_name": (nameController.text.trim() + " " + lastNameController.text.trim()).trim(),
      "email": emailController.text.trim(),
      "phone": phoneController.text.trim(),
      "password": passwordController.text,
      "preferred_language": "ur",
      "role": "citizen"
    });

    try {
      final res = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: body,
      );

      final data = res.body.isNotEmpty ? jsonDecode(res.body) : {};

      if (res.statusCode == 201) {
        // Store auth data
        final accessToken = data['access_token'];
        final user = data['user'];

        if (accessToken != null) {
          await _secureStorage.write(key: 'accessToken', value: accessToken.toString());
        }

        if (user != null) {
          await _secureStorage.write(
            key: 'role',
            value: (user['role'] ?? 'citizen').toString(),
          );
        }

        // Mark as non-guest
        await _secureStorage.write(key: 'is_guest', value: 'false');

        if (!mounted) return;

        // Navigate directly to home
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const LegalMateHome(),
          ),
        );
      } else {
        final errMsg = data['error'] ?? data['message'] ?? 'Signup failed - please try again';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errMsg)));
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: ${e.toString()}")));
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    lastNameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    confirmController.dispose();
    _entranceController.dispose();
    _signupButtonController.dispose();
    _googleButtonController.dispose();
    _facebookButtonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.height < 700;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9F9),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 24,
            vertical: isSmallScreen ? 30 : 50,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Heading
              FadeAndSlideUp(
                animation: _headingAnimation,
                child: const Text(
                  "Create Account",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1B1A1A),
                    height: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Subtitle
              FadeAndSlideUp(
                animation: _subtitleAnimation,
                child: const Text(
                  "Fill in your details below to start getting law\nconsultancies at just one click.",
                  style: TextStyle(
                    color: Color(0xFF666666),
                    fontSize: 14,
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 40),

              // First Name Field
              FadeAndSlideUp(
                animation: _firstNameAnimation,
                child: _buildInputField(
                  controller: nameController,
                  label: "First Name",
                  icon: Icons.person_outline,
                  hint: "Sameer",
                ),
              ),
              const SizedBox(height: 16),

              // Last Name Field
              FadeAndSlideUp(
                animation: _lastNameAnimation,
                child: _buildInputField(
                  controller: lastNameController,
                  label: "Last Name",
                  icon: Icons.person_outline,
                  hint: "Abid",
                ),
              ),
              const SizedBox(height: 16),

              // Email Field
              FadeAndSlideUp(
                animation: _emailAnimation,
                child: _buildInputField(
                  controller: emailController,
                  label: "Email",
                  icon: Icons.mail_outline,
                  hint: "sameer.abid@gmail.com",
                  keyboardType: TextInputType.emailAddress,
                ),
              ),
              const SizedBox(height: 16),

              // Password Field
              FadeAndSlideUp(
                animation: _passwordAnimation,
                child: _buildPasswordField(
                  controller: passwordController,
                  label: "Password",
                  hidePassword: hidePassword,
                  onToggle: () {
                    setState(() => hidePassword = !hidePassword);
                  },
                ),
              ),
              const SizedBox(height: 16),

              // Confirm Password Field
              FadeAndSlideUp(
                animation: _confirmAnimation,
                child: _buildPasswordField(
                  controller: confirmController,
                  label: "Confirm Password",
                  hidePassword: hideConfirm,
                  onToggle: () {
                    setState(() => hideConfirm = !hideConfirm);
                  },
                ),
              ),
              const SizedBox(height: 20),

              // Terms and conditions
              FadeAndSlideUp(
                animation: _termsAnimation,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Color(0xFF10300C).withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Color(0xFF10300C).withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: RichText(
                    text: TextSpan(
                      text: "By clicking Create Account, you acknowledge you\nhave read and agreed to our ",
                      style: const TextStyle(
                        color: Color(0xFF666666),
                        fontSize: 12,
                        height: 1.4,
                      ),
                      children: [
                        TextSpan(
                          text: "Terms of Use",
                          style: const TextStyle(
                            color: Color(0xFF10300C),
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                          ),
                          recognizer: null,
                        ),
                        const TextSpan(
                          text: " and ",
                          style: TextStyle(
                            color: Color(0xFF666666),
                          ),
                        ),
                        TextSpan(
                          text: "Privacy Policy",
                          style: const TextStyle(
                            color: Color(0xFF10300C),
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                          ),
                          recognizer: null,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // Create Account Button
              FadeAndSlideUp(
                animation: _buttonAnimation,
                child: ScaleOnTap(
                  controller: _signupButtonController,
                  onTap: loading ? null : signup,
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
                              "Create Account",
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

              // Divider with OR
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
                          fontWeight: FontWeight.w600,
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

              // Google Button
              FadeAndSlideUp(
                animation: _socialAnimation,
                child: ScaleOnTap(
                  controller: _googleButtonController,
                  onTap: () {},
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
                          "Continue with Google",
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

              // Facebook Button
              FadeAndSlideUp(
                animation: _socialAnimation,
                child: ScaleOnTap(
                  controller: _facebookButtonController,
                  onTap: () {},
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
                          "Continue with Facebook",
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

              // Login Link
              FadeAndSlideUp(
                animation: _loginLinkAnimation,
                child: Center(
                  child: TextButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SignInScreen(),
                        ),
                      );
                    },
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: RichText(
                      text: const TextSpan(
                        text: "Already have an account? ",
                        style: TextStyle(
                          color: Color(0xFF666666),
                          fontSize: 14,
                        ),
                        children: [
                          TextSpan(
                            text: "Login",
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
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
  }) {
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
        controller: controller,
        keyboardType: keyboardType,
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
          prefixIcon: Icon(
            icon,
            color: const Color(0xFF10300C),
            size: 22,
          ),
          labelText: label,
          hintText: hint,
          labelStyle: const TextStyle(
            color: Color(0xFF999999),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          hintStyle: const TextStyle(
            color: Color(0xFFBBBBBB),
            fontSize: 13,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
        style: const TextStyle(
          fontSize: 14,
          color: Color(0xFF333333),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool hidePassword,
    required VoidCallback onToggle,
  }) {
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
        controller: controller,
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
          suffixIcon: IconButton(
            icon: Icon(
              hidePassword ? Icons.visibility_off : Icons.visibility,
              color: const Color(0xFF10300C),
              size: 22,
            ),
            onPressed: onToggle,
          ),
          labelText: label,
          labelStyle: const TextStyle(
            color: Color(0xFF999999),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
        style: const TextStyle(
          fontSize: 14,
          color: Color(0xFF333333),
          fontWeight: FontWeight.w500,
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

// Custom widget for button tap scale animation
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
