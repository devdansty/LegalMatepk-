// dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:image_picker/image_picker.dart';
import '../services/STT.dart';
import '../config/api_config.dart';
import 'signin_screen.dart';

class ChatBotPage extends StatefulWidget {
  const ChatBotPage({super.key});

  @override
  State<ChatBotPage> createState() => _ChatBotPageState();
}

class _ChatBotPageState extends State<ChatBotPage> {

  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _messages = [];
  final ScrollController _scrollController = ScrollController();

  final STTService _sttService = STTService();
  final FlutterTts _flutterTts = FlutterTts();

  bool _isListening = false;
  bool _isLoading = false;
  String _errorMessage = '';

  Timer? _silenceTimer;
  Timer? _errorTimer;
  bool _isRestarting = false;
  final Duration _silenceDuration = const Duration(seconds: 4); // 4 seconds of silence to stop

  String _lastRecognizedText = '';
  String _sessionPrefix = '';
  String _currentLanguage = "en_US"; // Store current language for restart

  String _voiceMode = "auto"; // auto | ur | en

  // OCR Image attachment
  File? _attachedImage;
  final ImagePicker _imagePicker = ImagePicker();
  bool _isExtractingOcr = false;
  String? _extractedOcrText;

  // ================= INIT =================
  @override
  void initState() {
    super.initState();
    _initTts();
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

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _sttService.stopListening();
    _flutterTts.stop();
    _silenceTimer?.cancel();
    _errorTimer?.cancel();
    super.dispose();
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    const bubbleGreen = Color(0xFF006400);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Legal Chatbot'),
        backgroundColor: const Color(0xFF004B23),
      ),
      body: Column(
        children: [
          _buildLanguageToggle(),
          Expanded(child: _buildChatList()),
          if (_isLoading) const CircularProgressIndicator(),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildLanguageToggle() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 8,
        children: [
          _langChip("Auto", "auto"),
          _langChip("اردو", "ur"),
          _langChip("English", "en"),
        ],
      ),
    );
  }

  Widget _langChip(String label, String value) {
    final selected = _voiceMode == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _voiceMode = value),
    );
  }

  Widget _buildChatList() {
    const bubbleGreen = Color(0xFF006400);

    return ListView.builder(
      controller: _scrollController,
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        final isUser = msg["role"] == "user";
        final text = msg["text"] ?? "";

        return Align(
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Row(
            mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.all(8),
                padding: const EdgeInsets.all(12),
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.68,
                ),
                decoration: BoxDecoration(
                  color: isUser ? bubbleGreen : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  text,
                  style: TextStyle(
                    color: isUser ? Colors.white : Colors.black,
                    fontSize: 15,
                  ),
                ),
              ),
              if (!isUser)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: SizedBox(
                    height: 32,
                    width: 32,
                    child: OutlinedButton(
                      onPressed: () => _speak(text),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        side: const BorderSide(
                          color: bubbleGreen,
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Icon(
                        Icons.play_arrow,
                        size: 18,
                        color: bubbleGreen,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInputBar() {
    const bubbleGreen = Color(0xFF006400);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: Column(
        children: [
          if (_isListening) _buildListeningLabel(),
          // Image attachment preview
          if (_attachedImage != null) _buildImagePreview(),
          // OCR extraction loading indicator
          if (_isExtractingOcr)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: const [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(bubbleGreen),
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    "Extracting text from image...",
                    style: TextStyle(fontSize: 12, color: bubbleGreen),
                  ),
                ],
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Mic Button Column
              Column(
                children: [
                  IconButton(
                    icon: Icon(
                      _isListening ? Icons.mic : Icons.mic_none,
                      color: bubbleGreen,
                      size: _isListening ? 32 : 24,
                    ),
                    onPressed: _isListening ? _stopListening : _startListening,
                  ),
                  if (_isListening)
                    const Text(
                      "Stop",
                      style: TextStyle(
                        fontSize: 10,
                        color: bubbleGreen,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
              // Attachment Button
              IconButton(
                icon: const Icon(Icons.attach_file, color: bubbleGreen),
                onPressed: _isListening || _isExtractingOcr ? null : _pickImage,
                tooltip: "Attach image",
              ),
              // Text Field
              Expanded(
                child: Opacity(
                  opacity: _isListening ? 0.5 : 1.0,
                  child: TextField(
                    controller: _controller,
                    enabled: !_isListening && !_isExtractingOcr,
                    maxLines: 4,
                    minLines: 2,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      hintText: "Ask LegalMate...",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ),
              ),
              // Send Button
              IconButton(
                icon: const Icon(Icons.send, color: bubbleGreen),
                onPressed: (_isListening || _isExtractingOcr)
                    ? null
                    : () => _sendMessage(_controller.text),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview() {
    const bubbleGreen = Color(0xFF006400);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          // Image thumbnail
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
          // File info and clear button
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _attachedImage!.path.split('/').last,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
                if (_extractedOcrText != null)
                  const Text(
                    "Text extracted ✓",
                    style: TextStyle(fontSize: 11, color: Colors.green),
                  ),
              ],
            ),
          ),
          // Clear button
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: _clearAttachment,
            tooltip: "Remove image",
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          ),
        ],
      ),
    );
  }

  Widget _buildListeningLabel() {
    String label = "ðŸŽ¤ Listening...";
    if (_voiceMode == "auto") label = "ðŸŽ¤ Auto detecting...";
    if (_voiceMode == "ur") label = "ðŸŽ¤ Listening in Urdu...";
    if (_voiceMode == "en") label = "ðŸŽ¤ Listening in English...";

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(label,
          style: const TextStyle(fontSize: 12, color: Colors.grey)),
    );
  }
}
