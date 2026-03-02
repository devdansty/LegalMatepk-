import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'signin_screen.dart';

class LawyerSignUpScreen extends StatefulWidget {
  const LawyerSignUpScreen({super.key});

  @override
  State<LawyerSignUpScreen> createState() => _LawyerSignUpScreenState();
}

class _LawyerSignUpScreenState extends State<LawyerSignUpScreen> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final cnicController = TextEditingController();
  final enrollmentController = TextEditingController();
  final barCouncilController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmController = TextEditingController();

  File? cnicFile;
  File? licenseFile;

  bool loading = false;

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

  Future<void> signupLawyer() async {
    if (passwordController.text != confirmController.text) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Passwords do not match")));
      return;
    }

    if (cnicFile == null || licenseFile == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Upload required documents")));
      return;
    }

    setState(() => loading = true);

    final url = Uri.parse('http://192.168.100.147:3000/api/lawyers/register');

    try {
      var request = http.MultipartRequest("POST", url);

      // TEXT FIELDS
      request.fields['name'] = nameController.text.trim();
      request.fields['email'] = emailController.text.trim();
      request.fields['phone'] = phoneController.text.trim();
      request.fields['cnic'] = cnicController.text.trim();
      request.fields['enrollment_number'] = enrollmentController.text.trim();
      request.fields['bar_council'] = barCouncilController.text.trim();
      request.fields['password'] = passwordController.text;
      request.fields['role'] = 'lawyer';

      // FILES
      request.files.add(await http.MultipartFile.fromPath('cnic_file', cnicFile!.path));
      request.files.add(await http.MultipartFile.fromPath('license_file', licenseFile!.path));

      final response = await request.send();
      final resBody = await response.stream.bytesToString();

      if (response.statusCode == 200 || response.statusCode == 201) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text("Application Submitted 👨‍⚖️"),
            content: const Text(
              "Your lawyer profile is under review. You will be notified once approved.",
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Signup failed")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Server error")));
    } finally {
      setState(() => loading = false);
    }
  }

  Widget field(String label, TextEditingController controller,
      {bool obscure = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        decoration: InputDecoration(labelText: label),
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
            field("Full Name (as per license)", nameController),
            field("Email", emailController),
            field("Phone", phoneController),
            field("CNIC", cnicController),
            field("Enrollment Number", enrollmentController),
            field("Bar Council Name", barCouncilController),
            field("Password", passwordController, obscure: true),
            field("Confirm Password", confirmController, obscure: true),

            const SizedBox(height: 10),

            ElevatedButton(
              onPressed: () => pickFile(true),
              child: Text(cnicFile == null ? "Upload CNIC" : "CNIC Selected ✅"),
            ),

            ElevatedButton(
              onPressed: () => pickFile(false),
              child: Text(licenseFile == null
                  ? "Upload License Card"
                  : "License Selected ✅"),
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: loading ? null : signupLawyer,
              child: loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("Submit Lawyer Application"),
            ),
          ],
        ),
      ),
    );
  }
}