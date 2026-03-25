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

class _LawyerSignUpScreenState extends State<LawyerSignUpScreen> {
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

  // Validate CNIC format: XXXXX-XXXXXXX-X
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
      return "CNIC format should be: XXXXX-XXXXXXX-X (e.g., 12345-6789012-3)";
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
      final resBody = await response.stream.bytesToString();

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (!mounted) return;

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text("Application Submitted ðŸ‘¨â€âš–ï¸"),
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

  // Standard text field widget
  Widget field(
    String label,
    TextEditingController controller, {
    bool obscure = false,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Lawyer Registration")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
              "Professional Registration Form",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // --- PERSONAL DETAILS SECTION ---
            const Text(
              "Personal Details",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            field("Full Name (as per license)", nameController),
            field("Email", emailController),
            field("Phone", phoneController),

            const SizedBox(height: 20),

            // --- LEGAL DOCUMENTS SECTION ---
            const Text(
              "Legal Documents",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            field("CNIC (Format: XXXXX-XXXXXXX-X)", cnicController),
            field("Enrollment Number", enrollmentController),
            field("Bar Council Name", barCouncilController),

            const SizedBox(height: 15),

            ElevatedButton.icon(
              onPressed: () => pickFile(true),
              icon: const Icon(Icons.upload_file),
              label: Text(
                cnicFile == null ? "Upload CNIC Image" : "CNIC: ${cnicFile!.path.split('/').last}",
              ),
            ),
            const SizedBox(height: 10),

            ElevatedButton.icon(
              onPressed: () => pickFile(false),
              icon: const Icon(Icons.upload_file),
              label: Text(
                licenseFile == null
                    ? "Upload License Image"
                    : "License: ${licenseFile!.path.split('/').last}",
              ),
            ),

            const SizedBox(height: 20),

            // --- PROFESSIONAL DETAILS SECTION ---
            const Text(
              "Professional Details",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            // Specialization Multi-select
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Specialization (Select one or more)",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      children: specializationOptions.map((spec) {
                        final isSelected = selectedSpecializations.contains(spec);
                        return FilterChip(
                          label: Text(spec),
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
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 15),

            field("City", cityController),
            field("Years of Experience", experienceController),
            field(
              "Professional Bio/Summary",
              bioController,
              maxLines: 4,
            ),

            const SizedBox(height: 20),

            // --- SECURITY SECTION ---
            const Text(
              "Account Security",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            field("Password", passwordController, obscure: true),
            field("Confirm Password", confirmController, obscure: true),

            const SizedBox(height: 30),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: loading ? null : signupLawyer,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                child: loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        "Submit Lawyer Application",
                        style: TextStyle(fontSize: 16),
                      ),
              ),
            ),

            const SizedBox(height: 20),

            // Already registered?
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("Already have an account? "),
                GestureDetector(
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const SignInScreen()),
                    );
                  },
                  child: const Text(
                    "Sign In",
                    style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
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
    super.dispose();
  }
}
