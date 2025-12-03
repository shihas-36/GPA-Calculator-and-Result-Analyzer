import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:gpa_frontend/theme/colors.dart';
import 'dart:convert';
import 'dart:collection';
import 'services/api_service.dart';

class GradeCalculatorPage extends StatefulWidget {
  @override
  _GradeCalculatorPageState createState() => _GradeCalculatorPageState();
}

class _GradeCalculatorPageState extends State<GradeCalculatorPage> {
  final storage = FlutterSecureStorage();
  String? _currentSemesterKey;
  Map<String, Map<String, Map<String, int>>> subjectsStructure = {};
  Map<String, Map<String, String?>> selectedSubjects = {};
  Map<String, Map<String, String?>> selectedGrades = {};
  Map<String, Map<String, String?>> gradeResults =
      {}; // semester -> subject -> grade
  bool isLoading = true;
  String? errorMessage;
  final Map<String, int> gradeValues = {
    'A+': 10,
    'A': 9,
    'B+': 8,
    'B': 7,
    'C': 6,
    'D': 5,
    'F': 0,
  };

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _loadSavedGrades(String semesterKey) async {
    try {
      final response = await ApiService.getUserData();
      if (response.statusCode != 200) return;
      final data = json.decode(response.body) as Map<String, dynamic>;
      final semesters = data['semesters'] as List<dynamic>?;
      if (semesters == null) return;

      // Find matching semester entry
      final matched = semesters.firstWhere(
          (s) => (s['semester'] as String) == semesterKey,
          orElse: () => null);
      if (matched == null) return;

      final subjectList = (matched['subjects'] as List<dynamic>?) ?? [];

      setState(() {
        gradeResults[semesterKey] = {};
        for (var subj in subjectList) {
          final name = subj['name'] as String?;
          final grade = subj['grade'] as String?;
          if (name != null) {
            gradeResults[semesterKey]![name] =
                (grade == null || grade == 'N/A') ? null : grade;
          }
        }
      });
    } catch (e) {
      // ignore load errors silently
      print('Error loading saved grades: $e');
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _initializeData() async {
    try {
      print('DEBUG: Starting _initializeData()');
      await fetchSubjects();
      print('DEBUG: fetchSubjects() completed');
      print(
          'DEBUG: subjectsStructure keys: ${subjectsStructure.keys.toList()}');

      // Get current user semester from API
      print('DEBUG: Fetching user data...');
      final userResponse = await ApiService.getUserData();
      print('DEBUG: User data response status: ${userResponse.statusCode}');

      if (userResponse.statusCode == 200) {
        final userData = json.decode(userResponse.body);
        print('DEBUG: User data: $userData');
        final currentUserSemester = userData['user']['semester'];
        print('DEBUG: Current user semester from API: $currentUserSemester');
        final semesterKey = 'semester_$currentUserSemester';
        print('DEBUG: Generated semester key: $semesterKey');

        // Use the user's current semester if it exists in subjects structure
        if (subjectsStructure.containsKey(semesterKey)) {
          _currentSemesterKey = semesterKey;
          print('DEBUG: Using user semester: $_currentSemesterKey');
        } else if (subjectsStructure.isNotEmpty) {
          // Fallback to first available semester
          _currentSemesterKey = subjectsStructure.keys.first;
          print('DEBUG: Fallback to first semester: $_currentSemesterKey');
        } else {
          _currentSemesterKey = null;
          print('DEBUG: No semesters available, setting to null');
        }
      } else {
        print('DEBUG: Failed to get user data, using fallback logic');
        // Fallback to saved semester or last available
        final savedSemester = await storage.read(key: 'current_semester');
        print('DEBUG: Saved semester from storage: $savedSemester');
        if (savedSemester != null &&
            subjectsStructure.containsKey(savedSemester)) {
          _currentSemesterKey = savedSemester;
          print('DEBUG: Using saved semester: $_currentSemesterKey');
        } else if (subjectsStructure.isNotEmpty) {
          _currentSemesterKey = subjectsStructure.keys.first;
          print('DEBUG: Fallback to first available: $_currentSemesterKey');
        } else {
          _currentSemesterKey = null;
          print('DEBUG: No semesters available in fallback');
        }
      }

      print('DEBUG: Final _currentSemesterKey: $_currentSemesterKey');

      // Load any previously saved grades for the current semester
      if (_currentSemesterKey != null) {
        print('DEBUG: Loading saved grades for: $_currentSemesterKey');
        await _loadSavedGrades(_currentSemesterKey!);
      }

      print('DEBUG: _initializeData() completed successfully');
    } catch (e) {
      print('DEBUG: Error in _initializeData(): $e');
      setState(() {
        errorMessage = 'Initialization error: $e';
        isLoading = false;
      });
    }
  }

  Future<void> fetchSubjects() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      print('DEBUG: Calling ApiService.getSubjects()...');
      final response = await ApiService.getSubjects();
      print('DEBUG: getSubjects() response status: ${response.statusCode}');
      print('DEBUG: getSubjects() response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        print('DEBUG: Parsed subjects data: $data');

        final parsedData = data.map<String, Map<String, Map<String, int>>>(
            (semesterKey, semesterValue) {
          print('DEBUG: Processing semester: $semesterKey');
          final slots = (semesterValue as Map<String, dynamic>)
              .map<String, Map<String, int>>((slotKey, slotValue) {
            print('DEBUG: Processing slot: $slotKey');
            // Deduplicate courses
            final courses =
                (slotValue as Map<String, dynamic>).map<String, int>(
              (subject, credit) => MapEntry(subject, (credit as num).toInt()),
            );

            return MapEntry(
                slotKey,
                LinkedHashMap.fromEntries(
                    courses.entries.toSet().toList())); // Remove duplicates
          });
          return MapEntry(semesterKey, slots);
        });

        print('DEBUG: Final parsed data: $parsedData');

        setState(() {
          subjectsStructure = parsedData;
          selectedSubjects = {};
          selectedGrades = {};

          // Initialize with first subject in each slot
          parsedData.forEach((semester, slots) {
            selectedSubjects[semester] = {};
            selectedGrades[semester] = {};
            slots.forEach((slot, courses) {
              if (courses.isNotEmpty) {
                selectedSubjects[semester]![slot] = courses.keys.first;
              }
            });
          });
        });

        print(
            'DEBUG: subjectsStructure after setState: ${subjectsStructure.keys.toList()}');
      } else {
        throw Exception('Failed to load subjects: ${response.statusCode}');
      }
    } catch (e) {
      print('DEBUG: Error in fetchSubjects(): $e');
      setState(() {
        errorMessage = 'Error fetching subjects: $e';
      });
      _showErrorDialog('Failed to fetch subjects: $e');
    } finally {
      setState(() => isLoading = false);
      print('DEBUG: fetchSubjects() completed, isLoading = false');
    }
  }

