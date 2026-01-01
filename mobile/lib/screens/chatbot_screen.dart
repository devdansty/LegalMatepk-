import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
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

  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();

  bool _isListening = false;
  bool _isLoading = false;
  String _errorMessage = ''; // new error state
  Timer? _errorTimer; // timer to auto-hide banner

  // <<<<<<<<<<<<<<<<< IMPORTANT: change this to your Node server URL >>>>>>>>>>>>>>>>>
  final String nodeApiUrl = 'http://192.168.0.108:3000/api/chatbot';
  // <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

  void _showError(String msg, {Duration duration = const Duration(seconds: 4)}) {
    _errorTimer?.cancel();
    setState(() => _errorMessage = msg);
    _errorTimer = Timer(duration, () {
      if (mounted) setState(() => _errorMessage = '');
    });
  }

  Future<void> _sendMessage(String message) async {
    if (message.trim().isEmpty) return;

    setState(() {
      _messages.add({"role": "user", "text": message});
      _isLoading = true;
      _errorMessage = ''; // clear previous errors when sending
    });

    _controller.clear();
    _scrollToBottom();

    try {
      await Future.delayed(const Duration(milliseconds: 200));

      final response = await http
          .post(
        Uri.parse(nodeApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"message": message, "session_id": "session-1"}),
      )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);

        final bool ok = data['success'] == true || data['success'] == null;
        final String botReply = (data['reply'] ?? data['message'] ?? '').toString();

        if (ok && botReply.isNotEmpty) {
          setState(() {
            _messages.add({"role": "bot", "text": botReply});
            _isLoading = false;
            _errorMessage = '';
          });
          _scrollToBottom();
          // auto TTS disabled: user must tap play button to hear replies
        } else {
          final fallback = data['reply']?.toString() ??
              data['message']?.toString() ??
              'Sorry, I did not get a response.';
          setState(() {
            _messages.add({"role": "bot", "text": fallback});
            _isLoading = false;
            _errorMessage = '';
          });
          _scrollToBottom();
          // auto TTS disabled
        }
      } else {
        setState(() {
          _isLoading = false;
        });
        _showError("Server error: ${response.statusCode}");
        _scrollToBottom();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showError("Network error: ${e.toString()}");
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
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
      onStatus: (status) {},
      onError: (error) {},
    );
    if (available) {
      setState(() => _isListening = true);
      _speech.listen(onResult: (result) {
        setState(() {
          _controller.text = result.recognizedWords;
        });
      });
    } else {
      _showError("Speech recognition is not available on this device.");
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
      // ignore
    }
  }

  void _clearChat() {
    setState(() {
      _messages.clear();
      _errorMessage = '';
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _speech.stop();
    _flutterTts.stop();
    _errorTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color darkGreen = Color(0xFF004B23);
    const Color offWhite = Color(0xFFF8F9F9);
    const Color bubbleGreen = Color(0xFF006400);

    return Scaffold(
      backgroundColor: offWhite,
      appBar: AppBar(
        title: const Text(
          'Legal Chatbot',
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: darkGreen,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) async {
              switch (value) {
                case 'logout':
                  setState(() => _isLoading = true);

                  try {
                    // read access token from secure storage
                    final accessToken = await secureStorage.read(key: 'accessToken');

                    final headers = <String, String>{
                      'Content-Type': 'application/json',
                      if (accessToken != null && accessToken.isNotEmpty)
                        'Authorization': 'Bearer $accessToken',
                    };

                    final response = await http.post(
                      Uri.parse('http://192.168.100.147:3000/api/sessions/logout'),
                      headers: headers,
                    );

                    if (response.statusCode == 200) {
                      if (mounted) {
                        // clear chat messages on logout (optional)
                        _messages.clear();

                        // delete stored access token
                        await secureStorage.delete(key: 'accessToken');

                        setState(() => _isLoading = false);

                        // Navigate to SignInScreen and remove previous routes
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const SignInScreen()),
                              (route) => false,
                        );
                      }
                    } else {
                      setState(() => _isLoading = false);
                      // if server sends JSON, try to show its error message
                      String serverMsg = 'Logout failed: ${response.statusCode}';
                      try {
                        final Map<String, dynamic> body = jsonDecode(response.body);
                        if (body['error'] != null) serverMsg = body['error'].toString();
                      } catch (_) {}
                      _showError(serverMsg);
                    }
                  } catch (e) {
                    setState(() => _isLoading = false);
                    _showError('Network error during logout');
                  }
                  break;
                case 'settings':
                  _showError('Settings clicked'); // dummy action
                  break;

                case 'profile':
                  _showError('Profile clicked'); // dummy action
                  break;

                case 'chat':
                  _showError('Chat clicked'); // dummy action
                  break;
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem(value: 'logout', child: Text('Logout')),
              const PopupMenuItem(value: 'settings', child: Text('Settings')),
              const PopupMenuItem(value: 'profile', child: Text('Profile')),
              const PopupMenuItem(value: 'chat', child: Text('Chat')),
            ],
          )
        ],
      ),


      body: Column(
        children: [
          // Top error banner (auto-dismisses)
          if (_errorMessage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.red.shade600,
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _errorMessage,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () {
                        _errorTimer?.cancel();
                        setState(() => _errorMessage = '');
                      },
                    ),
                  ],
                ),
              ),
            ),

          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final isUser = message["role"] == "user";
                final text = message["text"] ?? "";
                final innerPadding = isUser
                    ? const EdgeInsets.all(12)
                    : const EdgeInsets.fromLTRB(12, 12, 44, 12); // space for play button

                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        padding: innerPadding,
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
                          text,
                          style: TextStyle(
                            color: isUser ? Colors.white : Colors.black87,
                            fontSize: 16,
                          ),
                        ),
                      ),

                      // Play button for bot messages (small, top-right)
                      if (!isUser && text.isNotEmpty)
                        Positioned(
                          top: -6,
                          right: -6,
                          child: GestureDetector(
                            onTap: () => _speak(text),
                            child: CircleAvatar(
                              radius: 14,
                              backgroundColor: bubbleGreen,
                              child: const Icon(Icons.play_arrow, size: 16, color: Colors.white),
                            ),
                          ),
                        ),
                    ],
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
            color: offWhite,
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
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  minLines: 1,
                  maxLines: null, // allows the TextField to grow vertically and wrap text
                  decoration: const InputDecoration(
                    hintText: "Ask LegalMate...",
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
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
