import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

import 'lawyer_connect_screen.dart';

class LawyerProfileScreen extends StatefulWidget {
  final String lawyerId;
  final LawyerCardData? initialData;

  const LawyerProfileScreen({
    super.key,
    required this.lawyerId,
    this.initialData,
  });

  @override
  State<LawyerProfileScreen> createState() => _LawyerProfileScreenState();
}

class _LawyerProfileScreenState extends State<LawyerProfileScreen> {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final TextEditingController _queryController = TextEditingController();

  bool _isLoadingProfile = true;
  bool _isSending = false;
  bool _isCheckingStatus = false;
  String? _error;

  LawyerCardData? _lawyer;
  String? _requestStatus;
  String? _approvedEmail;
  String? _approvedPhone;

  @override
  void initState() {
    super.initState();
    _lawyer = widget.initialData;
    _loadAll();
  }

  Future<void> _loadAll() async {
    await _loadLawyerProfile();
    await _loadConnectionStatus();
  }

  Future<void> _loadLawyerProfile() async {
    setState(() {
      _isLoadingProfile = true;
      _error = null;
    });

    try {
      final response = await http
          .get(ApiConfig.uri('/api/lawyers/profile/${widget.lawyerId}'))
          .timeout(const Duration(seconds: 30));

      final body = response.body.isNotEmpty ? jsonDecode(response.body) : {};

      if (response.statusCode == 200 && body is Map && body['data'] is Map<String, dynamic>) {
        final parsed = LawyerCardData.fromJson(body['data'] as Map<String, dynamic>);

        if (!mounted) return;
        setState(() {
          _lawyer = parsed;
          _isLoadingProfile = false;
        });
        return;
      }

      if (!mounted) return;
      setState(() {
        _error = (body is Map && body['error'] != null)
            ? body['error'].toString()
            : 'Failed to load lawyer profile';
        _isLoadingProfile = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Network error: $e';
        _isLoadingProfile = false;
      });
    }
  }

  Future<void> _loadConnectionStatus() async {
    final token = await _secureStorage.read(key: 'accessToken');
    if (token == null || token.isEmpty) {
      return;
    }

    setState(() => _isCheckingStatus = true);

    try {
      final response = await http.get(
        ApiConfig.uri('/api/lawyers/my-connections'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final body = response.body.isNotEmpty ? jsonDecode(response.body) : {};
      final list = body is Map && body['data'] is List ? body['data'] as List : const [];

      Map<String, dynamic>? match;
      for (final item in list) {
        if (item is! Map<String, dynamic>) continue;
        final lawyer = item['lawyer'];
        if (lawyer is! Map<String, dynamic>) continue;

        final id = (lawyer['_id'] ?? lawyer['id'] ?? '').toString();
        if (id == widget.lawyerId) {
          match = item;
          break;
        }
      }

      if (!mounted) return;

      if (match != null) {
        final lawyer = match['lawyer'] as Map<String, dynamic>?;
        setState(() {
          _requestStatus = (match!['status'] ?? '').toString();
          _approvedEmail = lawyer?['email']?.toString();
          _approvedPhone = lawyer?['phone']?.toString();
          _isCheckingStatus = false;
        });
      } else {
        setState(() {
          _requestStatus = null;
          _approvedEmail = null;
          _approvedPhone = null;
          _isCheckingStatus = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isCheckingStatus = false);
    }
  }

  Future<void> _sendRequest() async {
    final query = _queryController.text.trim();
    if (query.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your legal query first')),
      );
      return;
    }

    final token = await _secureStorage.read(key: 'accessToken');
    final isGuest = await _secureStorage.read(key: 'is_guest');

    // Check if user is guest
    if (isGuest == 'true') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This feature is not available for guest users. Please sign up to connect with lawyers.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Check if user is authenticated
    if (token == null || token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in to send a connection request'),
        ),
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      final response = await http
          .post(
            ApiConfig.uri('/api/lawyers/request'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'lawyerId': widget.lawyerId,
              'query': query,
            }),
          )
          .timeout(const Duration(seconds: 30));

      final body = response.body.isNotEmpty ? jsonDecode(response.body) : {};

      if (!mounted) return;

      if (response.statusCode == 201) {
        setState(() {
          _requestStatus = 'pending';
          _isSending = false;
        });
        _queryController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request sent successfully. Lawyer will review it soon.'),
          ),
        );
        return;
      }

      setState(() => _isSending = false);
      final error = (body is Map && body['error'] != null)
          ? body['error'].toString()
          : 'Failed to send request';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Network error: $e')),
      );
    }
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color darkGreen = Color(0xFF004B23);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lawyer Profile'),
        backgroundColor: darkGreen,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _isCheckingStatus ? null : _loadConnectionStatus,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh request status',
          )
        ],
      ),
      body: _buildBody(darkGreen),
    );
  }

  Widget _buildBody(Color darkGreen) {
    if (_isLoadingProfile) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loadLawyerProfile,
              style: ElevatedButton.styleFrom(backgroundColor: darkGreen),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_lawyer == null) {
      return const Center(child: Text('Lawyer profile unavailable'));
    }

    final contactApproved = _requestStatus == 'accepted';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _lawyer!.name,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text('Specialization: ${_lawyer!.specialization.join(', ')}'),
                const SizedBox(height: 6),
                Text('City: ${_lawyer!.city}'),
                const SizedBox(height: 6),
                Text('Experience: ${_lawyer!.experienceYears} years'),
                const SizedBox(height: 10),
                Text(_lawyer!.bio),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Request Contact Access',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _queryController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Describe your legal query for this lawyer',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (_isSending || _requestStatus == 'pending') ? null : _sendRequest,
                    style: ElevatedButton.styleFrom(backgroundColor: darkGreen),
                    child: _isSending
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            _requestStatus == 'pending'
                                ? 'Request Pending'
                                : 'Send Contact Request',
                          ),
                  ),
                ),
                const SizedBox(height: 10),
                _buildStatusLine(),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: contactApproved ? Colors.green.shade50 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: contactApproved ? Colors.green.shade200 : Colors.grey.shade300,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Contact Information',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (contactApproved) ...[
                  Text('Email: ${_approvedEmail ?? 'Not available'}'),
                  const SizedBox(height: 4),
                  Text('Phone: ${_approvedPhone ?? 'Not available'}'),
                ] else
                  const Text(
                    'Contact information will appear here after the lawyer approves your request.',
                  ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildStatusLine() {
    if (_isCheckingStatus) {
      return const Text('Checking request status...');
    }

    if (_requestStatus == null || _requestStatus!.isEmpty) {
      return const Text('No request sent yet.');
    }

    if (_requestStatus == 'accepted') {
      return const Text(
        'Your request has been approved.',
        style: TextStyle(color: Colors.green),
      );
    }

    if (_requestStatus == 'rejected') {
      return const Text(
        'Your request was rejected.',
        style: TextStyle(color: Colors.red),
      );
    }

    return const Text(
      'Your request is pending approval.',
      style: TextStyle(color: Colors.orange),
    );
  }
}

