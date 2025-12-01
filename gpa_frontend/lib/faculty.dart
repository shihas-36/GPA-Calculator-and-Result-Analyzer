import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:gpa_frontend/auth/login_page.dart';
import 'Theme/colors.dart'; // Import AppColors
import 'package:gpa_frontend/export.dart'; // Import the existing export package
import 'services/api_service.dart';

class FacultyService {
  final storage = FlutterSecureStorage();

  Future<List<Map<String, dynamic>>> fetchStudentsByFaculty() async {
    try {
      print('Sending GET request to fetch students by faculty');
      final response = await ApiService.fetchStudentsByFaculty();

      // Log the response
      print('Fetch Students Response: ${response.statusCode}');
      print('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is! Map || !data.containsKey('students')) {
          throw Exception('Unexpected response format');
        }
        return List<Map<String, dynamic>>.from(data['students'].map((student) {
          return {
            'name': student['name'] ?? 'No Name',
            'KTUID': student['KTUID'] ?? 'N/A',
            'degree': student['degree'] ?? 'Not Specified',
            'semester': student['semester']?.toString() ?? '0',
            'cgpa': student['cgpa']?.toString() ?? '0.0',
          };
        }).toList());
      } else {
        throw Exception('Failed to fetch students: ${response.body}');
      }
    } catch (e) {
      print('Error occurred while fetching students: $e');
      throw Exception('Error occurred while fetching students: $e');
    }
  }

  Future<void> fetchAndGeneratePDF(BuildContext context, String ktuid) async {
    print('fetchAndGeneratePDF method called'); // Add this
    try {
      print('Sending POST request to export PDF with KTUID: $ktuid');
      final response = await ApiService.exportGpaData({'ktuid': ktuid});

      // Log the response
      print('Export PDF Response: ${response.statusCode}');
      print('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final pdfBytes = response.bodyBytes;

        // Save the PDF locally
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/$ktuid-gpa-report.pdf');
        await file.writeAsBytes(pdfBytes);

        // Open the PDF
        await OpenFile.open(file.path);
      } else {
        throw Exception('Failed to export PDF: ${response.body}');
      }
    } catch (e) {
      print('Error occurred while exporting PDF: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }
}

class FacultyPage extends StatelessWidget {
  final FacultyService facultyService = FacultyService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Faculty Dashboard'),
        backgroundColor: AppColors.blue, // Use AppColors for AppBar
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              // Clear stored tokens
              final storage = FlutterSecureStorage();
              await storage.delete(key: 'auth_token');
              await storage.delete(key: 'refresh_token');

              // Navigate to the correct page
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => LoginPage()),
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: facultyService.fetchStudentsByFaculty(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No students found.'));
          } else {
            final students = snapshot.data!;
            return ListView.builder(
              itemCount: students.length,
              itemBuilder: (context, index) {
                final student = students[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  child: Card(
                    color: AppColors.yellow,
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            student['name'],
                            style: const TextStyle(
                              fontSize: 18,
                              color: AppColors.lightYellow,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text('Reg No: ${student['KTUID'] ?? 'N/A'}'),
                          Text('Degree: ${student['degree'] ?? 'Unknown'}'),
                          Text('Semester: ${student['semester'] ?? ''}'),
                          Text('CGPA: ${student['cgpa'] ?? ''}'),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                try {
                                  await ExportPage().fetchAndGeneratePDF(
                                    context,
                                    student['KTUID'] ?? 'N/A',
                                  );
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error: $e')),
                                  );
                                }
                              },
                              icon: const Icon(Icons.download),
                              label: const Text('Download PDF'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.blue,
                                foregroundColor: AppColors.lightYellow,
                                // Use AppColors for AppBar,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          }
        },
      ),
    );
  }
}
