// dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_tts/flutter_tts.dart';
import '../services/STT.dart';
import '../config/api_config.dart';
import 'signin_screen.dart';

class ChatBotPage extends StatefulWidget {
  const ChatBotPage({super.key});

  @override
  State<ChatBotPage> createState() => _ChatBotPageState();
}

class _ChatBotPageState extends State<ChatBotPage> {
  bool useDummyReplies = true; // ðŸ” switch to false when backend is ready
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
  final Duration _silenceDuration = const Duration(seconds: 10);

  String _lastRecognizedText = '';
  String _sessionPrefix = '';

  String _voiceMode = "auto"; // auto | ur | en

  // ================= INIT =================
  @override
  void initState() {
    super.initState();
    _initTts();
  }

  Future<void> _initTts() async {
    await _flutterTts.setSpeechRate(0.45);
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.awaitSpeakCompletion(true);
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

    setState(() {
      _messages.add({"role": "user", "text": message});
      _isLoading = true;
      _errorMessage = '';
    });

    _controller.clear();
    _scrollToBottom();

    // ================= DUMMY MODE =================
    if (useDummyReplies) {
      await Future.delayed(const Duration(seconds: 1));

      final List<String> dummyReplies = [
        "Ø§Ù„Ø³Ù„Ø§Ù… Ø¹Ù„ÛŒÚ©Ù…! Ù…ÛŒÚº Ø¢Ù¾ Ú©ÛŒ Ú©ÛŒØ³Û’ Ù…Ø¯Ø¯ Ú©Ø± Ø³Ú©ØªØ§ ÛÙˆÚºØŸ",
        "ÛŒÛ Ø§ÛŒÚ© Ù¹ÛŒØ³Ù¹ Ø¬ÙˆØ§Ø¨ ÛÛ’ ØªØ§Ú©Û Ù¹ÛŒÚ©Ø³Ù¹ Ù¹Ùˆ Ø§Ø³Ù¾ÛŒÚ† Ú©Ùˆ Ú†ÛŒÚ© Ú©ÛŒØ§ Ø¬Ø§ Ø³Ú©Û’Û”",
        "Yeh sirf testing ke liye dummy response hai.",
        "Hello! This is a dummy reply for testing purposes.",
        "Ø¯Ø±Ø®ÙˆØ§Ø³Øª Ú¯Ø²Ø§Ø± Ú©Ùˆ Ù…Ø·Ù„Ø¹ Ú©ÛŒØ§ Ø¬Ø§ØªØ§ ÛÛ’ Ú©Û Ø§Ù¾ÛŒÙ„ Ú©ÛŒ Ù…Ø¯Øª ØªÛŒØ³ Ø¯Ù† ÛÛ’Û”"
      ];

      dummyReplies.shuffle();
      final botReply = dummyReplies.first;

      setState(() {
        _messages.add({"role": "bot", "text": botReply});
        _isLoading = false;
      });
      _scrollToBottom();
      return;
    }

    // ================= REAL API MODE =================
    try {
      final response = await http.post(
        ApiConfig.uri('/api/chatbot'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"message": message, "session_id": "session-1"}),
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final botReply =
        (data['reply'] ?? data['message'] ?? '').toString();

        setState(() {
          _messages.add({"role": "bot", "text": botReply});
          _isLoading = false;
        });

        _scrollToBottom();
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
  Future<void> _startListening() async {
    if (_isListening) return;

    setState(() => _isListening = true);

    String lang = "en_US";
    if (_voiceMode == "ur") lang = "ur_PK";
    if (_voiceMode == "en") lang = "en_US";

    _sessionPrefix = _controller.text.trim();
    _lastRecognizedText = '';

    try {
      await _sttService.startListening(
        languageCode: lang,
        onResult: (text) async {
          if (!mounted) return;

          if (text == _lastRecognizedText &&
              _silenceTimer != null &&
              _silenceTimer!.isActive) {
            return;
          }

          _lastRecognizedText = text;

          final combined = _sessionPrefix.isEmpty
              ? text
              : "$_sessionPrefix $text";

          setState(() {
            _controller.text = combined;
            _controller.selection = TextSelection.fromPosition(
              TextPosition(offset: _controller.text.length),
            );
          });

          _resetSilenceTimer();

          if (_voiceMode == "auto" && _containsUrdu(text)) {
            _voiceMode = "ur";
          }

          if (_isListening) {
            _sttService.stopListening();
            await Future.delayed(const Duration(milliseconds: 250));
            if (_isListening) _startListening();
          }
        },
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
    if (mounted) setState(() => _isListening = false);
  }

  // ================= TTS =================
  Future<void> _speak(String text) async {
    if (text.trim().isEmpty) return;

    try {
      await _flutterTts.stop();

      final language = _detectLanguage(text);
      await _setVoice(language);

      await _flutterTts.speak(text);
    } catch (e) {
      debugPrint("TTS Error: $e");
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

  Future<void> _setVoice(String languageType) async {
    final voices = await _flutterTts.getVoices;
    if (voices == null) return;

    Map<String, dynamic>? selectedVoice;

    if (languageType == "ur") {
      selectedVoice = voices.firstWhere(
            (voice) =>
        (voice["locale"]?.toString().contains("ur") ?? false),
        orElse: () => voices.first,
      );
      await _flutterTts.setLanguage("ur-PK");
    } else {
      selectedVoice = voices.firstWhere(
            (voice) =>
        (voice["locale"]?.toString().contains("en") ?? false),
        orElse: () => voices.first,
      );
      await _flutterTts.setLanguage("en-US");
    }

    if (selectedVoice != null) {
      await _flutterTts.setVoice({
        "name": selectedVoice["name"],
        "locale": selectedVoice["locale"],
      });
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
          _langChip("Ø§Ø±Ø¯Ùˆ", "ur"),
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
          child: Container(
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isUser ? bubbleGreen : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Stack(
              children: [
                Text(text,
                    style: TextStyle(
                        color: isUser ? Colors.white : Colors.black)),
                if (!isUser)
                  Positioned(
                    right: -5,
                    top: -5,
                    child: GestureDetector(
                      onTap: () => _speak(text),
                      child: const CircleAvatar(
                        radius: 12,
                        backgroundColor: bubbleGreen,
                        child: Icon(Icons.play_arrow,
                            size: 14, color: Colors.white),
                      ),
                    ),
                  )
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInputBar() {
    const bubbleGreen = Color(0xFF006400);

    return Column(
      children: [
        if (_isListening) _buildListeningLabel(),
        Row(
          children: [
            IconButton(
              icon: Icon(
                  _isListening ? Icons.mic : Icons.mic_none,
                  color: bubbleGreen),
              onPressed:
              _isListening ? _stopListening : _startListening,
            ),
            Expanded(
              child: TextField(
                controller: _controller,
                decoration:
                const InputDecoration(hintText: "Ask LegalMate..."),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.send, color: bubbleGreen),
              onPressed: () => _sendMessage(_controller.text),
            ),
          ],
        ),
      ],
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
