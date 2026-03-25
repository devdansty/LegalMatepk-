import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class LawyerDashboard extends StatefulWidget {
  const LawyerDashboard({super.key});

  @override
  State<LawyerDashboard> createState() => _LawyerDashboardState();
}

class _LawyerDashboardState extends State<LawyerDashboard> {
  static const List<String> _specializationOptions = [
    'family',
    'criminal',
    'corporate',
    'property',
    'cybercrime',
    'immigration',
  ];

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _experienceController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isRefreshingRequests = false;
  bool _isVisible = true;
  String? _email;
  String? _status;
  String? _error;
  List<String> _selectedSpecializations = [];
  List<LawyerRequestData> _requests = [];

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<String?> _getToken() {
    return _secureStorage.read(key: 'accessToken');
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final token = await _getToken();
    if (token == null || token.isEmpty) {
      if (!mounted) return;
      setState(() {
        _error = 'Please sign in as a lawyer to access this module.';
        _isLoading = false;
      });
      return;
    }

    try {
      final responses = await Future.wait([
        http.get(
          ApiConfig.uri('/api/lawyers/me/profile'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ),
        http.get(
          ApiConfig.uri('/api/lawyers/requests/incoming'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ),
      ]);

      final profileResponse = responses[0];
      final requestsResponse = responses[1];
      final profileBody = profileResponse.body.isNotEmpty
          ? jsonDecode(profileResponse.body)
          : {};
      final requestsBody = requestsResponse.body.isNotEmpty
          ? jsonDecode(requestsResponse.body)
          : {};

      if (profileResponse.statusCode != 200) {
        throw Exception(
          profileBody is Map && profileBody['error'] != null
              ? profileBody['error'].toString()
              : 'Failed to load lawyer profile',
        );
      }

      final profileData = profileBody['data'] as Map<String, dynamic>;
      final requestList = requestsBody is Map && requestsBody['data'] is List
          ? (requestsBody['data'] as List)
              .whereType<Map<String, dynamic>>()
              .map(LawyerRequestData.fromJson)
              .toList()
          : <LawyerRequestData>[];

      if (!mounted) return;

      setState(() {
        _nameController.text = (profileData['name'] ?? '').toString();
        _phoneController.text = (profileData['phone'] ?? '').toString();
        _cityController.text = (profileData['city'] ?? '').toString();
        _experienceController.text =
            (profileData['experience_years'] ?? '').toString();
        _bioController.text = (profileData['bio'] ?? '').toString();
        _email = (profileData['email'] ?? '').toString();
        _status = (profileData['status'] ?? '').toString();
        _isVisible = profileData['is_visible'] == true;
        _selectedSpecializations = (profileData['specialization'] is List)
            ? (profileData['specialization'] as List)
                .map((item) => item.toString())
                .toList()
            : <String>[];
        _requests = requestList;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load lawyer module: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveProfile() async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in again.')),
      );
      return;
    }

    if (_nameController.text.trim().isEmpty ||
        _phoneController.text.trim().isEmpty ||
        _cityController.text.trim().isEmpty ||
        _bioController.text.trim().isEmpty ||
        _experienceController.text.trim().isEmpty ||
        _selectedSpecializations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all public profile fields.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final response = await http.put(
        ApiConfig.uri('/api/lawyers/me/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'name': _nameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'city': _cityController.text.trim(),
          'experience_years': _experienceController.text.trim(),
          'bio': _bioController.text.trim(),
          'specialization': _selectedSpecializations,
          'is_visible': _isVisible,
        }),
      );

      final body = response.body.isNotEmpty ? jsonDecode(response.body) : {};

      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lawyer profile updated successfully.')),
        );
      } else {
        final error = body is Map && body['error'] != null
            ? body['error'].toString()
            : 'Failed to update profile';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error)));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Network error: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _refreshRequests() async {
    final token = await _getToken();
    if (token == null || token.isEmpty) return;

    setState(() => _isRefreshingRequests = true);

    try {
      final response = await http.get(
        ApiConfig.uri('/api/lawyers/requests/incoming'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final body = response.body.isNotEmpty ? jsonDecode(response.body) : {};
      final requestList = body is Map && body['data'] is List
          ? (body['data'] as List)
              .whereType<Map<String, dynamic>>()
              .map(LawyerRequestData.fromJson)
              .toList()
          : <LawyerRequestData>[];

      if (!mounted) return;
      setState(() {
        _requests = requestList;
        _isRefreshingRequests = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isRefreshingRequests = false);
    }
  }

  Future<void> _respondToRequest(String requestId, String status) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in again.')),
      );
      return;
    }

    try {
      final response = await http.post(
        ApiConfig.uri('/api/lawyers/requests/respond'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'requestId': requestId,
          'status': status,
        }),
      );

      final body = response.body.isNotEmpty ? jsonDecode(response.body) : {};

      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() {
          _requests = _requests.map((request) {
            if (request.id == requestId) {
              return request.copyWith(status: status);
            }
            return request;
          }).toList();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Request $status successfully.')),
        );
      } else {
        final error = body is Map && body['error'] != null
            ? body['error'].toString()
            : 'Failed to update request';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error)));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Network error: $e')),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    _experienceController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color darkGreen = Color(0xFF004B23);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lawyer Connect'),
        backgroundColor: darkGreen,
        foregroundColor: Colors.white,
      ),
      body: _buildBody(darkGreen),
    );
  }

  Widget _buildBody(Color darkGreen) {
    if (_isLoading) {
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
              onPressed: _loadDashboard,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
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
                  'Your Public Lawyer Profile',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text('Email: ${_email ?? ''}'),
                const SizedBox(height: 4),
                Text('Status: ${_status ?? ''}'),
                const SizedBox(height: 16),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Full Name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _phoneController,
                  decoration: const InputDecoration(labelText: 'Phone Number'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _cityController,
                  decoration: const InputDecoration(labelText: 'City'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _experienceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Years of Experience'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _bioController,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Professional Bio'),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Specialization',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _specializationOptions.map((item) {
                    final isSelected = _selectedSpecializations.contains(item);
                    return FilterChip(
                      label: Text(item),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedSpecializations.add(item);
                          } else {
                            _selectedSpecializations.remove(item);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  value: _isVisible,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Visible to citizens'),
                  subtitle: const Text(
                    'If disabled, your profile will not appear in Lawyer Connect for users.',
                  ),
                  onChanged: (value) {
                    setState(() => _isVisible = value);
                  },
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveProfile,
                    child: _isSaving
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Save Public Profile'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Incoming Requests',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      onPressed: _isRefreshingRequests ? null : _refreshRequests,
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_requests.isEmpty)
                  const Text('No citizen requests yet.')
                else
                  ..._requests.map((request) => Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(top: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              request.displayName,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text('Email: ${request.email}'),
                            if (request.phone.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text('Phone: ${request.phone}'),
                            ],
                            const SizedBox(height: 8),
                            Text(request.query),
                            const SizedBox(height: 10),
                            Text(
                              'Status: ${request.status.toUpperCase()}',
                              style: TextStyle(
                                color: _statusColor(request.status),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (request.status == 'pending') ...[
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () => _respondToRequest(request.id, 'accepted'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                      ),
                                      child: const Text('Accept'),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () => _respondToRequest(request.id, 'rejected'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.redAccent,
                                      ),
                                      child: const Text('Reject'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.redAccent;
      default:
        return Colors.orange;
    }
  }
}

class LawyerRequestData {
  final String id;
  final String query;
  final String status;
  final String displayName;
  final String email;
  final String phone;

  LawyerRequestData({
    required this.id,
    required this.query,
    required this.status,
    required this.displayName,
    required this.email,
    required this.phone,
  });

  factory LawyerRequestData.fromJson(Map<String, dynamic> json) {
    final user = json['user'] is Map<String, dynamic>
        ? json['user'] as Map<String, dynamic>
        : <String, dynamic>{};
    final profile = user['profile'] is Map<String, dynamic>
        ? user['profile'] as Map<String, dynamic>
        : <String, dynamic>{};

    return LawyerRequestData(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      query: (json['query'] ?? '').toString(),
      status: (json['status'] ?? 'pending').toString(),
      displayName: (profile['display_name'] ?? user['email'] ?? 'Citizen').toString(),
      email: (user['email'] ?? '').toString(),
      phone: (user['phone'] ?? '').toString(),
    );
  }

  LawyerRequestData copyWith({String? status}) {
    return LawyerRequestData(
      id: id,
      query: query,
      status: status ?? this.status,
      displayName: displayName,
      email: email,
      phone: phone,
    );
  }
}
