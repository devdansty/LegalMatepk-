import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/template_models.dart';
import '../config/api_config.dart';

class TemplateService {
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  static String get baseUrl => '${ApiConfig.baseUrl}/api/templates';

  // ============ GET ALL TEMPLATES ============
  static Future<TemplateListResponse> getAllTemplates({
    int page = 1,
    int limit = 10,
    String? category,
    String? search,
  }) async {
    try {
      final queryParameters = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };

      if (category != null && category.isNotEmpty) {
        queryParameters['category'] = category;
      }

      if (search != null && search.isNotEmpty) {
        queryParameters['search'] = search;
      }

      final response = await http.get(
        ApiConfig.uri('/api/templates', queryParameters),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return TemplateListResponse.fromJson(json);
      } else {
        final errorJson = response.body.isNotEmpty ? jsonDecode(response.body) : {};
        final serverMessage =
            (errorJson is Map && errorJson['message'] != null)
                ? errorJson['message'].toString()
                : (errorJson is Map && errorJson['error'] != null)
                    ? errorJson['error'].toString()
                    : 'HTTP ${response.statusCode}';
        throw Exception('Failed to load templates: $serverMessage');
      }
    } catch (e) {
      throw Exception('Error fetching templates: $e');
    }
  }

  // ============ GET SINGLE TEMPLATE BY ID ============
  static Future<DocumentTemplate> getTemplateById(String templateId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/$templateId'));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return DocumentTemplate.fromJson(json['data'] ?? json);
      } else {
        throw Exception('Failed to load template: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching template: $e');
    }
  }

  // ============ GET TEMPLATE BY SLUG ============
  static Future<DocumentTemplate> getTemplateBySlug(String slug) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/slug/$slug'));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return DocumentTemplate.fromJson(json['data'] ?? json);
      } else {
        throw Exception('Failed to load template: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching template: $e');
    }
  }

  // ============ GET CATEGORIES ============
  static Future<List<String>> getCategories() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/categories'));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final categories = json['data'] as List;
        return List<String>.from(categories);
      } else {
        throw Exception('Failed to load categories: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching categories: $e');
    }
  }

  // ============ DOWNLOAD ORIGINAL TEMPLATE ============
  /// Download the original .docx template file without filling
  /// Returns the document as bytes
  static Future<List<int>> downloadOriginalTemplate(String templateId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/$templateId/download-original'),
      );

      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        throw Exception('Failed to download template: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error downloading template: $e');
    }
  }

  // ============ GENERATE DOCUMENT ============
  /// Sends filled form data to backend to generate .docx document
  /// Returns the document as bytes for download
  /// Requires authentication - NOT available for guest users
  static Future<List<int>> generateDocument({
    required String templateId,
    required Map<String, String> fieldValues,
  }) async {
    try {
      // Get auth token and guest status
      final accessToken = await _secureStorage.read(key: 'accessToken');
      final isGuest = await _secureStorage.read(key: 'is_guest');

      // Check if user is guest
      if (isGuest == 'true') {
        throw Exception('This feature is not available for guest users. Please sign up to generate documents.');
      }

      // Check if user is authenticated
      if (accessToken == null || accessToken.isEmpty) {
        throw Exception('Authentication required. Please sign in.');
      }

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      };

      final response = await http.post(
        Uri.parse('$baseUrl/generate'),
        headers: headers,
        body: jsonEncode({
          'templateId': templateId,
          'fieldValues': fieldValues,
        }),
      );

      if (response.statusCode == 200) {
        // Return the document bytes for saving
        return response.bodyBytes;
      } else if (response.statusCode == 403) {
        final errorJson = jsonDecode(response.body);
        final errorMsg = errorJson['error'] ?? 'Access denied';
        throw Exception(errorMsg);
      } else {
        throw Exception('Failed to generate document: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error generating document: $e');
    }
  }

  // ============ REPLACE PLACEHOLDERS IN TEMPLATE ============
  /// Replaces {{placeholder}} with actual values in template content
  static String replacePlaceholders(
    String templateContent,
    Map<String, String> fieldValues,
  ) {
    String result = templateContent;

    fieldValues.forEach((key, value) {
      result = result.replaceAll('{{$key}}', value);
    });

    return result;
  }
}

