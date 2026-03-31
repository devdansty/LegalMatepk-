import 'package:flutter/material.dart';
import '../models/template_models.dart';
import 'template_preview_screen.dart';

class TemplateDetailScreen extends StatelessWidget {
  final DocumentTemplate template;

  const TemplateDetailScreen({
    required this.template,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Template Details"),
        backgroundColor: const Color(0xFF004B23),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Template Title
              Text(
                template.title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF004B23),
                ),
              ),
              const SizedBox(height: 8),
              
              // Description Section
              _buildSectionCard(
                title: 'About This Template',
                child: Text(
                  template.description,
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
                title: 'Fields to Fill (${template.fields.length})',
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
                        builder: (_) => TemplatePreviewScreen(template: template),
                      ),
                    );
                  },
                  icon: const Icon(Icons.preview),
                  label: const Text('Preview Template'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF004B23),
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
            color: Color(0xFF004B23),
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
    
    for (var field in template.fields) {
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
                  color: Color(0xFF004B23),
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
