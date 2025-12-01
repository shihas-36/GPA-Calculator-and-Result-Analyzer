import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:gpa_frontend/theme/colors.dart'; // Import AppColors
import 'package:gpa_frontend/start.dart';
import '../services/api_service.dart'; // Import API service
import 'choose_signup_page.dart';
import 'package:gpa_frontend/faculty.dart';
import 'package:gpa_frontend/admin.dart';
import 'package:gpa_frontend/gpa.dart';

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final storage = FlutterSecureStorage();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await ApiService.login(
        _emailController.text,
        _passwordController.text,
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final accessToken = responseData['access'];
        final refreshToken = responseData['refresh'];
        final KTUID = responseData['KTUID'] ?? 'N/A';

        // Log tokens
        print('Access Token: $accessToken');
        print('Refresh Token: $refreshToken');

        // Store tokens
        await storage.write(key: 'auth_token', value: accessToken);
        await storage.write(key: 'refresh_token', value: refreshToken);
        await storage.write(key: 'ktuid', value: KTUID);

        // Check superuser status
        final isSuperuserResponse = await ApiService.checkIsAdmin();

        if (isSuperuserResponse.statusCode == 200) {
          final superuserData = json.decode(isSuperuserResponse.body);
          final isSuperuser = superuserData['is_superuser'] ?? false;

          // Log superuser status
          print('Is Superuser: $isSuperuser');

          if (isSuperuser) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => AdminDashboardPage()),
            );
            return;
          }

          // Check faculty status
          final isFacultyResponse = await ApiService.checkIsFaculty();

          if (isFacultyResponse.statusCode == 200) {
            final isFacultyData = json.decode(isFacultyResponse.body);
            final isFaculty = isFacultyData['is_faculty'] ?? false;

            // Log faculty status
            print('Is Faculty: $isFaculty');
            if (isFaculty) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => FacultyPage()),
              );
            } else {
              // Student path: check if user needs initial GPA setup
              final userDataResponse = await ApiService.getUserData();
              if (userDataResponse.statusCode == 200) {
                final userData = json.decode(userDataResponse.body);
                final cgpa = userData['cgpa'];
                final semesters = userData['semesters'] as List<dynamic>?;
                final needsSetup =
                    (cgpa == null) || (semesters == null) || semesters.isEmpty;

                if (needsSetup) {
                  // Navigate to GPA calculator for first-time grade entry
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => GpaCalculator()),
                  );
                } else {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => StartPage()),
                  );
                }
              } else {
                // Fallback to start page if unable to fetch user data
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => StartPage()),
                );
              }
            }
          } else {
            throw Exception(
                'Failed to fetch faculty status: ${isFacultyResponse.body}');
          }
        } else {
          throw Exception(
              'Failed to fetch superuser status: ${isSuperuserResponse.body}');
        }
      } else {
        throw Exception('Failed to login: ${response.body}');
      }
    } catch (e) {
      print("Login error: $e");
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Error'),
            content: Text('Login failed: $e'),
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
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
        backgroundColor: AppColors.blue, // Use AppColors for AppBar
      ),
      backgroundColor: AppColors.blue, // Use AppColors for background
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),

                // Logo
                Center(
                  child: Image.asset(
                    'assets/Edula.png', // Path to your logo
                    width: 150,
                    height: 150,
                  ),
                ),
                const SizedBox(height: 40),

                // Login Title
                const Center(
                  child: Text(
                    'Welcome Back!',
                    style: TextStyle(
                      color: AppColors.lightYellow, // Use AppColors for text
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 30),

                // Email Field
                _buildTextField('Email', _emailController),

                // Password Field
                _buildTextField('Password', _passwordController,
                    isPassword: true),

                const SizedBox(height: 30),

                // Login Button
                Center(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.lightYellow, // Use AppColors
                      padding: const EdgeInsets.symmetric(
                          horizontal: 50, vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.black)
                        : const Text(
                            'Login',
                            style: TextStyle(
                              color: AppColors.blue, // Use AppColors for text
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 20),

                // Don't have an account text
                Center(
                  child: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => ChooseSignupPage()),
                      );
                    },
                    child: const Text(
                      "Don't have an account? Sign Up",
                      style: TextStyle(
                        color: AppColors.lightYellow, // Use AppColors for text
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper method to build text fields
  Widget _buildTextField(
    String placeholder,
    TextEditingController controller, {
    bool isPassword = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15.0),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        style: const TextStyle(color: AppColors.blue), // Text inside field
        decoration: InputDecoration(
          filled: true,
          fillColor: AppColors.lightYellow, // Use AppColors for field
          hintText: placeholder,
          hintStyle: const TextStyle(color: AppColors.blue),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
        ),
      ),
    );
  }
}
