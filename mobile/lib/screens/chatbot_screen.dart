// dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/STT.dart';
import '../config/api_config.dart';

class ChatBotPage extends StatefulWidget {
  final String? initialQuery;

  const ChatBotPage({super.key, this.initialQuery});

  @override
  State<ChatBotPage> createState() => _ChatBotPageState();
}

class _ChatBotPageState extends State<ChatBotPage>
    with TickerProviderStateMixin {

  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _messages = [];
  final ScrollController _scrollController = ScrollController();
  final FlutterSecureStorage secureStorage = const FlutterSecureStorage();

  final STTService _sttService = STTService();
  final FlutterTts _flutterTts = FlutterTts();

  // Animation controllers
  late AnimationController _entranceController;
  late Animation<double> _iconAnimation;
  late Animation<double> _headingAnimation;
  late Animation<double> _subtitleAnimation;
  late List<Animation<double>> _cardAnimations;

  bool _isListening = false;
  bool _isLoading = false;
  String _errorMessage = '';

  Timer? _silenceTimer;
  Timer? _errorTimer;
  bool _isRestarting = false;
  final Duration _silenceDuration = const Duration(seconds: 4);

  String _lastRecognizedText = '';
  String _sessionPrefix = '';
  String _currentLanguage = "en_US";

  String _voiceMode = "auto";

  // OCR Image attachment
  File? _attachedImage;
  final ImagePicker _imagePicker = ImagePicker();
  bool _isExtractingOcr = false;
  String? _extractedOcrText;

  // Color scheme
  static const Color primaryGreen = Color(0xFF10300C);
  static const Color offWhite = Color(0xFFF8F9F9);
  static const Color textDark = Color(0xFF333333);
  static const Color textMedium = Color(0xFF666666);
  static const Color textLight = Color(0xFF999999);
  static const Color borderColor = Color(0xFFE0E0E0);

  // ================= INIT =================
  @override
  void initState() {
    super.initState();
    _initTts();
    _setupAnimations();
    
    // Set initial query if provided
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _controller.text = widget.initialQuery!;
    }
  }

  void _setupAnimations() {
    _entranceController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _iconAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.2, curve: Curves.easeOut),
      ),
    );

    _headingAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.1, 0.35, curve: Curves.easeOut),
      ),
    );

    _subtitleAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.2, 0.45, curve: Curves.easeOut),
      ),
    );

    // 4 common issue cards
    _cardAnimations = List.generate(
      4,
      (index) => Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
          parent: _entranceController,
          curve: Interval(
            0.3 + (index * 0.1),
            0.6 + (index * 0.1),
            curve: Curves.easeOut,
          ),
        ),
      ),
    );

    _entranceController.forward();
  }

  Future<void> _initTts() async {
    try {
      await _flutterTts.setLanguage("en-US");
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setPitch(1.0);
      await _flutterTts.setVolume(1.0);
      debugPrint("TTS Initialized successfully");
    } catch (e) {
      debugPrint("TTS Init Error: $e");
    }
  }

  // ================= ERROR =================
  void _showError(String msg, {Duration duration = const Duration(seconds: 4)}) {
    _errorTimer?.cancel();
    setState(() => _errorMessage = msg);
    _errorTimer = Timer(duration, () {
      if (mounted) setState(() => _errorMessage = '');
    });
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 200), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String message) async {
    if (message.trim().isEmpty) return;

    // ================= OCR EXTRACTION (if image attached) =================
    String finalMessage = message;
    if (_attachedImage != null && _extractedOcrText == null) {
      // Extract text from image first
      await _extractTextFromImage(_attachedImage!);
      
      if (_extractedOcrText != null) {
        // Combine OCR text with user message
        finalMessage = "Document content:\n$_extractedOcrText\n\nUser question: $message";
        _clearAttachment();
      } else {
        // Extraction failed - error already shown
        return;
      }
    } else if (_attachedImage != null && _extractedOcrText != null) {
      // Use previously extracted text
      finalMessage = "Document content:\n$_extractedOcrText\n\nUser question: $message";
      _clearAttachment();
    }

    setState(() {
      _messages.add({"role": "user", "text": message});
      _isLoading = true;
      _errorMessage = '';
    });

    _controller.clear();
    _scrollToBottom();

    // ================= REAL API CALL =================
    try {
      // Get auth token if available
      var _accessToken = await secureStorage.read(key: 'accessToken');
      var _isGuest = await secureStorage.read(key: 'is_guest');
      
      // Check guest call limit before sending
      if (_isGuest == 'true') {
        var remainingCalls = await secureStorage.read(key: 'remaining_calls');
        int remaining = int.tryParse(remainingCalls ?? '0') ?? 0;
        
        if (remaining <= 0) {
          setState(() => _isLoading = false);
          _showError("Guest session limit reached. Please sign up for unlimited access.");
          return;
        }
      }

      final headers = {
        'Content-Type': 'application/json',
        if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
      };

      final response = await http.post(
        ApiConfig.uri('/api/chatbot'),
        headers: headers,
        body: jsonEncode({"message": finalMessage, "session_id": "session-1"}),
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final botReply = (data['reply'] ?? data['message'] ?? '').toString();

        // Update guest call info if available
        if (_isGuest == 'true' && data['guest_session'] != null) {
          final guestInfo = data['guest_session'];
          final remainingCalls = guestInfo['remaining_calls'] ?? 0;
          await secureStorage.write(key: 'remaining_calls', value: remainingCalls.toString());
          
          // Show warning if running out of calls
          if (remainingCalls == 1) {
            _showError("Warning: Only 1 API call remaining. Please sign up to continue.", 
              duration: const Duration(seconds: 6));
          } else if (remainingCalls == 0) {
            _showError("Guest session limit reached. Please sign up for unlimited access.", 
              duration: const Duration(seconds: 6));
          }
        }

        setState(() {
          _messages.add({"role": "bot", "text": botReply});
          _isLoading = false;
        });

        _scrollToBottom();
      } else if (response.statusCode == 403) {
        setState(() => _isLoading = false);
        final data = jsonDecode(response.body);
        _showError(data['error'] ?? "Access denied: ${response.statusCode}");
      } else {
        setState(() => _isLoading = false);
        _showError("Server error: ${response.statusCode}");
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError("Network error: ${e.toString()}");
    }

  }
  // ================= SEND =================
  // Future<void> _sendMessage(String message) async {
  //   if (message.trim().isEmpty) return;
  //
  //   setState(() {
  //     _messages.add({"role": "user", "text": message});
  //     _isLoading = true;
  //   });
  //
  //   _controller.clear();
  //   _scrollToBottom();
  //
  //   try {
  //     final response = await http.post(
  //       Uri.parse(nodeApiUrl),
  //       headers: {'Content-Type': 'application/json'},
  //       body: jsonEncode({"message": message, "session_id": "session-1"}),
  //     );
  //
  //     final data = jsonDecode(response.body);
  //     final botReply = (data['reply'] ?? '').toString();
  //
  //     setState(() {
  //       _messages.add({"role": "bot", "text": botReply});
  //       _isLoading = false;
  //     });
  //
  //     _scrollToBottom();
  //   } catch (_) {
  //     setState(() => _isLoading = false);
  //     _showError("Network error");
  //   }
  // }
  //
  // void _scrollToBottom() {
  //   Future.delayed(const Duration(milliseconds: 200), () {
  //     if (_scrollController.hasClients) {
  //       _scrollController.animateTo(
  //         _scrollController.position.maxScrollExtent,
  //         duration: const Duration(milliseconds: 300),
  //         curve: Curves.easeOut,
  //       );
  //     }
  //   });
  // }

  // ================= STT =================
  void _handleSpeechResult(String text, bool isFinal) async {
    if (!mounted || !_isListening) return;

    // Reset silence timer on ANY result (partial or final) to keep timer active while speaking
    _resetSilenceTimer();

    // Only process FINAL results to avoid duplicates
    if (!isFinal) return;

    // Skip if same text (already processed)
    if (text == _lastRecognizedText) {
      return;
    }

    _lastRecognizedText = text;

    // Combine with previous text, preserving all spoken input
    final combined = _sessionPrefix.isEmpty
        ? text
        : "$_sessionPrefix $text";

    setState(() {
      _controller.text = combined;
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: _controller.text.length),
      );
    });

    // Update session prefix with new text for next utterance
    _sessionPrefix = combined;

    if (_voiceMode == "auto" && _containsUrdu(text)) {
      _voiceMode = "ur";
      _currentLanguage = "ur_PK";
    }

    // Speech service auto-stops after final result - restart immediately
    if (_isListening && !_isRestarting) {
      _isRestarting = true;
      try {
        await _sttService.startListening(
          languageCode: _currentLanguage,
          onResult: _handleSpeechResult,
        );
      } catch (e) {
        debugPrint("STT Restart Error: $e");
      }
      _isRestarting = false;
    }
  }

  Future<void> _startListening() async {
    if (_isListening) return;

    setState(() => _isListening = true);

    String lang = "en_US";
    if (_voiceMode == "ur") lang = "ur_PK";
    if (_voiceMode == "en") lang = "en_US";

    _currentLanguage = lang; // Store for restart
    _sessionPrefix = _controller.text.trim();
    _lastRecognizedText = '';

    try {
      await _sttService.startListening(
        languageCode: lang,
        onResult: _handleSpeechResult,
      );

      _resetSilenceTimer();
    } catch (_) {
      setState(() => _isListening = false);
      _showError("Mic failed to start");
    }
  }

  void _resetSilenceTimer() {
    _silenceTimer?.cancel();
    _silenceTimer = Timer(_silenceDuration, () {
      _stopListening();
    });
  }

  bool _containsUrdu(String text) {
    return RegExp(r'[\u0600-\u06FF]').hasMatch(text);
  }

  void _stopListening() {
    _silenceTimer?.cancel();
    _sttService.stopListening();
    _lastRecognizedText = '';
    _isRestarting = false;
    if (mounted) setState(() => _isListening = false);
  }

  // ================= TTS =================
  Future<void> _speak(String text) async {
    if (text.trim().isEmpty) return;

    try {
      final language = _detectLanguage(text);
      
      // Set language based on detection
      if (language == "ur") {
        await _flutterTts.setLanguage("ur-PK");
      } else {
        await _flutterTts.setLanguage("en-US");
      }

      await _flutterTts.speak(text);
      debugPrint("TTS Playing: Language=$language");
    } catch (e) {
      debugPrint("TTS Error: $e");
      if (mounted) {
        _showError("Could not play audio");
      }
    }
  }

  Future<void> _setLanguageForTts(String languageType) async {
    try {
      if (languageType == "ur") {
        await _flutterTts.setLanguage("ur-PK");
        debugPrint("TTS Language set to Urdu");
      } else {
        await _flutterTts.setLanguage("en-US");
        debugPrint("TTS Language set to English");
      }
    } catch (e) {
      debugPrint("Error setting TTS language: $e");
    }
  }

  String _detectLanguage(String text) {
    if (RegExp(r'[\u0600-\u06FF]').hasMatch(text)) return "ur";

    final romanUrduWords = [
      "hai","hain","kya","ka","ki","ke",
      "aur","agar","yeh","wo","ap","aap",
      "mein","kar","karna"
    ];

    final lower = text.toLowerCase();
    for (var word in romanUrduWords) {
      if (lower.contains(" $word ") ||
          lower.startsWith("$word ") ||
          lower.endsWith(" $word")) {
        return "roman";
      }
    }

    return "en";
  }

  // ================= OCR IMAGE ATTACHMENT =================
  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _attachedImage = File(image.path);
          _extractedOcrText = null;
        });
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
      _showError("Failed to pick image");
    }
  }

  void _clearAttachment() {
    setState(() {
      _attachedImage = null;
      _extractedOcrText = null;
    });
  }

  Future<void> _extractTextFromImage(File imageFile) async {
    setState(() => _isExtractingOcr = true);

    try {
      final uri = ApiConfig.uri('/api/ocr');
      final request = http.MultipartRequest('POST', uri);

      // Add file
      final fileStream = http.ByteStream(imageFile.openRead());
      final fileLength = await imageFile.length();
      final multipartFile = http.MultipartFile(
        'document',
        fileStream,
        fileLength,
        filename: imageFile.path.split('/').last,
      );
      request.files.add(multipartFile);

      // Send request
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          setState(() => _isExtractingOcr = false);
          throw TimeoutException('OCR extraction took too long');
        },
      );

      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final confidence = data['data']?['confidenceScore'] ?? 
                          data['confidenceScore'] ?? 0.0;

        // Check confidence threshold (70%)
        if (confidence >= 0.70) {
          final rawText = data['data']?['rawExtractedText'] ?? 
                         data['rawExtractedText'] ?? '';
          setState(() {
            _extractedOcrText = rawText;
            _isExtractingOcr = false;
          });
          debugPrint("OCR success. Confidence: ${(confidence * 100).toStringAsFixed(1)}%");
        } else {
          setState(() => _isExtractingOcr = false);
          _showError("Unable to extract text. Please try another image.");
          _clearAttachment();
        }
      } else {
        setState(() => _isExtractingOcr = false);
        _showError("OCR extraction failed. Please try again.");
        debugPrint("OCR Error: ${response.statusCode}");
      }
    } catch (e) {
      setState(() => _isExtractingOcr = false);
      _showError("Error extracting text: ${e.toString()}");
      debugPrint("OCR Exception: $e");
    }
  }

  void _showHistoryDialog() {
    if (_messages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No chat history yet')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chat History'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final msg = _messages[index];
              final isUser = msg["role"] == "user";
              final text = msg["text"] ?? "";
              
              return ListTile(
                leading: Icon(
                  isUser ? Icons.person : Icons.smart_toy,
                  color: primaryGreen,
                  size: 18,
                ),
                title: Text(
                  text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: isUser ? primaryGreen : textDark,
                    fontWeight: isUser ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _sttService.stopListening();
    _flutterTts.stop();
    _silenceTimer?.cancel();
    _errorTimer?.cancel();
    _entranceController.dispose();
    super.dispose();
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    final hasMessages = _messages.isNotEmpty;

    return Scaffold(
      backgroundColor: offWhite,
      appBar: AppBar(
        backgroundColor: primaryGreen,
        elevation: 1,
        toolbarHeight: 70,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'LegalMate AI',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        actions: [
          PopupMenuButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) {
              if (value == 'history') {
                _showHistoryDialog();
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem(
                value: 'history',
                child: Text('History'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: hasMessages
                ? _buildChatList()
                : _buildWelcomeScreen(),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildWelcomeScreen() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: Column(
          children: [
            // Icon with animation
            FadeAndSlideUp(
              animation: _iconAnimation,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: primaryGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.psychology_outlined,
                  color: primaryGreen,
                  size: 40,
                ),
              ),
            ),
            const SizedBox(height: 28),

            // Heading
            FadeAndSlideUp(
              animation: _headingAnimation,
              child: Text(
                'I am your legal assistant',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: textDark,
                  height: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Subtitle
            FadeAndSlideUp(
              animation: _subtitleAnimation,
              child: Text(
                'Ask freely � your problem stays confidential',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: textMedium,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 40),

            // Common issues label
            FadeAndSlideUp(
              animation: _subtitleAnimation,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Common issues:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: primaryGreen,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Common issue cards
            _buildCommonIssueCard(
              index: 0,
              icon: Icons.person_outline,
              title: 'Tenant won\'t leave',
              onTap: () => _handleCommonIssueSelect('Tenant won\'t leave'),
            ),
            const SizedBox(height: 12),
            _buildCommonIssueCard(
              index: 1,
              icon: Icons.location_on,
              title: 'Land illegally occupied',
              onTap: () => _handleCommonIssueSelect('Land illegally occupied'),
            ),
            const SizedBox(height: 12),
            _buildCommonIssueCard(
              index: 2,
              icon: Icons.file_present_outlined,
              title: 'How to file an FIR',
              onTap: () => _handleCommonIssueSelect('How to file an FIR'),
            ),
            const SizedBox(height: 12),
            _buildCommonIssueCard(
              index: 3,
              icon: Icons.description_outlined,
              title: 'What is a rent agreement',
              onTap: () => _handleCommonIssueSelect('What is a rent agreement'),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildCommonIssueCard({
    required int index,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return FadeAndSlideUp(
      animation: _cardAnimations[index],
      child: ScaleOnTapIcon(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(icon, color: primaryGreen, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textDark,
                  ),
                ),
              ),
              Icon(Icons.arrow_forward, color: primaryGreen, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _handleCommonIssueSelect(String issue) {
    setState(() {
      _controller.text = issue;
    });
  }

  Widget _buildChatList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        final isUser = msg["role"] == "user";
        final text = msg["text"] ?? "";

        return Align(
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            decoration: BoxDecoration(
              color: isUser ? primaryGreen : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: isUser
                  ? null
                  : Border.all(color: borderColor, width: 1),
              boxShadow: [
                if (!isUser)
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: TextStyle(
                    color: isUser ? Colors.white : textDark,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
                if (!isUser)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.volume_up_outlined,
                          size: 16,
                          color: primaryGreen,
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _speak(text),
                          child: Text(
                            'Listen',
                            style: TextStyle(
                              color: primaryGreen,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInputBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Error message
          if (_errorMessage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _errorMessage,
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

          // Image attachment preview
          if (_attachedImage != null) _buildImagePreview(),

          // OCR extraction loading
          if (_isExtractingOcr)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(primaryGreen),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Extracting text from image...',
                    style: TextStyle(
                      fontSize: 12,
                      color: textMedium,
                    ),
                  ),
                ],
              ),
            ),

          // Input row
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Mic button with listening state
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isListening)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        'Listening...',
                        style: TextStyle(
                          fontSize: 10,
                          color: primaryGreen,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ScaleOnTapIcon(
                    onTap: _isListening ? _stopListening : _startListening,
                    child: Icon(
                      _isListening ? Icons.mic : Icons.mic_none,
                      color: _isListening ? primaryGreen : textMedium,
                      size: 22,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),

              // Attachment button
              ScaleOnTapIcon(
                onTap: _pickImage,
                child: const Icon(
                  Icons.attachment,
                  color: textMedium,
                  size: 22,
                ),
              ),
              const SizedBox(width: 8),

              // Text field
              Expanded(
                child: TextField(
                  controller: _controller,
                  maxLines: null,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(_controller.text),
                  decoration: InputDecoration(
                    hintText: 'Type your question...',
                    hintStyle: const TextStyle(
                      color: textLight,
                      fontSize: 13,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: borderColor,
                        width: 1,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: primaryGreen,
                        width: 1.5,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: borderColor,
                        width: 1,
                      ),
                    ),
                  ),
                  style: const TextStyle(
                    fontSize: 13,
                    color: textDark,
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Send button
              ScaleOnTapIcon(
                onTap: _isLoading ? null : () => _sendMessage(_controller.text),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: primaryGreen,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: _isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : const Icon(
                            Icons.send,
                            color: Colors.white,
                            size: 20,
                          ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.file(
              _attachedImage!,
              width: 50,
              height: 50,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _attachedImage!.path.split('/').last,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: textDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Ready to extract',
                  style: TextStyle(
                    fontSize: 11,
                    color: textLight,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: _clearAttachment,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          ),
        ],
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
class ScaleOnTapIcon extends StatefulWidget {
  final VoidCallback? onTap;
  final Widget child;

  const ScaleOnTapIcon({
    required this.onTap,
    required this.child,
    super.key,
  });

  @override
  State<ScaleOnTapIcon> createState() => _ScaleOnTapIconState();
}

class _ScaleOnTapIconState extends State<ScaleOnTapIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.85).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _controller.reverse();
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onTap != null ? _onTapDown : null,
      onTapUp: widget.onTap != null ? _onTapUp : null,
      onTapCancel: widget.onTap != null
          ? () {
              _controller.reverse();
            }
          : null,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
    }
