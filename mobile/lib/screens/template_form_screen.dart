import 'package:flutter/material.dart';
import '../models/template_models.dart';
import '../services/template_service.dart';
import 'document_preview_screen.dart';

class TemplateFormScreen extends StatefulWidget {
  final DocumentTemplate template;

  const TemplateFormScreen({
    required this.template,
    super.key,
  });

  @override
  State<TemplateFormScreen> createState() => _TemplateFormScreenState();
}

class _TemplateFormScreenState extends State<TemplateFormScreen> {
  late List<TemplateField> _sortedFields;
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, String> _selectedOptions = {};
  final Map<String, bool> _checkboxValues = {};
  final Map<String, String> _errors = {};

  int _currentFieldIndex = 0;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    // Sort fields by order and group them
    _sortedFields = List.from(widget.template.fields);
    _sortedFields.sort((a, b) => a.order.compareTo(b.order));

    // Initialize controllers
    for (var field in _sortedFields) {
      _controllers[field.name] = TextEditingController();
      if (field.type == 'select' && field.options != null) {
        _selectedOptions[field.name] = field.options!.first;
      }
      if (field.type == 'checkbox') {
        _checkboxValues[field.name] = false;
      }
    }
  }

  bool _validateCurrentField() {
    final field = _sortedFields[_currentFieldIndex];
    final value = _controllers[field.name]?.text ?? '';

    _errors.clear();

    if (field.required && value.isEmpty) {
      _errors[field.name] = '${field.label} is required';
      return false;
    }

    // Type-specific validation
    switch (field.type) {
      case 'email':
        if (value.isNotEmpty &&
            !RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
          _errors[field.name] = 'Please enter a valid email';
          return false;
        }
        break;
      case 'phone':
        if (value.isNotEmpty && !RegExp(r'^[0-9]{10,}').hasMatch(value)) {
          _errors[field.name] = 'Please enter a valid phone number';
          return false;
        }
        break;
      case 'number':
        if (value.isNotEmpty && double.tryParse(value) == null) {
          _errors[field.name] = 'Please enter a valid number';
          return false;
        }
        break;
      case 'date':
        if (value.isNotEmpty) {
          try {
            DateTime.parse(value);
          } catch (e) {
            _errors[field.name] = 'Please enter a valid date (YYYY-MM-DD)';
            return false;
          }
        }
        break;
    }

    return true;
  }

  void _nextField() {
    if (_validateCurrentField()) {
      if (_currentFieldIndex < _sortedFields.length - 1) {
        setState(() {
          _currentFieldIndex++;
        });
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_errors.values.first),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _previousField() {
    if (_currentFieldIndex > 0) {
      setState(() {
        _currentFieldIndex--;
      });
    }
  }

  void _skipField() {
    if (_currentFieldIndex < _sortedFields.length - 1) {
      setState(() {
        _currentFieldIndex++;
      });
    }
  }

  Future<void> _generateDocument() async {
    // Validate all required fields
    bool allValid = true;
    for (var field in _sortedFields) {
      if (field.required) {
        final value = _controllers[field.name]?.text ?? '';
        if (value.isEmpty) {
          _errors[field.name] = '${field.label} is required';
          allValid = false;
        }
      }
    }

    if (!allValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all required fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isGenerating = true;
    });

    try {
      // Collect all field values
      final Map<String, String> fieldValues = {};
      for (var field in _sortedFields) {
        if (field.type == 'checkbox') {
          fieldValues[field.name] =
              (_checkboxValues[field.name] ?? false).toString();
        } else if (field.type == 'select') {
          fieldValues[field.name] = _selectedOptions[field.name] ?? '';
        } else {
          fieldValues[field.name] = _controllers[field.name]?.text ?? '';
        }
      }

      // Generate document - TODO: Implement backend endpoint
      // For now, we'll just navigate to preview with filled content
      final previewContent = TemplateService.replacePlaceholders(
        widget.template.templateContent,
        fieldValues,
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DocumentPreviewScreen(
            template: widget.template,
            filledContent: previewContent,
            fieldValues: fieldValues,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating document: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isGenerating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentField = _sortedFields[_currentFieldIndex];
    final progressPercent =
        (_currentFieldIndex + 1) / _sortedFields.length * 100;

    return WillPopScope(
      onWillPop: () async {
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Fill Document"),
          backgroundColor: const Color(0xFF004B23),
        ),
        body: Column(
          children: [
            // Progress Indicator
            Container(
              padding: const EdgeInsets.all(16),
              color: const Color(0xFF004B23).withOpacity(0.05),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Step ${_currentFieldIndex + 1} of ${_sortedFields.length}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF004B23),
                          ),
                        ),
                      ),
                      Text(
                        '${progressPercent.toStringAsFixed(0)}%',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF004B23),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progressPercent / 100,
                      minHeight: 8,
                      backgroundColor: Colors.grey[300],
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF004B23),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Form Content
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Field Label
                      Text(
                        currentField.label,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF004B23),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Field Description
                      if (currentField.placeholder.isNotEmpty)
                        Text(
                          currentField.placeholder,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      const SizedBox(height: 24),

                      // Input Field Based on Type
                      _buildInputField(currentField),

                      // Error Message
                      if (_errors.containsKey(currentField.name))
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            _errors[currentField.name]!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // Navigation Buttons
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                border: Border(
                  top: BorderSide(color: Colors.grey[200]!),
                ),
              ),
              child: Row(
                children: [
                  // Previous Button
                  if (_currentFieldIndex > 0)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _previousField,
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Previous'),
                      ),
                    )
                  else
                    Expanded(child: Container()),

                  const SizedBox(width: 12),

                  // Skip/Next Button
                  if (_currentFieldIndex < _sortedFields.length - 1) ...[
                    if (!currentField.required)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _skipField,
                          icon: const Icon(Icons.skip_next),
                          label: const Text('Skip'),
                        ),
                      ),
                    const SizedBox(width: 12),
                  ],

                  // Next/Generate Button
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isGenerating
                          ? null
                          : (_currentFieldIndex == _sortedFields.length - 1
                              ? _generateDocument
                              : _nextField),
                      icon: Icon(_currentFieldIndex == _sortedFields.length - 1
                          ? Icons.check
                          : Icons.arrow_forward),
                      label: Text(_currentFieldIndex == _sortedFields.length - 1
                          ? 'Generate'
                          : 'Next'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF004B23),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField(TemplateField field) {
    switch (field.type) {
      case 'textarea':
        return TextField(
          controller: _controllers[field.name],
          maxLines: 5,
          minLines: 3,
          decoration: InputDecoration(
            hintText: field.placeholder,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: const EdgeInsets.all(12),
          ),
        );

      case 'select':
        return DropdownButtonFormField<String>(
          value: _selectedOptions[field.name],
          items: (field.options ?? [])
              .map((opt) => DropdownMenuItem(
                    value: opt,
                    child: Text(opt),
                  ))
              .toList(),
          onChanged: (value) {
            setState(() {
              _selectedOptions[field.name] = value ?? '';
            });
          },
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: const EdgeInsets.all(12),
          ),
        );

      case 'checkbox':
        return CheckboxListTile(
          title: Text(field.label),
          value: _checkboxValues[field.name] ?? false,
          onChanged: (value) {
            setState(() {
              _checkboxValues[field.name] = value ?? false;
            });
          },
          contentPadding: EdgeInsets.zero,
        );

      case 'date':
        return TextField(
          controller: _controllers[field.name],
          readOnly: true,
          onTap: () async {
            final pickedDate = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime(1900),
              lastDate: DateTime(2100),
            );
            if (pickedDate != null) {
              _controllers[field.name]?.text =
                  pickedDate.toString().split(' ')[0];
            }
          },
          decoration: InputDecoration(
            hintText: 'YYYY-MM-DD',
            prefixIcon: const Icon(Icons.calendar_today),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: const EdgeInsets.all(12),
          ),
        );

      case 'number':
        return TextField(
          controller: _controllers[field.name],
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: field.placeholder,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: const EdgeInsets.all(12),
          ),
        );

      case 'email':
        return TextField(
          controller: _controllers[field.name],
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            hintText: field.placeholder,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: const EdgeInsets.all(12),
          ),
        );

      case 'phone':
        return TextField(
          controller: _controllers[field.name],
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            hintText: field.placeholder,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: const EdgeInsets.all(12),
          ),
        );

      default: // text
        return TextField(
          controller: _controllers[field.name],
          decoration: InputDecoration(
            hintText: field.placeholder,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: const EdgeInsets.all(12),
          ),
        );
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }
}
