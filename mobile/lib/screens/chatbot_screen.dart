// dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_tts/flutter_tts.dart';
import '../services/STT.dart';
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
  final Duration _silenceDuration = const Duration(seconds: 10);

  // STT stability buffers
  String _lastRecognizedText = '';
  String _sessionPrefix = '';

  // 🌍 HYBRID LANGUAGE MODE
  String _voiceMode = "auto"; // auto | ur | en

  final String nodeApiUrl = 'http://192.168.0.108:3000/api/chatbot';

  // ================= ERROR =================
  void _showError(String msg, {Duration duration = const Duration(seconds: 4)}) {
    _errorTimer?.cancel();
    setState(() => _errorMessage = msg);
    _errorTimer = Timer(duration, () {
      if (mounted) setState(() => _errorMessage = '');
    });
  }

  // ================= SEND =================
  Future<void> _sendMessage(String message) async {
    if (message.trim().isEmpty) return;

    setState(() {
      _messages.add({"role": "user", "text": message});
      _isLoading = true;
    });

    _controller.clear();
    _scrollToBottom();

    try {
      final response = await http.post(
        Uri.parse(nodeApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"message": message, "session_id": "session-1"}),
      );

      final data = jsonDecode(response.body);
      final botReply = (data['reply'] ?? '').toString();

      setState(() {
        _messages.add({"role": "bot", "text": botReply});
        _isLoading = false;
      });

      _scrollToBottom();
    } catch (_) {
      setState(() => _isLoading = false);
      _showError("Network error");
    }
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

  // ================= START LISTENING =================
  Future<void> _startListening() async {
    if (_isListening) return;

    setState(() => _isListening = true);

    String lang = "en_US";
    if (_voiceMode == "ur") lang = "ur_PK";
    if (_voiceMode == "en") lang = "en_US";
    if (_voiceMode == "auto") lang = "en_US";

    // Save previous text for concatenation across sessions
    _sessionPrefix = _controller.text.trim();
    _lastRecognizedText = '';

    try {
      await _sttService.startListening(
        languageCode: lang,
        onResult: (text) async {
          if (!mounted) return;

          // Prevent rapid duplicate partial spam only
          if (text == _lastRecognizedText &&
              _silenceTimer != null &&
              _silenceTimer!.isActive) {
            return;
          }

          _lastRecognizedText = text;

          // Combine with previous session text
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

          // 🌍 Optional Urdu auto detect
          if (_voiceMode == "auto" && _containsUrdu(text)) {
            await _switchToUrdu();
          }

          // 🔁 CRITICAL FIX: Restart listening for next phrase
          if (_isListening) {
            _sttService.stopListening();
            await Future.delayed(const Duration(milliseconds: 250));

            if (_isListening) {
              _startListening(); // silent restart
            }
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

  // ================= URDU SWITCH =================
  Future<void> _switchToUrdu() async {
    // ✅ DO NOT restart mic if already switched once
    if (!_isListening) return;

    // Prevent multiple Urdu switches
    if (_voiceMode == "ur") return;

    // Lock mode to Urdu but DO NOT restart STT session
    _voiceMode = "ur";
  }

  bool _containsUrdu(String text) {
    return RegExp(r'[\u0600-\u06FF]').hasMatch(text);
  }

  // ================= STOP LISTENING =================
  void _stopListening() {
    _silenceTimer?.cancel();
    _sttService.stopListening();
    _lastRecognizedText = '';

    if (mounted) {
      setState(() => _isListening = false);
    }
  }

  // ================= TTS =================
  Future<void> _speak(String text) async {
    await _flutterTts.stop();
    await _flutterTts.speak(text);
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

  // ================= LANGUAGE TOGGLE =================
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

  // ================= CHAT =================
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

  // ================= INPUT BAR =================
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
    String label = "🎤 Listening...";

    if (_voiceMode == "auto") label = "🎤 Auto detecting...";
    if (_voiceMode == "ur") label = "🎤 Listening in Urdu...";
    if (_voiceMode == "en") label = "🎤 Listening in English...";

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(label,
          style: const TextStyle(fontSize: 12, color: Colors.grey)),
    );
  }
}