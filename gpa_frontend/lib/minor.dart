import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:gpa_frontend/theme/colors.dart'; // Import AppColors,
import 'services/api_service.dart';

class MinorCalculatorPage extends StatefulWidget {
  @override
  _MinorCalculatorPageState createState() => _MinorCalculatorPageState();
}

class _MinorCalculatorPageState extends State<MinorCalculatorPage> {
  final FlutterSecureStorage storage = FlutterSecureStorage();
  Map<String, Map<String, Map<String, int>>> _minorBuckets = {};
  Map<String, Map<String, Map<String, int>>> _honorBuckets = {};
  Map<String, TextEditingController> _gradeControllers = {};
  Map<String, double> _sgpaMap = {}; // Store SGPA for each semester
  String _selectedMinorBucket = 'Bucket 1';
  String _selectedHonorBucket = 'Bucket 1';
  Map<String, String> _selectedMinorSubjects = {};
  Map<String, String> _selectedHonorSubjects = {};
  List<String> _grades = ['S', 'A', 'A+', 'B+', 'B', 'C+', 'C', 'D+', 'P', 'F'];
  bool _isMinorStudent = false; // Flag to check if the user is a minor student
  bool _isHonorStudent = false; // Flag to check if the user is an honor student

  @override
  void initState() {
    super.initState();
    _checkMinorStatus();
  }

