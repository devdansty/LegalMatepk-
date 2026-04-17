import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

import 'lawyer_profile_screen.dart';

class LawyerConnectScreen extends StatefulWidget {
  const LawyerConnectScreen({super.key});

  @override
  State<LawyerConnectScreen> createState() => _LawyerConnectScreenState();
}

class _LawyerConnectScreenState extends State<LawyerConnectScreen> {
  bool _isLoading = true;
  String? _error;
  List<LawyerCardData> _lawyers = [];

  @override
  void initState() {
    super.initState();
    _fetchLawyers();
  }

  Future<void> _fetchLawyers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await http
          .get(ApiConfig.uri('/api/lawyers'))
          .timeout(const Duration(seconds: 30));

      final body = response.body.isNotEmpty ? jsonDecode(response.body) : {};

      if (response.statusCode == 200 && body is Map && body['data'] is List) {
        final parsed = (body['data'] as List)
            .whereType<Map<String, dynamic>>()
            .map(LawyerCardData.fromJson)
            .toList();

        if (!mounted) return;
        setState(() {
          _lawyers = parsed;
          _isLoading = false;
        });
        return;
      }

      if (!mounted) return;
      setState(() {
        _error = (body is Map && body['error'] != null)
            ? body['error'].toString()
            : 'Failed to load lawyers';
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Network error: $e';
        _isLoading = false;
      });
    }
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
      body: RefreshIndicator(
        onRefresh: _fetchLawyers,
        child: _buildBody(darkGreen),
      ),
    );
  }

  Widget _buildBody(Color darkGreen) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            _error!,
            style: const TextStyle(color: Colors.red),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _fetchLawyers,
            style: ElevatedButton.styleFrom(backgroundColor: darkGreen),
            child: const Text('Retry'),
          ),
        ],
      );
    }

    if (_lawyers.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: const [
          Text(
            'No active lawyers are available right now.',
            style: TextStyle(fontSize: 16),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _lawyers.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final lawyer = _lawyers[index];

        return InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => LawyerProfileScreen(
                  lawyerId: lawyer.id,
                  initialData: lawyer,
                ),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade300),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                )
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: darkGreen,
                  child: Text(
                    lawyer.name.isNotEmpty ? lawyer.name[0].toUpperCase() : 'L',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lawyer.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        lawyer.specialization.join(', '),
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        lawyer.bio,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'City: ${lawyer.city}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        );
      },
    );
  }
}

class LawyerCardData {
  final String id;
  final String name;
  final List<String> specialization;
  final String city;
  final String bio;
  final int experienceYears;

  LawyerCardData({
    required this.id,
    required this.name,
    required this.specialization,
    required this.city,
    required this.bio,
    required this.experienceYears,
  });

  factory LawyerCardData.fromJson(Map<String, dynamic> json) {
    final rawSpecialization = json['specialization'];
    final specialization = rawSpecialization is List
        ? rawSpecialization.map((e) => e.toString()).toList()
        : <String>[];

    return LawyerCardData(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      specialization: specialization,
      city: (json['city'] ?? '').toString(),
      bio: (json['bio'] ?? '').toString(),
      experienceYears: int.tryParse((json['experience_years'] ?? 0).toString()) ?? 0,
    );
  }
}

