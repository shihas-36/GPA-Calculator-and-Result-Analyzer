import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'services/api_service.dart';
import 'theme/colors.dart';

class GpaCalculator extends StatefulWidget {
  @override
  _GpaCalculatorState createState() => _GpaCalculatorState();
}

class _GpaCalculatorState extends State<GpaCalculator>
    with TickerProviderStateMixin {
  final storage = FlutterSecureStorage();
  late TabController _tabController;
  Map<String, Map<String, Map<String, int>>> subjectsStructure = {};
  Map<String, Map<String, String?>> selectedSubjects = {};
  Map<String, Map<String, String?>> selectedGrades = {};
  double? gpa;
  double? cgpa;
  bool isLoading = false;

  final Map<String, double> gradeValues = {
    'S': 10,
    'A': 8.5,
    'A+': 9,
    'B+': 8,
    'B': 7.5,
    'C+': 7,
    'C': 6.5,
    'D+': 6,
    'P': 5.5,
    'F': 0,
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 1, vsync: this);
    fetchSubjects();
    fetchUserData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _updateTabController() {
    final newLength = subjectsStructure.keys.length;
    if (_tabController.length != newLength) {
      _tabController.dispose();
      _tabController = TabController(
        length: newLength,
        vsync: this,
      );
    }
  }

  Future<void> fetchSubjects() async {
    try {
      final response = await ApiService.getSubjects();

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        print('API Response: $data');

        final parsedData = data.map<String, Map<String, Map<String, int>>>(
            (semesterKey, semesterValue) {
          final slots = (semesterValue as Map<String, dynamic>)
              .map<String, Map<String, int>>((slotKey, slotValue) {
            return MapEntry(
              slotKey,
              (slotValue as Map<String, dynamic>).map<String, int>(
                (subject, credit) => MapEntry(subject, (credit as num).toInt()),
              ),
            );
          });
          return MapEntry(semesterKey, slots);
        });

        if (mounted) {
          setState(() {
            subjectsStructure = parsedData;

            // Initialize selections
            selectedSubjects = {};
            selectedGrades = {};

            parsedData.forEach((semester, slots) {
              selectedSubjects[semester] = {};
              selectedGrades[semester] = {};

              slots.forEach((slot, courses) {
                if (courses.isNotEmpty) {
                  // Select first course by default
                  selectedSubjects[semester]![slot] = courses.keys.first;
                  selectedGrades[semester]![courses.keys.first] = null;
                }
              });
            });

            _updateTabController();
          });
        }
      } else {
        throw Exception('Failed to load subjects: ${response.statusCode}');
      }
    } catch (e) {
      print("Error fetching subjects: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to fetch subjects: $e')),
        );
      }
    }
  }

  Future<void> fetchUserData() async {
    try {
      final response = await ApiService.getUserData();

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (mounted) {
          setState(() {
            cgpa = responseData['cgpa']?.toDouble();
            for (var semesterData in responseData['semesters']) {
              String semesterKey = semesterData['semester'];
              for (var subject in semesterData['subjects']) {
                String subjectName = subject['name'];
                String? grade = subject['grade'];

                // Find which slot contains this subject
                subjectsStructure[semesterKey]?.forEach((slot, courses) {
                  if (courses.containsKey(subjectName)) {
                    // Set this as the selected subject for the slot
                    selectedSubjects[semesterKey] ??= {};
                    selectedSubjects[semesterKey]![slot] = subjectName;

                    // Set the grade if it exists
                    selectedGrades[semesterKey] ??= {};
                    if (grade != null) {
                      selectedGrades[semesterKey]![subjectName] = grade;
                    }
                  }
                });
              }
            }
          });
        }
      }
    } catch (e) {
      print("Error fetching user data: $e");
    }
  }

  Future<void> calculateGPA() async {
    setState(() {
      isLoading = true;
    });

    try {
      final semester = subjectsStructure.keys.elementAt(_tabController.index);

      // Prepare grades for currently selected subjects
      Map<String, String?> gradesToSend = {};
      selectedSubjects[semester]!.forEach((slot, subject) {
        if (subject != null && selectedGrades[semester]!.containsKey(subject)) {
          gradesToSend[subject] = selectedGrades[semester]![subject];
        }
      });

      // Check if all grades are selected
      if (gradesToSend.values.any((grade) => grade == null)) {
        throw Exception('Please select grades for all subjects');
      }

      final response = await ApiService.calculateGpa({
        'semester': semester,
        'grades': gradesToSend,
      });

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (mounted) {
          setState(() {
            gpa = responseData['semester_gpa']?.toDouble();
            cgpa = responseData['cgpa']?.toDouble();
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('GPA calculated successfully!')),
          );
        }
      } else {
        throw Exception('Failed to calculate GPA: ${response.statusCode}');
      }
    } catch (e) {
      print("An error occurred: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to calculate GPA: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Widget _buildCourseCard(
      String semester, String slot, Map<String, int> courses) {
    // Get current subject with null check
    final currentSubject = selectedSubjects[semester]?[slot];
    // Verify the subject exists in current courses
    final validSubject = courses.containsKey(currentSubject)
        ? currentSubject
        : (courses.isNotEmpty ? courses.keys.first : null);

    // Get current grade with null check
    final currentGrade =
        (validSubject != null && selectedGrades[semester] != null)
            ? selectedGrades[semester]![validSubject]
            : null;

    return Container(
      margin: EdgeInsets.symmetric(vertical: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.lightYellow, AppColors.yellow],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: AppColors.lightBlue),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.lightBlue.withOpacity(0.2),
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
                      // Remove duplicates using Set
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
                        selectedGrades[semester] ??= {};

                        // Clear previous grade
                        final prev = selectedSubjects[semester]![slot];
                        if (prev != null) {
                          selectedGrades[semester]!.remove(prev);
                        }

                        // Set new subject
                        selectedSubjects[semester]![slot] = value;
                      });
                    },
                  ),
          ),
          if (validSubject != null)
            Container(
              width: 80,
              height: 40,
              margin: EdgeInsets.only(left: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: AppColors.lightBlue),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.lightBlue.withOpacity(0.2),
                    spreadRadius: 2,
                    blurRadius: 5,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: DropdownButton<String>(
                value: currentGrade,
                underline: Container(),
                icon:
                    Icon(Icons.arrow_drop_down, size: 18, color: Colors.black),
                style: TextStyle(fontSize: 16, color: Colors.black),
                items: gradeValues.keys.map((grade) {
                  return DropdownMenuItem<String>(
                    value: grade,
                    child: Center(
                      child: Text(
                        grade,
                        style: TextStyle(color: Colors.black),
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    selectedGrades[semester]![validSubject] = value;
                  });
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSemesterView(String semester) {
    final slots = subjectsStructure[semester] ?? {};
    final grades = selectedGrades[semester] ?? {};
    final credits = slots.values.fold<Map<String, int>>({}, (map, courses) {
      map.addAll(courses);
      return map;
    });

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          SizedBox(height: 16),
          SemesterSummaryCard(
            grades: grades,
            credits: credits,
            gradeValues: gradeValues,
            subjectsStructure: subjectsStructure,
          ),
          SizedBox(height: 20),
          ...slots.entries.map((slotEntry) {
            final slotName = slotEntry.key;
            final courses = slotEntry.value;
            return _buildCourseCard(semester, slotName, courses);
          }),
          if (gpa != null &&
              semester ==
                  subjectsStructure.keys.elementAt(_tabController.index))
            Column(
              children: [
                _buildResultsCard(),
                SizedBox(height: 20),
                Divider(),
                SizedBox(height: 16),
                SizedBox(height: 20),
              ],
            ),
          CalculateButton(
            isLoading: isLoading,
            onPressed: calculateGPA,
          ),
        ],
      ),
    );
  }

  Widget _buildResultsCard() {
    return Card(
      color: AppColors.yellow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'Results',
              style: TextStyle(
                  fontSize: 18,
                  color: AppColors.black,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildResultColumn('Semester GPA', gpa),
                _buildResultColumn('CGPA', cgpa),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultColumn(String label, double? value) {
    return Column(
      children: [
        Text(label),
        Text(
          value?.toStringAsFixed(2) ?? 'N/A',
          style: const TextStyle(
              fontSize: 24,
              color: AppColors.black,
              fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('GPA Calculator'),
        bottom: subjectsStructure.isNotEmpty
            ? TabBar(
                controller: _tabController,
                isScrollable: true,
                labelColor: AppColors.lightYellow, // Active tab text color
                unselectedLabelColor: Colors.grey, // Inactive tab text color
                indicatorColor: AppColors.lightYellow, // Indicator color
                tabs: subjectsStructure.keys.map((semester) {
                  return Tab(text: semester.replaceAll('_', ' ').toUpperCase());
                }).toList(),
              )
            : null,
      ),
      body: subjectsStructure.isNotEmpty
          ? TabBarView(
              controller: _tabController,
              children: subjectsStructure.keys.map((semester) {
                return _buildSemesterView(semester);
              }).toList(),
            )
          : Center(child: CircularProgressIndicator()),
      floatingActionButton: FloatingActionButton(
        onPressed: isLoading ? null : calculateGPA,
        backgroundColor: AppColors.primaryBlue,
        child: isLoading
            ? CircularProgressIndicator(color: Colors.white)
            : Icon(Icons.calculate, size: 24, color: Colors.white),
      ),
    );
  }
}

class CalculateButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onPressed;

  const CalculateButton({
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        minimumSize: Size(double.infinity, 50),
        padding: EdgeInsets.symmetric(vertical: 12),
        backgroundColor: AppColors.blue,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: isLoading
          ? CircularProgressIndicator(color: Colors.white)
          : Icon(
              Icons.calculate, // Calculator icon
              size: 24,
              color: Colors.white,
            ),
    );
  }
}

class SemesterSummaryCard extends StatelessWidget {
  final Map<String, String?> grades;
  final Map<String, int> credits;
  final Map<String, double> gradeValues;
  final Map<String, Map<String, Map<String, int>>> subjectsStructure;

  const SemesterSummaryCard({
    required this.grades,
    required this.credits,
    required this.gradeValues,
    required this.subjectsStructure,
  });

  @override
  Widget build(BuildContext context) {
    int totalCredits = grades.entries.fold(0, (sum, entry) {
      final grade = entry.value;
      final credit = credits[entry.key] ?? 0;
      return grade != 'F' ? sum + credit : sum;
    });

    int earnedCredits = grades.entries.fold(0, (sum, entry) {
      final grade = entry.value;
      final credit = credits[entry.key] ?? 0;
      return grade != null && grade != 'F' ? sum + credit : sum;
    });

    double totalPoints = grades.entries.fold(0.0, (sum, entry) {
      final grade = entry.value;
      final credit = credits[entry.key] ?? 0;
      return grade != null ? sum + (gradeValues[grade] ?? 0) * credit : sum;
    });

    bool allGradesSelected = grades.values.every((grade) => grade != null);

    return Card(
      color: AppColors.yellow,
      margin: EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Semester Summary',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSummaryItem('Total Credits', '$totalCredits'),
                _buildSummaryItem('Earned Credits', '$earnedCredits'),
              ],
            ),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSummaryItem(
                  'Completion',
                  '${grades.values.where((g) => g != null).length}/${grades.length}',
                ),
                _buildSummaryItem(
                  'saved GPA',
                  allGradesSelected
                      ? (totalPoints / totalCredits).toStringAsFixed(2)
                      : 'N/A',
                  isHighlighted: allGradesSelected,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value,
      {bool isHighlighted = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: AppColors.black,
          ),
        ),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isHighlighted ? AppColors.black : Colors.black,
          ),
        ),
      ],
    );
  }
}