  Future<void> _checkMinorStatus() async {
    try {
      final response = await ApiService.checkMinorStatus();
      print("Response body: ${response.body}");
      print("Response status code: ${response.statusCode}");

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        setState(() {
          _isMinorStudent = data['is_minor_student'];
          _isHonorStudent = data['is_honor_student'];
          if (_isMinorStudent || _isHonorStudent) {
            _fetchSubjects();
          }
        });
      } else {
        throw Exception('Failed to check minor status: ${response.statusCode}');
      }
    } catch (e) {
      print("Error checking minor status: $e");
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Error'),
            content: Text('Failed to check minor status: $e'),
            actions: <Widget>[
              TextButton(
                child: Text('OK'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
    }
  }

  Future<void> _fetchSubjects() async {
    try {
      final response = await ApiService.getMinorSubjects();

      print("Response status code: ${response.statusCode}");
      print("Response body: ${response.body}");

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        setState(() {
          _minorBuckets =
              (data['Minor'] as Map<String, dynamic>).map((bucket, semesters) {
            return MapEntry(
                bucket,
                (semesters as Map<String, dynamic>).map((semester, subjects) {
                  return MapEntry(
                      semester,
                      (subjects as Map<String, dynamic>)
                          .map((subject, credits) {
                        return MapEntry(subject, credits as int);
                      }));
                }));
          }).cast<String, Map<String, Map<String, int>>>();

          _honorBuckets =
              (data['Honor'] as Map<String, dynamic>).map((bucket, semesters) {
            return MapEntry(
                bucket,
                (semesters as Map<String, dynamic>).map((semester, subjects) {
                  return MapEntry(
                      semester,
                      (subjects as Map<String, dynamic>)
                          .map((subject, credits) {
                        return MapEntry(subject, credits as int);
                      }));
                }));
          }).cast<String, Map<String, Map<String, int>>>();

          // Initialize controllers and fetch saved grades and SGPA
          _minorBuckets[_selectedMinorBucket]?.forEach((semester, subjects) {
            _selectedMinorSubjects[semester] = subjects.keys.first;
            subjects.forEach((subject, credits) {
              _gradeControllers[subject] = TextEditingController(text: 'S');
            });
            _fetchSavedMinorData(semester, 'Minor'); // Fetch saved data
          });

          _honorBuckets[_selectedHonorBucket]?.forEach((semester, subjects) {
            _selectedHonorSubjects[semester] = subjects.keys.first;
            subjects.forEach((subject, credits) {
              _gradeControllers[subject] = TextEditingController(text: 'S');
            });
            _fetchSavedMinorData(semester, 'Honor'); // Fetch saved data
          });
        });
      } else {
        throw Exception('Failed to fetch subjects: ${response.statusCode}');
      }
    } catch (e) {
      print("Error fetching subjects: $e");
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Error'),
            content: Text('Failed to fetch subjects: $e'),
            actions: <Widget>[
              TextButton(
                child: Text('OK'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
    }
  }

  Future<void> _fetchSavedMinorData(String semester, String type) async {
    try {
      final response = await ApiService.getUserData();

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        setState(() {
          for (var semesterData in responseData['semesters']) {
            if (semesterData['semester'] == semester) {
              _sgpaMap[semester] = semesterData['minor_gpa']?.toDouble() ?? 0.0;
              for (var subject in semesterData['subjects']) {
                String subjectName = subject['name'];
                String? grade = subject['grade'];
                if (_gradeControllers.containsKey(subjectName)) {
                  // Update the grade controller with the fetched grade
                  _gradeControllers[subjectName]?.text = grade ?? 'S';
                } else {
                  // Initialize a new controller if it doesn't exist
                  _gradeControllers[subjectName] = TextEditingController(
                    text: grade ?? 'S',
                  );
                }
              }
            }
          }
        });
      } else {
        throw Exception(
            'Failed to fetch saved minor data: ${response.statusCode}');
      }
    } catch (e) {
      print("Error fetching saved minor data: $e");
    }
  }

  Future<void> _calculateNewSgpa(String semester, String type) async {
    try {
      // Get the selected subject and its grade for the selected semester
      final selectedSubject = type == 'Minor'
          ? _selectedMinorSubjects[semester]
          : _selectedHonorSubjects[semester];
      final selectedGrade = _gradeControllers[selectedSubject]?.text ?? 'S';

      if (selectedSubject == null || selectedGrade.isEmpty) {
        throw Exception(
            'No selected subject or grade found for the selected semester');
      }

      final minorGrades = {selectedSubject: selectedGrade};

      final response = await ApiService.calculateMinor({
        'semester': semester,
        'minor_grades': minorGrades,
        'Type': type, // Include the selected type (Minor or Honor)
        'Bucket': type == 'Minor'
            ? _selectedMinorBucket
            : _selectedHonorBucket, // Include the selected bucket
      });

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        setState(() {
          _sgpaMap[semester] = responseData['semester_sgpa'];
        });
      } else {
        throw Exception('Failed to calculate new SGPA: ${response.statusCode}');
      }
    } catch (e) {
      print("Error calculating new SGPA: $e");
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Error'),
            content: Text('Failed to calculate new SGPA: $e'),
            actions: <Widget>[
              TextButton(
                child: Text('OK'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
    }
  }

  String _truncateSubject(String subject) {
    return subject.length > 5 ? '${subject.substring(0, 5)}...' : subject;
  }

  Widget _buildDropdowns(String type) {
    final buckets = type == 'Minor' ? _minorBuckets : _honorBuckets;
    final selectedBucket =
        type == 'Minor' ? _selectedMinorBucket : _selectedHonorBucket;
    final selectedSubjects =
        type == 'Minor' ? _selectedMinorSubjects : _selectedHonorSubjects;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(
          child: DropdownButton<String>(
            value: selectedBucket,
            onChanged: (String? newValue) {
              setState(() {
                if (type == 'Minor') {
                  _selectedMinorBucket = newValue!;
                } else {
                  _selectedHonorBucket = newValue!;
                }
                _fetchSubjects(); // Fetch subjects based on the selected type
              });
            },
            items: buckets.keys.map<DropdownMenuItem<String>>((String bucket) {
              return DropdownMenuItem<String>(
                value: bucket,
                child: Text(
                  bucket,
                  style: TextStyle(
                    color: AppColors.yellow, // Set bucket text color to yellow
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        SizedBox(height: 16),
        SizedBox(
          height: 300,
          child: ListView.builder(
            shrinkWrap: true,
            physics: ClampingScrollPhysics(),
            itemCount: buckets[selectedBucket]?.length ?? 0,
            itemBuilder: (context, index) {
              String semester =
                  buckets[selectedBucket]?.keys.elementAt(index) ?? '';
              String selectedSubject = selectedSubjects[semester] ?? '';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      semester.split('_').last,
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors
                            .yellow, // Set semester text color to yellow
                      ),
                    ),
                    DropdownButton<String>(
                      value: buckets[selectedBucket]?[semester]
                                  ?.containsKey(selectedSubject) ==
                              true
                          ? selectedSubject
                          : null, // Ensure the value exists
                      onChanged: (String? newValue) {
                        setState(() {
                          selectedSubjects[semester] = newValue!;
                          // Automatically calculate SGPA when subject changes
                          _calculateNewSgpa(semester, type);
                        });
                      },
                      items: buckets[selectedBucket]?[semester]
                          ?.keys
                          .map<DropdownMenuItem<String>>((String subject) {
                        return DropdownMenuItem<String>(
                          value: subject,
                          child: Text(
                            _truncateSubject(subject),
                            style: TextStyle(
                              color: AppColors
                                  .yellow, // Set subject text color to yellow
                            ),
                            overflow: TextOverflow.ellipsis, // Handle overflow
                          ),
                        );
                      }).toList(),
                    ),
                    DropdownButton<String>(
                      value: _grades.contains(
                              _gradeControllers[selectedSubject]?.text)
                          ? _gradeControllers[selectedSubject]?.text
                          : null, // Ensure the value exists
                      onChanged: (String? newValue) {
                        setState(() {
                          _gradeControllers[selectedSubject]?.text = newValue!;
                          // Automatically calculate SGPA when grade changes
                          _calculateNewSgpa(semester, type);
                        });
                      },
                      items:
                          _grades.map<DropdownMenuItem<String>>((String grade) {
                        return DropdownMenuItem<String>(
                          value: grade,
                          child: Text(
                            grade,
                            style: TextStyle(
                              color: AppColors
                                  .yellow, // Set grade text color to yellow
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    if (_sgpaMap[semester] != null)
                      Text(
                        'SGPA: ${_sgpaMap[semester]!.toStringAsFixed(2)}',
                        style: TextStyle(
                            color: AppColors.yellow,
                            fontSize: 16), // SGPA text color
                      )
                    else
                      Text(
                        'SGPA: 0.00',
                        style: TextStyle(
                            color: AppColors.yellow,
                            fontSize: 16), // SGPA text color
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Minor Calculator',
          style: TextStyle(
            color: AppColors.yellow, // Yellow
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.blue, // Blue
      ),
      backgroundColor: AppColors.blue, // Light Blue
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: _isMinorStudent || _isHonorStudent
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isMinorStudent) ...[
                      Text(
                        'MINOR',
                        style: TextStyle(
                            fontSize: 18,
                            color: AppColors.yellow,
                            fontWeight: FontWeight.bold),
                      ),
                      _buildDropdowns('Minor'),
                      SizedBox(height: 20),
                    ],
                    if (_isHonorStudent) ...[
                      Text(
                        'HONOR',
                        style: TextStyle(
                            fontSize: 18,
                            color: AppColors.yellow,
                            fontWeight: FontWeight.bold),
                      ),
                      _buildDropdowns('Honor'),
                    ],
                  ],
                )
              : Center(
                  child: Text(
                    "You're not chosen minor/honour course",
                    style: TextStyle(fontSize: 18),
                  ),
                ),
        ),
      ),
    );
  }
}
