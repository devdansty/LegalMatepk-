import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';

class ChatBotPage extends StatefulWidget {
  const ChatBotPage({super.key});

  @override
  State<ChatBotPage> createState() => _ChatBotPageState();
}

class _ChatBotPageState extends State<ChatBotPage> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _messages = [];
  final ScrollController _scrollController = ScrollController();

  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();

  bool _isListening = false;
  bool _isLoading = false;

  // <<<<<<<<<<<<<<<<< IMPORTANT: change this to your Node server URL >>>>>>>>>>>>>>>>>
  // - Android emulator: use http://10.0.2.2:3000/api/chat
  // - iOS simulator: use http://localhost:3000/api/chat
  // - Physical device: use your machine LAN IP e.g. http://192.168.1.10:3000/api/chat
  //
  // The Node proxy response shape assumed here:
  // { "success": true, "reply": "model reply text", "extra": {...} }
  final String nodeApiUrl = 'http://192.168.0.108:3000/api/chatbot';
  // <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

  Future<void> _sendMessage(String message) async {
    if (message.trim().isEmpty) return;

    setState(() {
      _messages.add({"role": "user", "text": message});
      _isLoading = true;
    });

    _controller.clear();
    _scrollToBottom();

    try {
      // small UX delay (optional)
      await Future.delayed(const Duration(milliseconds: 200));

      final response = await http
          .post(
        Uri.parse(nodeApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"message": message, "session_id": "session-1"}),
      )
          .timeout(const Duration(seconds: 120));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);

        // Node proxy: expected fields: success, reply, extra
        final bool ok = data['success'] == true || data['success'] == null;
        final String botReply = (data['reply'] ?? data['message'] ?? '').toString();

        if (ok && botReply.isNotEmpty) {
          setState(() {
            _messages.add({"role": "bot", "text": botReply});
            _isLoading = false;
          });
          _scrollToBottom();
          await _speak(botReply);
        } else {
          // fallback when shape differs or no reply
          final fallback = data['reply']?.toString() ??
              data['message']?.toString() ??
              'Sorry, I did not get a response.';
          setState(() {
            _messages.add({"role": "bot", "text": fallback});
            _isLoading = false;
          });
          _scrollToBottom();
          await _speak(fallback);
        }
      } else {
        setState(() {
          _isLoading = false;
          _messages.add({"role": "bot", "text": "Server error: ${response.statusCode}"});
        });
        _scrollToBottom();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _messages.add({"role": "bot", "text": "Network error: ${e.toString()}"});
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    // scroll to the end (bottom). list is natural order from top -> bottom, so animate to max.
    // Use a small delay so UI finished building the new tile.
    Future.delayed(const Duration(milliseconds: 200), () {
      if (_scrollController.hasClients) {
        final position = _scrollController.position.maxScrollExtent;
        _scrollController.animateTo(
          position,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _startListening() async {
    bool available = await _speech.initialize(
      onStatus: (status) {
        // optional: handle status updates
        // print('STT status: $status');
      },
      onError: (error) {
        // optional: handle errors
        // print('STT error: $error');
      },
    );
    if (available) {
      setState(() => _isListening = true);
      _speech.listen(onResult: (result) {
        setState(() {
          _controller.text = result.recognizedWords;
        });
      });
    } else {
      // STT unavailable: inform user or fallback
      setState(() {
        _messages.add({"role": "bot", "text": "Speech recognition is not available on this device."});
      });
    }
  }

  void _stopListening() {
    _speech.stop();
    setState(() => _isListening = false);
  }

  Future<void> _speak(String text) async {
    try {
      await _flutterTts.stop();
      await _flutterTts.speak(text);
    } catch (e) {
      // ignore TTS errors silently or show message if you want
    }
  }

  void _clearChat() {
    setState(() {
      _messages.clear();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _speech.stop();
    _flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color darkGreen = Color(0xFF004B23);
    const Color offWhite = Color(0xFFF8F9F9);
    const Color bubbleGreen = Color(0xFF006400);

    return Scaffold(
      backgroundColor: offWhite, // ✅ off-white background
      appBar: AppBar(
        title: const Text(
          'LegalMate Chatbot',
          style: TextStyle(color: Colors.white), // ✅ white heading
        ),
        centerTitle: true,
        backgroundColor: darkGreen,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever, color: Colors.white),
            onPressed: _clearChat,
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final isUser = message["role"] == "user";
                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                    decoration: BoxDecoration(
                      color: isUser ? bubbleGreen : Colors.grey.shade300,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: isUser ? const Radius.circular(16) : const Radius.circular(0),
                        bottomRight: isUser ? const Radius.circular(0) : const Radius.circular(16),
                      ),
                    ),
                    child: Text(
                      message["text"] ?? "",
                      style: TextStyle(
                        color: isUser ? Colors.white : Colors.black87,
                        fontSize: 16,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(color: Color(0xFF006400)),
            ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    const Color bubbleGreen = Color(0xFF006400);
    const Color offWhite = Color(0xFFF8F9F9);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Container(
          decoration: BoxDecoration(
            color: offWhite, // ✅ off-white bottom bar
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              IconButton(
                icon: Icon(_isListening ? Icons.mic : Icons.mic_none, color: bubbleGreen),
                onPressed: _isListening ? _stopListening : _startListening,
              ),
              Expanded(
                child: TextField(
                  controller: _controller,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (text) => _sendMessage(text),
                  decoration: const InputDecoration(
                    hintText: "Ask LegalMate...",
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 10),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send, color: bubbleGreen),
                onPressed: () => _sendMessage(_controller.text),
              ),
            ],
          ),
        ),
      ),
    );
  }
}