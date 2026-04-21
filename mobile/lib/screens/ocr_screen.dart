import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'dart:io';
import '../config/api_config.dart';

class OcrScreen extends StatefulWidget {
  const OcrScreen({super.key});

  @override
  State<OcrScreen> createState() => _OcrScreenState();
}

class _OcrScreenState extends State<OcrScreen>
    with TickerProviderStateMixin {
  // Animation controllers
  late AnimationController _entranceController;
  late Animation<double> _contentAnimation;

  static const bool _allowGuestTesting = true;
  File? _selectedFile;
  String? _selectedFileName;
  final TextEditingController _queryController = TextEditingController();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  
  bool _isProcessing = false;
  String? _summaryResult;
  String? _errorMessage;

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

    _contentAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );

    _entranceController.forward();
  }

  // Pick file (images, PDFs, DOCs)
  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'doc', 'docx'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedFile = File(result.files.single.path!);
          _selectedFileName = result.files.single.name;
          _summaryResult = null; // Clear previous result
          _errorMessage = null;
        });
      }
    } catch (e) {
      _showError("Failed to pick file: $e");
    }
  }

  // Process document - Call backend API
  Future<void> _processDocument() async {
    if (_selectedFile == null) {
      _showError("Please select a document first");
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
      _summaryResult = null;
    });

    try {
      // Get authentication token and guest status
      final accessToken = await _secureStorage.read(key: 'accessToken');
      final isGuest = await _secureStorage.read(key: 'is_guest');
      
      // Check if user is guest (allow if _allowGuestTesting is true)
      if (isGuest == 'true' && !_allowGuestTesting) {
        _showError("This feature is not available for guest users. Please sign up to use Document Analyzer.");
        setState(() => _isProcessing = false);
        return;
      }

      // Check if user is authenticated
      if (accessToken == null || accessToken.isEmpty) {
        _showError("Authentication token not found. Please login again.");
        setState(() => _isProcessing = false);
        return;
      }

      // Prepare request
      final url = ApiConfig.uri('/api/ocr');
      var request = http.MultipartRequest('POST', url);
      
      // Add authentication header
      request.headers['Authorization'] = 'Bearer $accessToken';

      // Add file
      request.files.add(
        await http.MultipartFile.fromPath('document', _selectedFile!.path),
      );

      // Add query (combine default + user input)
      String finalQuery =
        "Please summarize and clearly explain the key points and important information from the attached document in a concise and professional manner.";
      if (_queryController.text.trim().isNotEmpty) {
        finalQuery += " ${_queryController.text.trim()}";
      }
      request.fields['query'] = finalQuery;

      // Send request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        
        if (data['success'] == true && data['data'] != null) {
          setState(() {
            _summaryResult = data['data']['summary'] ?? "No summary available";
            _isProcessing = false;
          });
          // Trigger animation for summary result
          _entranceController.reset();
          _entranceController.forward();
        } else {
          setState(() {
            _errorMessage = data['error'] ?? "Failed to process document";
            _isProcessing = false;
          });
        }
      } else if (response.statusCode == 403) {
        final data = json.decode(response.body);
        _showError(data['error'] ?? "Access denied: This feature requires a full account");
        setState(() => _isProcessing = false);
      } else {
        final data = json.decode(response.body);
        setState(() {
          _errorMessage = data['error'] ?? "Server error: ${response.statusCode}";
          _isProcessing = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Network error: $e";
        _isProcessing = false;
      });
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color darkGreen = Color(0xFF004B23);
    const Color offWhite = Color(0xFFF8F9F9);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF10300C),
        elevation: 1,
        toolbarHeight: 70,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Scan Document',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // File Upload Area
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey[400]!, width: 2),
              ),
              child: _selectedFile == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.upload_file_outlined, size: 60, color: Colors.grey[500]),
                        const SizedBox(height: 10),
                        const Text(
                          "No document selected",
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          "Supported: JPG, PNG, PDF, DOC, DOCX",
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _getFileIcon(_selectedFileName ?? ""),
                          size: 60,
                          color: darkGreen,
                        ),
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            _selectedFileName ?? "Document",
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _selectedFile = null;
                              _selectedFileName = null;
                              _summaryResult = null;
                              _errorMessage = null;
                            });
                          },
                          icon: const Icon(Icons.close, size: 16),
                          label: const Text("Remove"),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 20),

            // Upload Button
            SizedBox(
              width: double.infinity,
              height: 55,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: darkGreen, width: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _isProcessing ? null : _pickFile,
                icon: const Icon(Icons.attach_file, color: darkGreen),
                label: const Text(
                  "Choose Document",
                  style: TextStyle(color: darkGreen, fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 25),

            // Query Input Section
            const Text(
              "Additional Instructions (Optional)",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _queryController,
              enabled: !_isProcessing,
              maxLines: 3,
              decoration: InputDecoration(
                hintText:
                  "Please summarize and clearly explain the key points and important information from the attached document.",
                hintStyle: TextStyle(color: Colors.grey[500]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[400]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[400]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: darkGreen, width: 2),
                ),
                contentPadding: const EdgeInsets.all(15),
              ),
            ),
            const SizedBox(height: 25),

            // Process Button
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: darkGreen,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: (_selectedFile == null || _isProcessing)
                    ? null
                    : _processDocument,
                child: _isProcessing
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          SizedBox(width: 15),
                          Text(
                            "Processing document...",
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ],
                      )
                    : const Text(
                        "Process Document",
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
              ),
            ),
            const SizedBox(height: 30),

            // Error Message Display
            if (_errorMessage != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red[300]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red[700]),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red[900]),
                      ),
                    ),
                  ],
                ),
              ),

            // Summary Result Display
            if (_summaryResult != null) ...[
              AnimatedBuilder(
                animation: _contentAnimation,
                builder: (context, child) {
                  return Opacity(
                    opacity: _contentAnimation.value,
                    child: Transform.translate(
                      offset: Offset(0, 20 * (1 - _contentAnimation.value)),
                      child: child,
                    ),
                  );
                },
                child: Column(
                  children: [
                    const Divider(height: 40, thickness: 1),
                    const Text(
                      "Summary Result",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: darkGreen,
                      ),
                    ),
                    const SizedBox(height: 15),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: offWhite,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: SelectableText(
                        _summaryResult!,
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.6,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Helper to get appropriate icon based on file extension
  IconData _getFileIcon(String filename) {
    final ext = filename.toLowerCase().split('.').last;
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'jpg':
      case 'jpeg':
      case 'png':
        return Icons.image;
      default:
        return Icons.insert_drive_file;
    }
  }
}
