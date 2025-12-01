import 'package:flutter/material.dart';
import 'package:gpa_frontend/theme/colors.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'services/api_service.dart'; // Import the new API service
import 'gpa.dart';
import 'grade.dart';
import 'minor.dart';
import 'summary.dart';
import 'export.dart';
import 'notifications.dart';
import 'auth/login_page.dart';
import 'pred_screen.dart';

class StartPage extends StatefulWidget {
  const StartPage({Key? key}) : super(key: key);

  @override
  _StartPageState createState() => _StartPageState();
}

class _StartPageState extends State<StartPage> {
  final storage = FlutterSecureStorage();
  List<SemesterData> semesterData = [];
  double currentSgpa = 0.0;
  double currentCgpa = 0.0;
  double currentMinorGpa = 0.0;
  bool isLoading = true;
  String errorMessage = '';
  String currentSemester = '';
  String userKtuid = ''; // Add a variable to store the KTUID

  @override
  void initState() {
    super.initState();
    _fetchAcademicData();
    _checkIncrementNotification(); // Ensure this is called
  }

  Future<void> _fetchAcademicData() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      final response = await ApiService.getUserData();

      print('Backend Response: ${response.body}'); // Log the response

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['user'] == null) {
          throw Exception('User data is missing in the response');
        }

        setState(() {
          userKtuid = data['user']['ktuid'] ?? 'N/A';
          currentCgpa = data['cgpa']?.toDouble() ?? 0.0;

          final semesters = data['semesters'] as List;
          semesterData = semesters.map((semester) {
            return SemesterData(
              semester['semester'],
              semester['gpa']?.toDouble() ?? 0.0,
              semester['minor_gpa']?.toDouble() ?? 0.0,
            );
          }).toList();

          if (semesters.isNotEmpty) {
            currentSemester = semesters.last['semester']
                .replaceAll('semester_', ''); // Extract numeric value
            currentSgpa = semesters.last['gpa']?.toDouble() ?? 0.0;
            currentMinorGpa = semesters.last['minor_gpa']?.toDouble() ?? 0.0;

            // Debug log for currentSemester
            print('Fetched Current Semester: $currentSemester');
          }
        });
      } else {
        throw Exception('Failed to load data: ${response.statusCode}');
      }
    } catch (e) {
      setState(() => errorMessage = 'Error: ${e.toString()}');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _exportPDF() async {
    try {
      // Log the KTUID being sent
      print('Exporting PDF for KTUID: $userKtuid');

      // Call the export functionality
      await ExportPage().fetchAndGeneratePDF(context, userKtuid);
    } catch (e) {
      // Log any errors that occur
      print('Error occurred while exporting PDF: $e');

      // Show an error message to the user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _checkIncrementNotification() async {
    print('Checking increment notification...'); // Debug log
    try {
      final response = await ApiService.checkIncrementNotification();

      print('Notification API Response: ${response.body}'); // Debug log

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['show_notification'] == true) {
          _showIncrementNotificationDialog(data['message']);
        }
      } else {
        throw Exception('Failed to check notification');
      }
    } catch (e) {
      print('Error in _checkIncrementNotification: $e'); // Debug log
    }
  }

  void _showIncrementNotificationDialog(String message) {
    print('Showing notification dialog with message: $message'); // Debug log
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Semester Increment Notification'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _confirmIncrementNotification();
              },
              child: const Text('Confirm'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _denyIncrementNotification();
              },
              child: const Text('Deny'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmIncrementNotification() async {
    try {
      final response = await ApiService.confirmIncrementNotification();

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notification confirmed!')),
        );

        // Fetch the updated semester from the backend
        final updatedResponse = await ApiService.getUserData();

        if (updatedResponse.statusCode == 200) {
          final updatedData = json.decode(updatedResponse.body);
          final updatedSemester = updatedData['user']['semester'];

          setState(() {
            currentSemester = updatedSemester.replaceAll(
                'semester_', ''); // Update currentSemester
          });

          // Debug log for currentSemester
          print('Updated Current Semester: $currentSemester');

          // Trigger notifications based on the updated semester
          if (currentSemester == '3') {
            print('Triggering minor courses notification...');
            _askMinorCourses(); // Ask about minor courses
          } else if (currentSemester == '4') {
            print('Triggering honor courses notification...');
            _askHonorCourses(); // Ask about honor courses
          } else {
            print(
                'No notifications triggered for currentSemester: $currentSemester');
          }
        } else {
          throw Exception('Failed to fetch updated user data');
        }
      } else {
        throw Exception('Failed to confirm notification');
      }
    } catch (e) {
      print('Error in _confirmIncrementNotification: $e');
    }
  }

  Future<void> _denyIncrementNotification() async {
    try {
      final response = await ApiService.denyIncrementNotification();

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Semester increment denied and reverted!')),
        );
      } else {
        throw Exception('Failed to deny increment');
      }
    } catch (e) {
      print('Error: $e');
    }
  }

  void _askMinorCourses() {
    print('Displaying minor courses dialog...'); // Debug log
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Minor Courses'),
          content: const Text(
              'Are you planning to take minor courses this semester?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _updateMinorStatus(true); // User is taking minor courses
              },
              child: const Text('Yes'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _updateMinorStatus(false); // User is not taking minor courses
              },
              child: const Text('No'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateMinorStatus(bool isMinor) async {
    try {
      final response =
          await ApiService.updateMinorStatus({'is_minor': isMinor});

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(isMinor
                  ? 'Minor courses enabled!'
                  : 'Minor courses disabled!')),
        );
      } else {
        throw Exception('Failed to update minor status');
      }
    } catch (e) {
      print('Error: $e');
    }
  }

  void _askHonorCourses() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Honor Courses'),
          content: const Text(
              'Are you planning to take honor courses this semester?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _updateHonorStatus(true); // User is taking honor courses
              },
              child: const Text('Yes'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _updateHonorStatus(false); // User is not taking honor courses
              },
              child: const Text('No'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateHonorStatus(bool isHonors) async {
    try {
      final response =
          await ApiService.updateHonorStatus({'is_honors': isHonors});

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(isHonors
                  ? 'Honor courses enabled!'
                  : 'Honor courses disabled!')),
        );
      } else {
        throw Exception('Failed to update honor status');
      }
    } catch (e) {
      print('Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.blue, // Primary Blue
      appBar: AppBar(
        title: const Text(
          'Academic Performance',
          style: TextStyle(
            color: AppColors.lightYellow, // Light Pink
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: AppColors.blue, // Primary Blue
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFFDABECA)), // Light Pink
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            color: AppColors.lightYellow, // Light Pink
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => NotificationsPage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            color: AppColors.lightYellow, // Light Pink
            onPressed: () async {
              await storage.delete(key: 'auth_token');
              await storage.delete(key: 'refresh_token');
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => LoginPage()),
              );
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.lightBlue, // Light Pink
              ),
            )
          : errorMessage.isNotEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        errorMessage,
                        style: const TextStyle(
                          color: AppColors.lightBlue, // Light Pink
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _fetchAcademicData,
                        child: const Text('Retry'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.lightBlue, // Light Pink
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildGpaChart(),
                      const SizedBox(height: 16),
                      _buildCurrentSemesterCard(),
                      const SizedBox(height: 16),
                      _buildGpaSummaryCards(),
                      const SizedBox(height: 24),
                      _buildActionButtons(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildGpaChart() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GpaCalculator(), // Use GpaCalculator()
          ),
        );
      },
      child: Card(
        elevation: 2,
        color: AppColors.lightYellow, // Light Yellow
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'GPA Progress',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF00487F), // Primary Blue
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 240,
                child: semesterData.isEmpty
                    ? const Center(
                        child: Text(
                          'No data available',
                          style: TextStyle(color: Color(0xFFF6AE2D)), // Orange
                        ),
                      )
                    : SfCartesianChart(
                        primaryXAxis: CategoryAxis(
                          title: AxisTitle(
                            text: 'Semester',
                            textStyle: const TextStyle(
                              color: AppColors.blue, // Primary Blue
                            ),
                          ),
                          labelRotation: -45,
                          majorGridLines: const MajorGridLines(width: 0),
                        ),
                        primaryYAxis: NumericAxis(
                          minimum: 0,
                          maximum: 10,
                          interval: 1,
                          title: AxisTitle(
                            text: 'GPA',
                            textStyle: const TextStyle(
                              color: AppColors.blue, // Primary Blue
                            ),
                          ),
                          majorGridLines: const MajorGridLines(width: 0),
                        ),
                        plotAreaBorderWidth: 0,
                        tooltipBehavior: TooltipBehavior(enable: true),
                        series: <ChartSeries>[
                          LineSeries<SemesterData, String>(
                            dataSource: semesterData,
                            xValueMapper: (data, _) => data.semesterName,
                            yValueMapper: (data, _) => data.gpa,
                            name: 'GPA',
                            color: AppColors.blue, // Orange
                            width: 3,
                            markerSettings: const MarkerSettings(
                              isVisible: true,
                              shape: DataMarkerType.circle,
                              borderWidth: 2,
                              borderColor: Color(0xFF00487F), // Orange
                            ),
                            dataLabelSettings: const DataLabelSettings(
                              isVisible: true,
                              textStyle: TextStyle(fontSize: 10),
                            ),
                          ),
                        ],
                        legend: Legend(
                          isVisible: true,
                          position: LegendPosition.bottom,
                          textStyle: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF00487F), // Primary Blue
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

  Widget _buildCurrentSemesterCard() {
    return Card(
      elevation: 2,
      color: AppColors.lightYellow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Current Semester',
                style: TextStyle(
                  fontSize: 18,
                  color: Color(0xFF00487F),
                  fontWeight: FontWeight.bold,
                )),
            const SizedBox(height: 12),
            Text(
              currentSemester,
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.lightBlue,
              ),
            ),
            const SizedBox(height: 8),
            Text('SGPA: ${currentSgpa.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.lightBlue,
                  fontWeight: FontWeight.bold,
                )),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => GradeCalculatorPage()),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.lightBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('View Grades',
                    style:
                        TextStyle(fontSize: 16, color: AppColors.lightYellow)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGpaSummaryCards() {
    return Row(
      children: [
        Expanded(
          child: _buildGpaCard('CGPA', currentCgpa, AppColors.lightBlue!),
        ),
        const SizedBox(width: 12),
        Expanded(
          child:
              _buildGpaCard('Minor GPA', currentMinorGpa, AppColors.lightBlue!),
        ),
      ],
    );
  }

  Widget _buildGpaCard(String title, double value, Color color) {
    return Card(
      color: AppColors.lightYellow,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title,
                style: TextStyle(
                  fontSize: 16,
                  color: color,
                  fontWeight: FontWeight.bold,
                )),
            const SizedBox(height: 8),
            Text(value.toStringAsFixed(2),
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: color,
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildActionButton(
            Icons.calculate, 'Minor', AppColors.lightYellow), // Light Pink
        _buildActionButton(Icons.analytics, 'Predict',
            AppColors.lightYellow), // Predict button
        _buildActionButton(
            Icons.summarize, 'Summary', AppColors.lightYellow), // Light Pink
        _buildActionButton(
            Icons.download, 'Export', AppColors.lightYellow), // Light Pink
      ],
    );
  }

  Widget _buildActionButton(IconData icon, String label, Color color) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: IconButton(
            icon: Icon(icon, size: 32, color: color),
            onPressed: () {
              if (label == 'Minor') {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => MinorCalculatorPage()));
              } else if (label == 'Predict') {
                Navigator.push(context,
                    MaterialPageRoute(builder: (context) => StudentDataForm()));
              } else if (label == 'Summary') {
                Navigator.push(context,
                    MaterialPageRoute(builder: (context) => SummaryPage()));
              } else if (label == 'Export') {
                _exportPDF(); // Call the export PDF function
              }
            },
          ),
        ),
        const SizedBox(height: 8),
        Text(label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
            )),
      ],
    );
  }
}

class SemesterData {
  final String semesterName;
  final double gpa;
  final double minorGpa;

  SemesterData(this.semesterName, this.gpa, this.minorGpa);
}
