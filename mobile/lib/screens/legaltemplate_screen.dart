import 'package:flutter/material.dart';

class DocumentAutomationScreen extends StatelessWidget {
  const DocumentAutomationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Document Generator"),
        backgroundColor: const Color(0xFF004B23),
      ),
      body: const Center(
        child: Text("Template Selection Screen"),
      ),
    );
  }
}