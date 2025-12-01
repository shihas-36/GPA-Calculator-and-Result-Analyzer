import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'auth/login_page.dart'; // Import the LoginPage
import 'theme/colors.dart'; // Import AppColors
import 'services/api_service.dart';

class AdminDashboardPage extends StatefulWidget {
  @override
  _AdminDashboardPageState createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final storage = FlutterSecureStorage();
  final _notificationFormKey = GlobalKey<FormState>();
  final _headerController = TextEditingController();
  final _contentController = TextEditingController();
  bool _isLoading = false;
  String _operationResult = '';
  int _updatedStudents = 0;

  Future<void> _incrementSemesters() async {
    setState(() {
      _isLoading = true;
      _operationResult = '';
      _updatedStudents = 0;
    });

    try {
      final response = await ApiService.incrementSemester();

      final data = json.decode(response.body);
      if (response.statusCode == 200) {
        setState(() {
          _updatedStudents = data['updated_count'];
          _operationResult =
              'Successfully incremented semesters for $_updatedStudents students';
        });
      } else {
        setState(() {
          _operationResult = 'Error: ${data['error']}';
        });
      }
    } catch (e) {
      setState(() {
        _operationResult = 'Error: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _sendNotification() async {
    if (!_notificationFormKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _operationResult = '';
    });

    try {
      final response = await ApiService.sendNotification({
        'header': _headerController.text,
        'content': _contentController.text,
      });

      final data = json.decode(response.body);
      if (response.statusCode == 200) {
        setState(() {
          _operationResult =
              'Notification sent successfully to ${data['message'].split(' ')[3]} users';
          _headerController.clear();
          _contentController.clear();
        });
      } else {
        setState(() {
          _operationResult = 'Error: ${data['error']}';
        });
      }
    } catch (e) {
      setState(() {
        _operationResult = 'Error: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _headerController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.blue, // Updated background color
      appBar: AppBar(
        title: const Text(
          'Admin Dashboard',
          style: TextStyle(color: AppColors.lightYellow), // Updated text color
        ),
        backgroundColor: AppColors.blue, // Updated AppBar background color
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            color: AppColors.lightYellow, // Updated icon color
            onPressed: () async {
              // Clear stored tokens
              await storage.delete(key: 'auth_token');
              await storage.delete(key: 'refresh_token');

              // Navigate back to LoginPage
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => LoginPage()),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Semester Increment Section
            Card(
              elevation: 4,
              color: AppColors.lightYellow, // Updated card background color
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Icon(Icons.school,
                        size: 50, color: AppColors.blue), // Updated icon color
                    const SizedBox(height: 16),
                    const Text(
                      'Semester Management',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.blue, // Updated text color
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Increment all students\' semester by 1 (except those in semester 8)',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.blue, // Updated text color
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.blue, // Updated button color
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: _isLoading ? null : _incrementSemesters,
                      child: const Text(
                        'Increment Semesters',
                        style: TextStyle(
                            fontSize: 16,
                            color: AppColors.lightYellow), // Updated text color
                      ),
                    ),
                    if (_updatedStudents > 0) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Updated $_updatedStudents students',
                        style: const TextStyle(
                          color: AppColors.yellow, // Updated text color
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Notification Section
            Card(
              elevation: 4,
              color: AppColors.lightYellow, // Updated card background color
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _notificationFormKey,
                  child: Column(
                    children: [
                      const Icon(Icons.notifications_active,
                          size: 50,
                          color: AppColors.blue), // Updated icon color
                      const SizedBox(height: 16),
                      const Text(
                        'Send Notification',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.blue, // Updated text color
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _headerController,
                        decoration: const InputDecoration(
                          labelText: 'Notification Header',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 14,
                          ),
                        ),
                        style: const TextStyle(fontSize: 14),
                        validator: (value) =>
                            value!.isEmpty ? 'Header is required' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _contentController,
                        decoration: const InputDecoration(
                          labelText: 'Notification Content',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 14,
                          ),
                        ),
                        maxLines: 4,
                        style: const TextStyle(fontSize: 14),
                        validator: (value) =>
                            value!.isEmpty ? 'Content is required' : null,
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              AppColors.blue, // Updated button color
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: _isLoading ? null : _sendNotification,
                        child: const Text(
                          'Send Notification',
                          style: TextStyle(
                              fontSize: 16,
                              color:
                                  AppColors.lightYellow), // Updated text color
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Operation Result
            if (_operationResult.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _operationResult.contains('Error')
                      ? Colors.red[50]
                      : Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _operationResult,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _operationResult.contains('Error')
                        ? Colors.red[800]
                        : Colors.green[800],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: CircularProgressIndicator(
                    color: AppColors.blue, // Updated color
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
