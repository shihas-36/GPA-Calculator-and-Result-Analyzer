import 'dart:convert';
import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'services/api_service.dart';

class ExportPage extends StatelessWidget {
  final storage =
      FlutterSecureStorage(); // Added missing storage initialization

  Future<void> fetchAndGeneratePDF(BuildContext context, String ktuid) async {
    try {
      // Fetch GPA data for the specific student from the Django API
      print('Sending POST request to export PDF with KTUID: $ktuid');

      final response = await ApiService.exportGpaData({'ktuid': ktuid});

      // Log the response
      print('Export PDF Response: ${response.statusCode}');
      print('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Generate the PDF
        final pdf = await GPAExporter.generatePDF(data);

        // Save the PDF locally
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/$ktuid-gpa-report.pdf');
        await file.writeAsBytes(pdf);

        // Open the PDF
        await OpenFile.open(file.path);
      } else {
        throw Exception('Failed to fetch data from API: ${response.body}');
      }
    } catch (e) {
      print('Error occurred while exporting PDF: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Export GPA Report'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            // Replace 'exampleKtuid' with the actual KTUID
            fetchAndGeneratePDF(context, 'exampleKtuid');
          },
          child: const Text('Export to PDF'),
        ),
      ),
    );
  }
}

class GPAExporter {
  static Future<List<int>> generatePDF(Map<String, dynamic> data) async {
    final pdf = pw.Document();
    final pageTheme = pw.PageTheme(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.all(1.5 * PdfPageFormat.cm),
    );

    // Add cover page with user information
    pdf.addPage(
      pw.Page(
        pageTheme: pageTheme,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                level: 0,
                child: pw.Text("GPA Report",
                    style: pw.TextStyle(
                        fontSize: 24, fontWeight: pw.FontWeight.bold)),
              ),
              pw.SizedBox(height: 20),
              pw.Text("User Information:",
                  style: pw.TextStyle(
                      fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.Table.fromTextArray(
                data: [
                  ['Name', data['user']['name']],
                  ['Degree', data['user']['degree']],
                  ['Current Semester', data['user']['current_semester']],
                  ['CGPA', data['user']['cgpa']],
                ],
              ),
            ],
          );
        },
      ),
    );

    // Add a separate page for each semester
    for (final semester in data['semesters']) {
      pdf.addPage(
        pw.Page(
          pageTheme: pageTheme,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Header(
                  level: 1,
                  child: pw.Text(
                      "Semester ${semester['semester']} - GPA: ${semester['gpa']}",
                      style: pw.TextStyle(
                          fontSize: 18, fontWeight: pw.FontWeight.bold)),
                ),
                pw.SizedBox(height: 20),
                _buildSubjectTable(semester['subjects']),
              ],
            );
          },
        ),
      );
    }

    return pdf.save();
  }

  static pw.Table _buildSubjectTable(List<dynamic> subjects) {
    final subjectRows = <pw.TableRow>[
      pw.TableRow(
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.all(5),
            child: pw.Text('Subject',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(5),
            child: pw.Text('Credits',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(5),
            child: pw.Text('Grade',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          ),
        ],
      )
    ];

    for (final subject in subjects) {
      subjectRows.add(pw.TableRow(
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.all(5),
            child: pw.Text(subject['name']),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(5),
            child: pw.Text(subject['credits'].toString()),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(5),
            child: pw.Text(subject['grade']),
          ),
        ],
      ));
    }

    return pw.Table(
      border: pw.TableBorder.all(),
      columnWidths: {
        0: pw.FlexColumnWidth(2),
        1: pw.FlexColumnWidth(1),
        2: pw.FlexColumnWidth(1),
      },
      children: subjectRows,
    );
  }
}