  void _showMarksDialog(String subject, String semester) {
    final TextEditingController internalController =
        TextEditingController(text: '0');
    final TextEditingController universityController =
        TextEditingController(text: '0');
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Enter Marks for $subject'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: internalController,
                    decoration: InputDecoration(labelText: 'Internal Marks'),
                    keyboardType: TextInputType.number,
                  ),
                  TextField(
                    controller: universityController,
                    decoration: InputDecoration(labelText: 'University Marks'),
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
              actions: [
                if (isSubmitting)
                  CircularProgressIndicator()
                else
                  TextButton(
                    onPressed: () async {
                      final internal =
                          double.tryParse(internalController.text) ?? 0;
                      final university =
                          double.tryParse(universityController.text) ?? 0;
                      final total = internal + university;

                      setState(() => isSubmitting = true);

                      try {
                        final response = await ApiService.calculateGrade({
                          'marks': total,
                          'subject': subject, // Include subject
                          'semester': semester // Include semester
                        });

                        if (response.statusCode == 200) {
                          final result = json.decode(response.body);
                          Navigator.of(context).pop();
                          _showGradeResultDialog(
                              subject, result['grade'], semester);
                        } else {
                          throw Exception(
                              'Grade calculation failed: ${response.statusCode}');
                        }
                      } catch (e) {
                        _showErrorDialog('Grade calculation failed: $e');
                      } finally {
                        setState(() => isSubmitting = false);
                      }
                    },
                    child: Text('Calculate Grade'),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  void _showGradeResultDialog(String subject, String grade, String semester) {
    setState(() {
      gradeResults[semester] ??= {};
      gradeResults[semester]![subject] = grade;
    });

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Grade Result'),
          content: Text('$subject: $grade'),
          actions: [
            TextButton(
              child: Text('OK'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Error'),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: Text('OK'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCourseCard(
      String semester, String slot, Map<String, int> courses) {
    final currentSubject = selectedSubjects[semester]?[slot];
    final validSubject = courses.containsKey(currentSubject)
        ? currentSubject
        : (courses.isNotEmpty ? courses.keys.first : null);

    // Get the current grade for the valid subject
    final currentGrade =
        (validSubject != null && gradeResults[semester] != null)
            ? gradeResults[semester]![validSubject]
            : null;

    return Container(
      margin: EdgeInsets.symmetric(vertical: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.lightBlue,
            AppColors.primaryBlue,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: AppColors.lightYellow),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 2,
            blurRadius: 5,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: courses.isEmpty
                ? Text(
                    'No courses available',
                    style: TextStyle(color: Colors.black, fontSize: 16),
                  )
                : DropdownButton<String>(
                    value: validSubject,
                    isExpanded: true,
                    underline: Container(),
                    style: TextStyle(fontSize: 16, color: Colors.black),
                    items: [
                      ...Set.from(courses.keys).map((course) {
                        return DropdownMenuItem<String>(
                          value: course,
                          child: Text(course),
                        );
                      }),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        selectedSubjects[semester] ??= {};

                        final prev = selectedSubjects[semester]![slot];
                        if (prev != null) {
                          gradeResults[semester]?.remove(prev);
                        }

                        selectedSubjects[semester]![slot] = value;
                      });
                    },
                  ),
          ),
          if (validSubject != null)
            GestureDetector(
              onTap: () => _showMarksDialog(validSubject, semester),
              child: Container(
                width: 80,
                height: 40,
                margin: EdgeInsets.only(left: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: AppColors.lightYellow),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      spreadRadius: 2,
                      blurRadius: 5,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    currentGrade ?? 'Enter Marks',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSemesterView(String semester) {
    final slots = subjectsStructure[semester] ?? {};

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            semester.replaceAll('_', ' ').toUpperCase(),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.blue,
            ),
          ),
          SizedBox(height: 20),

          // Render course cards
          ...slots.entries.map((slotEntry) {
            final slotName = slotEntry.key;
            final courses = slotEntry.value;

            return _buildCourseCard(semester, slotName, courses);
          }).toList(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Mark-Grade Converter'),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(child: Text(errorMessage!))
              : subjectsStructure.isEmpty || _currentSemesterKey == null
                  ? Center(child: Text('No subjects found'))
                  : _buildSemesterView(_currentSemesterKey!),
    );
  }
}
