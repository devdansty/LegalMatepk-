import 'package:flutter/material.dart';
import '../models/template_models.dart';
import '../services/template_service.dart';
import 'template_detail_screen.dart';

class DocumentAutomationScreen extends StatefulWidget {
  const DocumentAutomationScreen({super.key});

  @override
  State<DocumentAutomationScreen> createState() =>
      _DocumentAutomationScreenState();
}

class _DocumentAutomationScreenState extends State<DocumentAutomationScreen> {
  final TextEditingController _searchController = TextEditingController();
  
  List<DocumentTemplate> _allTemplates = [];
  List<DocumentTemplate> _filteredTemplates = [];
  List<String> _categories = [];
  
  String? _selectedCategory;
  bool _isLoading = true;
  String _errorMessage = '';
  
  int _currentPage = 1;
  final int _pageSize = 10;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
    _loadCategories();
  }

  Future<void> _loadTemplates({String? category}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await TemplateService.getAllTemplates(
        page: _currentPage,
        limit: _pageSize,
        category: category,
      );

      setState(() {
        _allTemplates = response.templates;
        _filteredTemplates = response.templates;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await TemplateService.getCategories();
      setState(() {
        _categories = categories;
      });
    } catch (e) {
      debugPrint('Error loading categories: $e');
    }
  }

  void _filterTemplates(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredTemplates = _allTemplates;
      });
    } else {
      setState(() {
        _filteredTemplates = _allTemplates
            .where((template) =>
                template.title.toLowerCase().contains(query.toLowerCase()) ||
                template.description
                    .toLowerCase()
                    .contains(query.toLowerCase()) ||
                template.tags.any((tag) =>
                    tag.toLowerCase().contains(query.toLowerCase())))
            .toList();
      });
    }
  }

  void _onCategoryChanged(String? category) {
    setState(() {
      _selectedCategory = category;
      _currentPage = 1;
    });
    _loadTemplates(category: category);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Document Generator"),
        backgroundColor: const Color(0xFF004B23),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search and Filter Section
          Container(
            color: const Color(0xFF004B23).withOpacity(0.1),
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Search Bar
                TextField(
                  controller: _searchController,
                  onChanged: _filterTemplates,
                  decoration: InputDecoration(
                    hintText: 'Search templates...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _filterTemplates('');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Category Filter
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _buildCategoryChip(
                        label: 'All',
                        isSelected: _selectedCategory == null,
                        onTap: () => _onCategoryChanged(null),
                      ),
                      ..._categories.map(
                        (category) => _buildCategoryChip(
                          label: category,
                          isSelected: _selectedCategory == category,
                          onTap: () => _onCategoryChanged(category),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Templates List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage.isNotEmpty
                    ? _buildErrorWidget(_errorMessage)
                    : _filteredTemplates.isEmpty
                        ? _buildEmptyWidget()
                        : _buildTemplatesList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => onTap(),
        selectedColor: const Color(0xFF004B23),
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.black,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildTemplatesList() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _filteredTemplates.length,
      itemBuilder: (context, index) {
        final template = _filteredTemplates[index];
        return _buildTemplateCard(template);
      },
    );
  }

  Widget _buildTemplateCard(DocumentTemplate template) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TemplateDetailScreen(template: template),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Text(
                template.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF004B23),
                ),
              ),
              const SizedBox(height: 8),
              // Description
              Text(
                template.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 12),
              // Meta Info Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Category and Subcategory
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Chip(
                          label: Text(template.category),
                          backgroundColor:
                              const Color(0xFF004B23).withOpacity(0.2),
                          labelStyle: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF004B23),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],            
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.description_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No templates found',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your search or filters',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Error loading templates',
            style: TextStyle(
              fontSize: 18,
              color: Colors.red[600],
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              _loadTemplates(category: _selectedCategory);
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF004B23),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}