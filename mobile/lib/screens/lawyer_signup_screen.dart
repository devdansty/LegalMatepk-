import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'signin_screen.dart';
import '../config/api_config.dart';

class LawyerSignUpScreen extends StatefulWidget {
  const LawyerSignUpScreen({super.key});

  @override
  State<LawyerSignUpScreen> createState() => _LawyerSignUpScreenState();
}

class _LawyerSignUpScreenState extends State<LawyerSignUpScreen>
    with TickerProviderStateMixin {
  // Text Controllers
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final cnicController = TextEditingController();
  final enrollmentController = TextEditingController();
  final barCouncilController = TextEditingController();
  final experienceController = TextEditingController();
  final cityController = TextEditingController();
  final bioController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmController = TextEditingController();

  // File Controllers
  File? cnicFile;
  File? licenseFile;

  // Specialization Multi-select
  Set<String> selectedSpecializations = {};
  final List<String> specializationOptions = [
    "family",
    "criminal",
    "corporate",
    "property",
    "cybercrime",
    "immigration"
  ];

  // Loading state
  bool loading = false;
  bool hidePassword = true;
  bool hideConfirm = true;

  // Animation controller
  late AnimationController _entranceController;
  late AnimationController _submitButtonController;

  // Animations
  late List<Animation<double>> _fieldAnimations;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    _entranceController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _submitButtonController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    // Create staggered animations for form fields
    _fieldAnimations = [];
    for (int i = 0; i < 11; i++) {
      final startTime = i * 0.08;
      final endTime = startTime + 0.3;
      
      _fieldAnimations.add(
        Tween<double>(begin: 0, end: 1).animate(
          CurvedAnimation(
            parent: _entranceController,
            curve: Interval(startTime, endTime, curve: Curves.easeOut),
          ),
        ),
      );
    }

    _entranceController.forward();
  }

  // Pick files
  Future<void> pickFile(bool isCnic) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null) {
      setState(() {
        if (isCnic) {
          cnicFile = File(result.files.single.path!);
        } else {
          licenseFile = File(result.files.single.path!);
        }
      });
    }
  }

  // Validate CNIC format
  bool isValidCNIC(String cnic) {
    final cnicRegex = RegExp(r'^\d{5}-\d{7}-\d{1}$');
    return cnicRegex.hasMatch(cnic);
  }

  // Validate inputs
  String? validateInputs() {
    if (nameController.text.isEmpty) return "Full name is required";
    if (emailController.text.isEmpty) return "Email is required";
    if (!emailController.text.contains("@")) return "Invalid email";
    if (phoneController.text.isEmpty) return "Phone number is required";
    if (cnicController.text.isEmpty) return "CNIC is required";
    if (!isValidCNIC(cnicController.text)) {
      return "CNIC format should be: XXXXX-XXXXXXX-X";
    }
    if (enrollmentController.text.isEmpty) return "Enrollment number is required";
    if (barCouncilController.text.isEmpty) return "Bar council name is required";
    if (selectedSpecializations.isEmpty) return "Select at least one specialization";
    if (cityController.text.isEmpty) return "City is required";
    if (experienceController.text.isEmpty) return "Experience years is required";
    if (int.tryParse(experienceController.text) == null) {
      return "Experience years must be a number";
    }
    if (bioController.text.isEmpty) return "Bio/description is required";
    if (bioController.text.length < 20) return "Bio must be at least 20 characters";
    if (passwordController.text.isEmpty) return "Password is required";
    if (passwordController.text.length < 6) return "Password must be at least 6 characters";
    if (passwordController.text != confirmController.text) {
      return "Passwords do not match";
    }
    if (cnicFile == null) return "CNIC file is required";
    if (licenseFile == null) return "License file is required";
    return null;
  }

  // Signup function
  Future<void> signupLawyer() async {
    final validation = validateInputs();
    if (validation != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(validation)));
      return;
    }

    setState(() => loading = true);

    try {
      final url = ApiConfig.uri('/api/lawyers/signup');
      var request = http.MultipartRequest("POST", url);

      // Add text fields
      request.fields['name'] = nameController.text.trim();
      request.fields['email'] = emailController.text.trim();
      request.fields['phone'] = phoneController.text.trim();
      request.fields['cnic'] = cnicController.text.trim();
      request.fields['enrollment_number'] = enrollmentController.text.trim();
      request.fields['bar_council'] = barCouncilController.text.trim();
      request.fields['city'] = cityController.text.trim();
      request.fields['experience_years'] = experienceController.text.trim();
      request.fields['bio'] = bioController.text.trim();
      request.fields['password'] = passwordController.text;
      
      // Add specializations as comma-separated string
      request.fields['specialization'] = selectedSpecializations.join(',');

      // Add files
      request.files.add(
        await http.MultipartFile.fromPath('cnic_file', cnicFile!.path),
      );
      request.files.add(
        await http.MultipartFile.fromPath('license_file', licenseFile!.path),
      );

      final response = await request.send();

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (!mounted) return;

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text("Application Submitted 👨‍⚖️"),
            content: const Text(
              "Your lawyer profile has been submitted for review. You will be notified once it is approved by the admin. Please check your email for updates.",
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const SignInScreen()),
                  );
                },
                child: const Text("Go to Login"),
              ),
            ],
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Signup failed: ${response.statusCode}",
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: ${e.toString()}")));
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    cnicController.dispose();
    enrollmentController.dispose();
    barCouncilController.dispose();
    experienceController.dispose();
    cityController.dispose();
    bioController.dispose();
    passwordController.dispose();
    confirmController.dispose();
    _entranceController.dispose();
    _submitButtonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF10300C),
        elevation: 1,
        toolbarHeight: 70,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Lawyer Registration',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FadeAndSlideUp(
              animation: _fieldAnimations[0],
              child: const Text(
                "Professional Registration Form",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF10300C),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // --- PERSONAL DETAILS SECTION ---
            FadeAndSlideUp(
              animation: _fieldAnimations[0],
              child: const Text(
                "Personal Details",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 10),

            FadeAndSlideUp(
              animation: _fieldAnimations[1],
              child: _buildInputField(
                label: "Full Name (as per license)",
                controller: nameController,
              ),
            ),

            FadeAndSlideUp(
              animation: _fieldAnimations[2],
              child: _buildInputField(
                label: "Email",
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
              ),
            ),

            FadeAndSlideUp(
              animation: _fieldAnimations[3],
              child: _buildInputField(
                label: "Phone",
                controller: phoneController,
                keyboardType: TextInputType.phone,
              ),
            ),

            const SizedBox(height: 20),

            // --- LEGAL DOCUMENTS SECTION ---
            FadeAndSlideUp(
              animation: _fieldAnimations[4],
              child: const Text(
                "Legal Documents",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 10),

            FadeAndSlideUp(
              animation: _fieldAnimations[5],
              child: _buildInputField(
                label: "CNIC (Format: XXXXX-XXXXXXX-X)",
                controller: cnicController,
              ),
            ),

            FadeAndSlideUp(
              animation: _fieldAnimations[6],
              child: _buildInputField(
                label: "Enrollment Number",
                controller: enrollmentController,
              ),
            ),

            FadeAndSlideUp(
              animation: _fieldAnimations[7],
              child: _buildInputField(
                label: "Bar Council Name",
                controller: barCouncilController,
              ),
            ),

            const SizedBox(height: 15),

            FadeAndSlideUp(
              animation: _fieldAnimations[5],
              child: ScaleOnTap(
                controller: _submitButtonController,
                onTap: () => pickFile(true),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFF10300C), width: 1.5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.upload_file, color: Color(0xFF10300C)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          cnicFile == null
                              ? "Upload CNIC Image"
                              : "CNIC: ${cnicFile!.path.split('/').last}",
                          style: const TextStyle(
                            color: Color(0xFF10300C),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            FadeAndSlideUp(
              animation: _fieldAnimations[6],
              child: ScaleOnTap(
                controller: _submitButtonController,
                onTap: () => pickFile(false),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFF10300C), width: 1.5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.upload_file, color: Color(0xFF10300C)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          licenseFile == null
                              ? "Upload License Image"
                              : "License: ${licenseFile!.path.split('/').last}",
                          style: const TextStyle(
                            color: Color(0xFF10300C),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // --- PROFESSIONAL DETAILS SECTION ---
            FadeAndSlideUp(
              animation: _fieldAnimations[7],
              child: const Text(
                "Professional Details",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 10),

            // Specialization Multi-select
            FadeAndSlideUp(
              animation: _fieldAnimations[8],
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Select Specializations",
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: specializationOptions.map((spec) {
                        final isSelected = selectedSpecializations.contains(spec);
                        return FilterChip(
                          label: Text(spec.toUpperCase()),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                selectedSpecializations.add(spec);
                              } else {
                                selectedSpecializations.remove(spec);
                              }
                            });
                          },
                          backgroundColor: Colors.white,
                          selectedColor: const Color(0xFF10300C).withOpacity(0.2),
                          labelStyle: TextStyle(
                            color: isSelected
                                ? const Color(0xFF10300C)
                                : const Color(0xFF666666),
                            fontWeight: FontWeight.w600,
                          ),
                          side: BorderSide(
                            color: isSelected
                                ? const Color(0xFF10300C)
                                : const Color(0xFFE0E0E0),
                            width: 1.5,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 15),

            FadeAndSlideUp(
              animation: _fieldAnimations[9],
              child: _buildInputField(
                label: "City",
                controller: cityController,
              ),
            ),

            FadeAndSlideUp(
              animation: _fieldAnimations[9],
              child: _buildInputField(
                label: "Years of Experience",
                controller: experienceController,
                keyboardType: TextInputType.number,
              ),
            ),

            FadeAndSlideUp(
              animation: _fieldAnimations[10],
              child: _buildInputField(
                label: "Professional Bio/Summary",
                controller: bioController,
                maxLines: 4,
              ),
            ),

            const SizedBox(height: 20),

            // --- SECURITY SECTION ---
            FadeAndSlideUp(
              animation: _fieldAnimations[10],
              child: const Text(
                "Account Security",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 10),

            FadeAndSlideUp(
              animation: _fieldAnimations[10],
              child: _buildPasswordField(
                label: "Password",
                controller: passwordController,
                hidePassword: hidePassword,
                onToggle: () => setState(() => hidePassword = !hidePassword),
              ),
            ),

            FadeAndSlideUp(
              animation: _fieldAnimations[10],
              child: _buildPasswordField(
                label: "Confirm Password",
                controller: confirmController,
                hidePassword: hideConfirm,
                onToggle: () => setState(() => hideConfirm = !hideConfirm),
              ),
            ),

            const SizedBox(height: 30),

            // Submit Button
            FadeAndSlideUp(
              animation: _fieldAnimations[10],
              child: ScaleOnTap(
                controller: _submitButtonController,
                onTap: loading ? null : signupLawyer,
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
                            "Submit Lawyer Application",
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

            const SizedBox(height: 20),

            // Already registered link
            FadeAndSlideUp(
              animation: _fieldAnimations[10],
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "Already have an account? ",
                      style: TextStyle(
                        color: Color(0xFF666666),
                        fontSize: 14,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SignInScreen(),
                          ),
                        );
                      },
                      child: const Text(
                        "Sign In",
                        style: TextStyle(
                          color: Color(0xFF10300C),
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    bool obscure = false,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
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
          obscureText: obscure,
          maxLines: maxLines,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            labelText: label,
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
            labelStyle: const TextStyle(
              color: Color(0xFF999999),
              fontWeight: FontWeight.w500,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
          style: const TextStyle(
            color: Color(0xFF333333),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required String label,
    required TextEditingController controller,
    required bool hidePassword,
    required VoidCallback onToggle,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
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
            labelText: label,
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
            suffixIcon: IconButton(
              icon: Icon(
                hidePassword ? Icons.visibility_off : Icons.visibility,
                color: const Color(0xFF10300C),
                size: 22,
              ),
              onPressed: onToggle,
            ),
            labelStyle: const TextStyle(
              color: Color(0xFF999999),
              fontWeight: FontWeight.w500,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
          style: const TextStyle(
            color: Color(0xFF333333),
            fontWeight: FontWeight.w500,
          ),
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
