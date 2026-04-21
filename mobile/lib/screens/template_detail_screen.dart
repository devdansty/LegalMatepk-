import 'package:flutter/material.dart';
import '../models/template_models.dart';
import 'template_preview_screen.dart';

class TemplateDetailScreen extends StatefulWidget {
  final DocumentTemplate template;

  const TemplateDetailScreen({
    required this.template,
    super.key,
  });

  @override
  State<TemplateDetailScreen> createState() => _TemplateDetailScreenState();
}

class _TemplateDetailScreenState extends State<TemplateDetailScreen>
    with TickerProviderStateMixin {
  // Color Constants - Accessible to all methods
  static const Color primaryGreen = Color(0xFF10300C);
  static const Color offWhite = Color(0xFFF8F9F9);


  // Animation controllers
  late AnimationController _entranceController;
  late Animation<double> _contentAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    _entranceController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _contentAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );

    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          'Template Details',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: AnimatedBuilder(
          animation: _contentAnimation,
          builder: (context, child) {
            return Opacity(
              opacity: _contentAnimation.value,
              child: Transform.translate(
                offset: Offset(0, 20 * (1 - _contentAnimation.value)),
                child: child,
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Template Title
                Text(
                  widget.template.title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: primaryGreen,
                  ),
                ),
                const SizedBox(height: 8),
                
                // Description Section
                _buildSectionCard(
                  title: 'About This Template',
                  child: Text(
                    widget.template.description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Fields Summary
                _buildSectionCard(
                  title: 'Fields to Fill (${widget.template.fields.length})',
                  child: Column(
                    children: [
                      ..._buildFieldsList(),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                
                // Preview Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TemplatePreviewScreen(template: widget.template),
                        ),
                      );
                    },
                    icon: const Icon(Icons.preview),
                    label: const Text('Preview Template'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: primaryGreen,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 1,
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: child,
          ),
        ),
      ],
    );
  }

  List<Widget> _buildFieldsList() {
    // Group fields by section
    final Map<String?, List<TemplateField>> groupedFields = {};
    
    for (var field in widget.template.fields) {
      final section = field.section ?? 'General';
      if (!groupedFields.containsKey(section)) {
        groupedFields[section] = [];
      }
      groupedFields[section]!.add(field);
    }

    return groupedFields.entries.map((entry) {
      final section = entry.key;
      final fields = entry.value;
      
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (section != null && section != 'General')
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Text(
                section,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF10300C),
                ),
              ),
            ),
          ...fields.map((field) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    field.label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (field.required)
                  const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Text(
                      '*',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          )).toList(),
        ],
      );
    }).toList();
  }
}
