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

class _LawyerConnectScreenState extends State<LawyerConnectScreen>
    with TickerProviderStateMixin {
  bool _isLoading = true;
  String? _error;
  List<LawyerCardData> _lawyers = [];
  String _selectedFilter = 'All';
  
  late AnimationController _entranceController;
  late List<Animation<double>> _cardAnimations;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _fetchLawyers();
  }

  void _setupAnimations() {
    _entranceController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _cardAnimations = List.generate(
      10,
      (index) => Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
          parent: _entranceController,
          curve: Interval(
            0.1 + (index * 0.05),
            0.6 + (index * 0.05),
            curve: Curves.easeOut,
          ),
        ),
      ),
    );

    _entranceController.forward();
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
        _entranceController.reset();
        _entranceController.forward();
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
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryGreen = Color(0xFF10300C);
    const Color offWhite = Color(0xFFF8F9F9);
    const Color darkGreen = Color(0xFF004B23);

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
          'Find a Lawyer',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchLawyers,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF10300C),
        ),
      );
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
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10300C),
            ),
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

    return ListView(
      padding: const EdgeInsets.all(0),
      children: [
        // Verified Lawyers Header
        _buildVerifiedLawyersHeader(),
        const SizedBox(height: 20),

        // Filter Tabs
        _buildFilterTabs(),
        const SizedBox(height: 20),

        // Lawyer Cards List
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _lawyers.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final lawyer = _lawyers[index];
              final animation = index < _cardAnimations.length
                  ? _cardAnimations[index]
                  : AlwaysStoppedAnimation<double>(1.0);

              return FadeAndSlideUp(
                animation: animation,
                child: _buildLawyerCard(lawyer, context),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildVerifiedLawyersHeader() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFC8E6C9).withOpacity(0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF10300C).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF10300C).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.verified_user,
              color: Color(0xFF10300C),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Verified Lawyers',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF333333),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'All lawyers are verified by Bar Council',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF10300C),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs() {
    const List<String> filters = ['All', 'Property', 'Family', 'Criminal', 'Civil'];
    const Color primaryGreen = Color(0xFF10300C);

    return SizedBox(
      height: 50,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = _selectedFilter == filter;

          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: GestureDetector(
              onTap: () {
                setState(() => _selectedFilter = filter);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? primaryGreen : Colors.transparent,
                  border: isSelected
                      ? null
                      : Border(
                          bottom: BorderSide(
                            color: primaryGreen,
                            width: 2,
                          ),
                        ),
                  borderRadius: isSelected ? BorderRadius.circular(20) : null,
                ),
                child: Text(
                  filter,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : primaryGreen,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLawyerCard(LawyerCardData lawyer, BuildContext context) {
    const Color primaryGreen = Color(0xFF10300C);

    return ScaleOnTap(
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
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFFE0E0E0),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar + Name + Verified Badge Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar Circle
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: primaryGreen.withOpacity(0.1),
                  ),
                  child: Center(
                    child: Text(
                      lawyer.name.isNotEmpty
                          ? lawyer.name[0].toUpperCase()
                          : 'L',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: primaryGreen,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Name and Verified Badge
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lawyer.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF333333),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: primaryGreen,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'Verified Lawyer',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: primaryGreen,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Specializations Row
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                ...lawyer.specialization.map((spec) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getSpecializationIcon(spec),
                        color: primaryGreen,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        spec,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF666666),
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
            const SizedBox(height: 12),

            // Location and Experience Row
            Row(
              children: [
                Icon(
                  Icons.location_on,
                  color: primaryGreen,
                  size: 14,
                ),
                const SizedBox(width: 4),
                Text(
                  lawyer.city,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF666666),
                  ),
                ),
                const SizedBox(width: 16),
                Icon(
                  Icons.star,
                  color: primaryGreen,
                  size: 14,
                ),
                const SizedBox(width: 4),
                Text(
                  '${lawyer.experienceYears} yrs exp',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF666666),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Bio Description
            Text(
              lawyer.bio,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF666666),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),

            // Connect Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryGreen,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.phone, size: 18, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'Connect with Lawyer',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getSpecializationIcon(String specialization) {
    final spec = specialization.toLowerCase();
    if (spec.contains('property')) return Icons.home;
    if (spec.contains('family')) return Icons.family_restroom;
    if (spec.contains('criminal')) return Icons.gavel;
    if (spec.contains('civil')) return Icons.balance;
    return Icons.description;
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
class ScaleOnTap extends StatefulWidget {
  final VoidCallback? onTap;
  final Widget child;

  const ScaleOnTap({
    required this.onTap,
    required this.child,
    super.key,
  });

  @override
  State<ScaleOnTap> createState() => _ScaleOnTapState();
}

class _ScaleOnTapState extends State<ScaleOnTap>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
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

