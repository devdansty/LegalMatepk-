import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/template_models.dart';
import '../services/template_service.dart';
import 'template_form_screen.dart';

class TemplatePreviewScreen extends StatefulWidget {
  final DocumentTemplate template;

  const TemplatePreviewScreen({
    required this.template,
    super.key,
  });

  @override
  State<TemplatePreviewScreen> createState() => _TemplatePreviewScreenState();
}

class _TemplatePreviewScreenState extends State<TemplatePreviewScreen> {
  bool _isDownloading = false;
  late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    _requestNotificationPermission();
  }

  Future<void> _requestNotificationPermission() async {
    if (Platform.isAndroid) {
      final status = await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      debugPrint('Android notification permission: $status');
    }
  }

  void _initializeNotifications() {
    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.payload != null && response.payload!.isNotEmpty) {
          OpenFile.open(response.payload!);
        }
      },
    );
  }

  Future<void> _showDownloadNotification(String filePath, String filename) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'template_downloads',
      'Template Downloads',
      channelDescription: 'Notifications for template file downloads',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
      enableVibration: true,
    );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await flutterLocalNotificationsPlugin.show(
      0,
      'Template Downloaded',
      filename,
      platformChannelSpecifics,
      payload: filePath,
    );
  }

  Future<void> _downloadTemplate() async {
    setState(() {
      _isDownloading = true;
    });

    try {
      // Download the file bytes from backend
      final fileBytes = await TemplateService.downloadOriginalTemplate(
        widget.template.id,
      );

      // Save file to device
      await _saveFile(fileBytes, '${widget.template.slug}.docx');
      
      // Get file path and show notification
      Directory? downloadDir;
      if (Platform.isAndroid) {
        downloadDir = Directory('/storage/emulated/0/Download');
        if (!await downloadDir.exists()) {
          downloadDir = await getExternalStorageDirectory();
        }
      } else if (Platform.isIOS) {
        downloadDir = await getApplicationDocumentsDirectory();
      } else {
        downloadDir = await getDownloadsDirectory();
      }
      
      if (downloadDir != null) {
        final filePath = '${downloadDir.path}/${widget.template.slug}.docx';
        await _showDownloadNotification(filePath, '${widget.template.slug}.docx');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Template downloaded successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isDownloading = false;
      });
    }
  }

  Future<void> _saveFile(List<int> bytes, String filename) async {
    try {
      // Get the downloads directory (or documents directory as fallback)
      Directory? downloadDir;
      
      if (Platform.isAndroid) {
        downloadDir = Directory('/storage/emulated/0/Download');
        if (!await downloadDir.exists()) {
          downloadDir = await getExternalStorageDirectory();
        }
      } else if (Platform.isIOS) {
        downloadDir = await getApplicationDocumentsDirectory();
      } else {
        downloadDir = await getDownloadsDirectory();
      }

      if (downloadDir == null) {
        throw Exception('Could not access downloads directory');
      }

      // Create the file
      final filePath = '${downloadDir.path}/$filename';
      final file = File(filePath);
      
      // Write bytes to file
      await file.writeAsBytes(bytes);
      
      debugPrint('File saved successfully: $filePath');
      debugPrint('File size: ${bytes.length} bytes');
    } catch (e) {
      throw Exception('Failed to save file: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Preview"),
        backgroundColor: const Color(0xFF004B23),
      ),
      body: Column(
        children: [
          // Template Info Header
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF004B23).withOpacity(0.05),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.template.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF004B23),
                  ),
                ),
              ],
            ),
          ),

          // Template Content Preview
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  widget.template.templateContent,
                  style: const TextStyle(
                    fontSize: 13,
                    fontFamily: 'Courier',
                    color: Colors.black87,
                    height: 1.6,
                  ),
                ),
              ),
            ),
          ),

          // Action Buttons
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: Colors.grey[200]!),
              ),
            ),
            child: Column(
              children: [
                // Download Original Template Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isDownloading ? null : _downloadTemplate,
                    icon: _isDownloading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFF004B23),
                              ),
                            ),
                          )
                        : const Icon(Icons.download),
                    label: Text(_isDownloading ? 'Downloading...' : 'Download Template'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Color(0xFF004B23)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Fill Document Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TemplateFormScreen(template: widget.template),
                        ),
                      );
                    },
                    icon: const Icon(Icons.edit_document),
                    label: const Text('Fill Document'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF004B23),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
