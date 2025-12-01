import 'package:flutter/material.dart';
import 'package:gpa_frontend/theme/colors.dart';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'services/api_service.dart';

class SummaryPage extends StatefulWidget {
  @override
  _SummaryPageState createState() => _SummaryPageState();
}

final FlutterSecureStorage storage = FlutterSecureStorage();

class _SummaryPageState extends State<SummaryPage> {
  Map<String, dynamic>? summaryData; // Initialize as nullable

  @override
  void initState() {
    super.initState();
    fetchSummaryData();
  }

  Future<void> fetchSummaryData() async {
    final response = await ApiService.getSummary();

    if (response.statusCode == 200) {
      setState(() {
        summaryData = json.decode(response.body);
      });
    } else {
      throw Exception('Failed to load summary data');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Summary Page'),
      ),
      body: summaryData == null
          ? Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  SummaryBox(
                    title: 'Best Semester',
                    value: summaryData?['best_semester']?.toString() ?? 'N/A',
                  ),
                  SummaryBox(
                    title: 'Worst Semester',
                    value: summaryData?['worst_semester']?.toString() ?? 'N/A',
                  ),
                  SummaryBox(
                    title: 'Topper Count',
                    value: summaryData?['topper_count']?.toString() ?? 'N/A',
                  ),
                  SummaryBox(
                    title: 'Supply Count',
                    value: summaryData?['supply_count']?.toString() ?? 'N/A',
                  ),
                  SummaryBox(
                    title: 'Yearback Required',
                    value:
                        summaryData?['yearback_required']?.toString() ?? 'N/A',
                  ),
                  SummaryBox(
                    title: 'SGPA Required',
                    value: summaryData?['sgpa_required'] != null
                        ? (summaryData!['sgpa_required'] is double
                            ? summaryData!['sgpa_required'].toStringAsFixed(2)
                            : summaryData!['sgpa_required']
                                .toString()) // Handle both float and string
                        : 'N/A', // Ensure SGPA is formatted correctly
                  ),
                ],
              ),
            ),
    );
  }
}

class SummaryBox extends StatelessWidget {
  final String title;
  final String value;

  SummaryBox({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 8.0),
      padding: EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: AppColors.lightYellow, // Light Yellow
        border: Border.all(color: AppColors.primaryBlue), // Yellow
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18.0,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryBlue, // Blue
              fontFamily: 'Vanilla',
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 18.0,
              color: AppColors.primaryBlue, // Blue
              fontFamily: 'Vanilla',
            ),
          ),
        ],
      ),
    );
  }
}
