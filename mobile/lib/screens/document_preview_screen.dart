import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/template_models.dart';
import '../services/template_service.dart';

class DocumentPreviewScreen extends StatefulWidget {
  final DocumentTemplate template;
  final String filledContent;
  final Map<String, String> fieldValues;

  const DocumentPreviewScreen({
    required this.template,
    required this.filledContent,
    required this.fieldValues,
    super.key,
  });

  @override
  State<DocumentPreviewScreen> createState() => _DocumentPreviewScreenState();
}

class _DocumentPreviewScreenState extends State<DocumentPreviewScreen>
    with TickerProviderStateMixin {
  // Animation controllers
  late AnimationController _entranceController;
  late Animation<double> _contentAnimation;

  bool _showFieldValues = false;
  bool _isDownloading = false;
  late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initializeNotifications();
    _requestNotificationPermission();
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
      'document_downloads',
      'Document Downloads',
      channelDescription: 'Notifications for generated document downloads',
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
      1,
      'Document Generated',
      filename,
      platformChannelSpecifics,
      payload: filePath,
    );
  }

  Future<void> _downloadDocument() async {
    setState(() {
      _isDownloading = true;
    });

    try {
      // Call backend to generate .docx file
      final documentBytes = await TemplateService.generateDocument(
        templateId: widget.template.id,
        fieldValues: widget.fieldValues,
      );

      if (documentBytes.isNotEmpty) {
        // Save file to device
        final filePath = await _saveDocumentFile(documentBytes);
        
        // Show notification
        await _showDownloadNotification(filePath, '${widget.template.slug}_filled.docx');
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Document generated successfully! (${(documentBytes.length / 1024).toStringAsFixed(2)} KB)',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
        debugPrint('Document size: ${documentBytes.length} bytes');
      }
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

  Future<String> _saveDocumentFile(List<int> bytes) async {
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

      // Generate filename with timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = '${widget.template.slug}_$timestamp.docx';
      final filePath = '${downloadDir.path}/$filename';
      final file = File(filePath);
      
      // Write bytes to file
      await file.writeAsBytes(bytes);
      
      debugPrint('Document saved successfully: $filePath');
      return filePath;
    } catch (e) {
      throw Exception('Failed to save document: $e');
    }
  }

  void _editDocument() {
    Navigator.pop(context); // Go back to form
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        return true;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9F9),
        appBar: AppBar(
          backgroundColor: const Color(0xFF10300C),
          elevation: 1,
          toolbarHeight: 70,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'Generated Document',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 20,
              color: Colors.white,
            ),
          ),
          actions: [
            // Toggle field values view
            IconButton(
              icon: Icon(_showFieldValues
                  ? Icons.visibility_off
                  : Icons.visibility,
                  color: Colors.white),
              tooltip: _showFieldValues
                  ? 'Hide filled values'
                  : 'Show filled values',
              onPressed: () {
                setState(() {
                  _showFieldValues = !_showFieldValues;
                });
                // Trigger animation on toggle
                _entranceController.reset();
                _entranceController.forward();
              },
            ),
          ],
        ),
        body: Column(
          children: [
            // Document Info
            Container(
              padding: const EdgeInsets.all(16),
              color: const Color(0xFF10300C).withOpacity(0.08),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.template.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF10300C),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Chip(
                        label: Text(widget.template.category),
                        backgroundColor:
                            const Color(0xFF004B23).withOpacity(0.2),
                        labelStyle: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF004B23),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Tabs - Preview / Fields
            Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey[300]!),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Material(
                      color: _showFieldValues ? Colors.transparent : Colors.white,
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _showFieldValues = false;
                          });
                          // Trigger animation on tab switch
                          _entranceController.reset();
                          _entranceController.forward();
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: !_showFieldValues
                                    ? const Color(0xFF004B23)
                                    : Colors.transparent,
                                width: 3,
                              ),
                            ),
                          ),
                          child: const Text(
                            'Document Preview',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Material(
                      color: _showFieldValues ? Colors.transparent : Colors.white,
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _showFieldValues = true;
                          });
                          // Trigger animation on tab switch
                          _entranceController.reset();
                          _entranceController.forward();
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: _showFieldValues
                                    ? const Color(0xFF004B23)
                                    : Colors.transparent,
                                width: 3,
                              ),
                            ),
                          ),
                          child: const Text(
                            'Filled Values',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
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
                    child: _showFieldValues
                        ? _buildFieldValuesList()
                        : _buildPreviewContent(),
                  ),
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              top: BorderSide(color: Colors.grey[200]!),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isDownloading ? null : _editDocument,
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isDownloading ? null : _downloadDocument,
                  icon: _isDownloading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Icon(Icons.download),
                  label: Text(_isDownloading ? 'Generating...' : 'Download'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF004B23),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewContent() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SelectableText(
        widget.filledContent,
        style: const TextStyle(
          fontSize: 13,
          fontFamily: 'Courier',
          color: Colors.black87,
          height: 1.6,
        ),
      ),
    );
  }

  Widget _buildFieldValuesList() {
    final entries = widget.fieldValues.entries.toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: entries.asMap().entries.map((entry) {
        final index = entry.key;
        final mapEntry = entry.value;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (index > 0) const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mapEntry.key,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF004B23),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    mapEntry.value.isNotEmpty
                        ? mapEntry.value
                        : '(empty)',
                    style: TextStyle(
                      fontSize: 13,
                      color: mapEntry.value.isEmpty
                          ? Colors.grey[500]
                          : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}
