// Models for Document Generator Template System

class DocumentTemplate {
  final String id;
  final String title;
  final String slug;
  final String category;
  final String? subcategory;
  final String language;
  final String description;
  final List<String> tags;
  final List<TemplateField> fields;
  final String templateContent;
  final String version;
  final bool isActive;

  DocumentTemplate({
    required this.id,
    required this.title,
    required this.slug,
    required this.category,
    this.subcategory,
    required this.language,
    required this.description,
    required this.tags,
    required this.fields,
    required this.templateContent,
    required this.version,
    required this.isActive,
  });

  factory DocumentTemplate.fromJson(Map<String, dynamic> json) {
    final rawFields = json['fields'];
    final parsedFields = rawFields is List
        ? rawFields
            .whereType<Map>()
            .map((f) => DocumentTemplate._normalizeMap(f))
            .map((f) => TemplateField.fromJson(f))
            .toList()
        : <TemplateField>[];

    return DocumentTemplate(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      slug: (json['slug'] ?? '').toString(),
      category: (json['category'] ?? '').toString(),
      subcategory: json['subcategory']?.toString(),
      language: (json['language'] ?? 'en').toString(),
      description: (json['description'] ?? '').toString(),
      tags: (json['tags'] is List)
          ? (json['tags'] as List).map((t) => t.toString()).toList()
          : <String>[],
      fields: parsedFields,
      templateContent: (json['templateContent'] ?? '').toString(),
      version: (json['version'] ?? '1.0').toString(),
      isActive: json['isActive'] ?? true,
    );
  }

  static Map<String, dynamic> _normalizeMap(Map source) {
    return source.map((key, value) => MapEntry(key.toString(), value));
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'title': title,
      'slug': slug,
      'category': category,
      'subcategory': subcategory,
      'language': language,
      'description': description,
      'tags': tags,
      'fields': fields.map((f) => f.toJson()).toList(),
      'templateContent': templateContent,
      'version': version,
      'isActive': isActive,
    };
  }
}

class TemplateField {
  final String name;
  final String label;
  final String type; // text, textarea, number, date, email, phone, select, checkbox
  final String placeholder;
  final bool required;
  final List<String>? options; // For select type
  final int order;
  final String? section; // Optional: group fields by section

  TemplateField({
    required this.name,
    required this.label,
    required this.type,
    required this.placeholder,
    required this.required,
    this.options,
    required this.order,
    this.section,
  });

  factory TemplateField.fromJson(Map<String, dynamic> json) {
    return TemplateField(
      name: (json['name'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
      type: (json['type'] ?? 'text').toString(),
      placeholder: (json['placeholder'] ?? '').toString(),
      required: json['required'] ?? false,
      options: json['options'] is List
          ? (json['options'] as List).map((o) => o.toString()).toList()
          : null,
      order: json['order'] ?? 0,
      section: json['section']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'label': label,
      'type': type,
      'placeholder': placeholder,
      'required': required,
      'options': options,
      'order': order,
      'section': section,
    };
  }
}

class TemplateListResponse {
  final List<DocumentTemplate> templates;
  final int total;
  final int page;
  final int limit;

  TemplateListResponse({
    required this.templates,
    required this.total,
    required this.page,
    required this.limit,
  });

  factory TemplateListResponse.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    final parsedTemplates = rawData is List
      ? rawData
        .whereType<Map>()
        .map((t) => DocumentTemplate._normalizeMap(t))
        .map((t) => DocumentTemplate.fromJson(t))
        .toList()
      : <DocumentTemplate>[];

    final pagination = json['pagination'];
    final pageFromPagination =
      pagination is Map ? int.tryParse('${pagination['page']}') : null;
    final limitFromPagination =
      pagination is Map ? int.tryParse('${pagination['limit']}') : null;
    final totalFromPagination =
      pagination is Map ? int.tryParse('${pagination['total']}') : null;

    return TemplateListResponse(
      templates: parsedTemplates,
      total: totalFromPagination ?? int.tryParse('${json['total']}') ?? 0,
      page: pageFromPagination ?? int.tryParse('${json['page']}') ?? 1,
      limit: limitFromPagination ?? int.tryParse('${json['limit']}') ?? 10,
    );
  }
}

class FilledDocument {
  final String templateId;
  final String templateTitle;
  final Map<String, String> fieldValues;

  FilledDocument({
    required this.templateId,
    required this.templateTitle,
    required this.fieldValues,
  });

  factory FilledDocument.fromJson(Map<String, dynamic> json) {
    return FilledDocument(
      templateId: json['templateId'] ?? '',
      templateTitle: json['templateTitle'] ?? '',
      fieldValues: Map<String, String>.from(json['fieldValues'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'templateId': templateId,
      'templateTitle': templateTitle,
      'fieldValues': fieldValues,
    };
  }
}
