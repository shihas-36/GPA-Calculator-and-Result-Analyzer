import 'package:flutter/material.dart';
import 'dart:convert';
import 'login_page.dart';
import '../services/api_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../gpa.dart';
import 'verification_screen.dart';
import '../theme/colors.dart'; // Import AppColors

class SignUpPage extends StatefulWidget {
  @override
  _SignUpPageState createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _ktuidController = TextEditingController();
  final TextEditingController _targetedCgpaController = TextEditingController();
  final storage = FlutterSecureStorage();

  String? _selectedSemester = "1";
  String? _selectedDegree;
  bool _isMinorSelected = false;
  bool _isLetSelected = false;
  bool _isHonorSelected = false;
  bool _showOptions = false;
  bool _showHonor = false;
  bool _isLoading = false;

  void _checkSemester(String? value) {
    final semester = int.tryParse(value ?? '') ?? 0;
    setState(() {
      _showOptions = semester > 2; // Controls Minor/Let visibility
      _showHonor = semester > 3; // Controls Honor visibility
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign Up'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pushReplacementNamed(context, '/'),
        ),
        backgroundColor: AppColors.blue, // Updated AppBar background color
      ),
      backgroundColor: AppColors.blue, // Updated Scaffold background color
      body: SafeArea(
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Section
                  Padding(
                    padding: const EdgeInsets.only(top: 20.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Thqdu',
                          style: TextStyle(
                            color: AppColors.lightYellow, // Updated text color
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.menu,
                              color: AppColors.lightYellow,
                              size: 32), // Updated icon color
                          onPressed: () {},
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  // Title
                  const Center(
                    child: Text(
                      'Create Account Now!',
                      style: TextStyle(
                        color: AppColors.lightYellow, // Updated text color
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  // Form Fields
                  _buildTextField(_usernameController, 'Username'),
                  _buildTextField(_emailController, 'Gmail', isEmail: true),
                  _buildTextField(_passwordController, 'Password',
                      isPassword: true),
                  _buildTextField(
                      _confirmPasswordController, 'Confirm Password',
                      isPassword: true),
                  _buildTextField(_ktuidController, 'KTU ID'),
                  // Targeted CGPA
                  Padding(
                    padding: const EdgeInsets.only(top: 20.0),
                    child: Row(
                      children: [
                        const Text(
                          'Targeted CGPA:',
                          style: TextStyle(
                            color: AppColors.lightYellow, // Updated text color
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          width: 50,
                          height: 50,
                          child: TextFormField(
                            controller: _targetedCgpaController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: AppColors
                                  .lightYellow, // Updated field background color
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Required';
                              }
                              final cgpa = double.tryParse(value);
                              if (cgpa == null || cgpa < 0 || cgpa > 10) {
                                return 'Invalid';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Semester & Degree
                  Padding(
                    padding: const EdgeInsets.only(top: 20.0),
                    child: Row(
                      children: [
                        const Text(
                          'Semester:',
                          style: TextStyle(
                            color: AppColors.lightYellow, // Updated text color
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 15),
                          decoration: BoxDecoration(
                            color: AppColors
                                .lightYellow, // Updated dropdown background color
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: DropdownButton<String>(
                            value: _selectedSemester,
                            underline: Container(),
                            dropdownColor:
                                AppColors.lightYellow, // Updated dropdown color
                            items: List.generate(
                                    8, (index) => (index + 1).toString())
                                .map((value) => DropdownMenuItem(
                                    value: value, child: Text(value)))
                                .toList(),
                            onChanged: (value) => setState(() {
                              _selectedSemester = value;
                              _checkSemester(value);
                            }),
                          ),
                        ),
                        const SizedBox(width: 20),
                        const Text(
                          'Degree:',
                          style: TextStyle(
                            color: AppColors.lightYellow, // Updated text color
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 15),
                          decoration: BoxDecoration(
                            color: AppColors
                                .lightYellow, // Updated dropdown background color
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: DropdownButton<String>(
                            value: _selectedDegree,
                            underline: Container(),
                            dropdownColor:
                                AppColors.lightYellow, // Updated dropdown color
                            items: ['CSE', 'CE', 'ME', 'EEE']
                                .map((value) => DropdownMenuItem(
                                    value: value, child: Text(value)))
                                .toList(),
                            onChanged: (value) =>
                                setState(() => _selectedDegree = value),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Options
                  Padding(
                    padding: const EdgeInsets.only(top: 20.0),
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 30.0,
                      children: [
                        // Always visible "Are you Let?" radio
                        _buildRadioButton('Are you Let?', _isLetSelected,
                            (value) {
                          setState(() => _isLetSelected = value ?? false);
                        }),

                        // Conditionally visible Minor radio
                        if (_showOptions)
                          _buildRadioButton('Minor', _isMinorSelected, (value) {
                            setState(() => _isMinorSelected = value ?? false);
                          }),

                        // Conditionally visible Honor radio
                        if (_showHonor)
                          _buildRadioButton('Honor', _isHonorSelected, (value) {
                            setState(() => _isHonorSelected = value ?? false);
                          }),
                      ],
                    ),
                  ),
                  // Sign Up Button
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 30.0),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submitForm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors
                              .yellow, // Updated button background color
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30)),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.black)
                            : const Text(
                                'Sign Up',
                                style: TextStyle(
                                  color:
                                      Colors.black, // Updated button text color
                                  fontSize: 18,
                                ),
                              ),
                      ),
                    ),
                  ),
                  // Navigation to Login
                  Center(
                    child: TextButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (context) => GpaCalculator()),
                        );
                      },
                      child: const Text(
                        'Already having an account? Login',
                        style: TextStyle(
                          color: AppColors.yellow, // Updated text color
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
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label,
      {bool isEmail = false, bool isPassword = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15.0),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword,
        style: const TextStyle(
          color: AppColors.blue, // Set input text color to black
        ),
        decoration: InputDecoration(
          filled: true,
          fillColor: AppColors.lightYellow, // Use AppColors for background
          hintText: label,
          hintStyle: const TextStyle(
            color: AppColors.blue, // Set hint text color to blue
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) return 'Please enter $label';
          if (isEmail && !value.contains('@')) return 'Invalid email';
          if (isPassword && value.length < 6) return 'Minimum 6 characters';
          return null;
        },
      ),
    );
  }

  Widget _buildRadioButton(
      String title, bool groupValue, Function(bool?) onChanged) {
    return Row(
      children: [
        Text(title,
            style: const TextStyle(
                color: AppColors.lightYellow,
                fontSize: 16)), // Updated text color
        Checkbox(
          value: groupValue,
          onChanged: onChanged,
          fillColor: MaterialStateProperty.all(
              AppColors.lightYellow), // Updated checkbox color
        ),
      ],
    );
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Passwords do not match')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userData = {
        'username': _usernameController.text,
        'email': _emailController.text,
        'password': _passwordController.text,
        'KTUID': _ktuidController.text,
        'semester': int.parse(_selectedSemester ?? '1'),
        'degree': _selectedDegree,
        'targeted_cgpa': _targetedCgpaController.text,
        'is_minor': _isMinorSelected,
        'is_let': _isLetSelected,
        'is_honors': _isHonorSelected,
      };

      final signUpResponse = await ApiService.signUp(userData);
      if (signUpResponse.statusCode != 201) {
        throw jsonDecode(signUpResponse.body)['error'] ?? 'Signup failed';
      }

      // Extract the token from the response
      final responseData = jsonDecode(signUpResponse.body);
      final token = responseData['token']; // Ensure the backend sends the token

      // Navigate to the VerificationScreen and pass the token
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VerificationScreen(
            email: _emailController.text,
            token: token, // Pass the token to the VerificationScreen
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    } finally {
      setState(() => _isLoading = false);
    }
  }
}
