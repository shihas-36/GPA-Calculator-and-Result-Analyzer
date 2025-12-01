/*import 'package:flutter/material.dart';
import 'dart:convert';
import 'login_page.dart';
import '../services/api_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../gpa.dart';

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
        title: Text('Sign Up'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pushReplacementNamed(context, '/'),
        ),
        backgroundColor: const Color.fromARGB(255, 20, 53, 89),
      ),
      backgroundColor: const Color.fromARGB(255, 20, 53, 89),
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
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.menu,
                              color: Colors.white, size: 32),
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
                        color: Colors.white,
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
                          style: TextStyle(color: Colors.white, fontSize: 16),
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
                              fillColor: const Color(0xFFF8F0E3),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty)
                                return 'Required';
                              final cgpa = double.tryParse(value);
                              if (cgpa == null || cgpa < 0 || cgpa > 10)
                                return 'Invalid';
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
                        const Text('Semester : ',
                            style:
                                TextStyle(color: Colors.white, fontSize: 16)),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 15),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F0E3),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: DropdownButton<String>(
                            value: _selectedSemester,
                            underline: Container(),
                            dropdownColor: const Color(0xFFF8F0E3),
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
                        const Text('Degree : ',
                            style:
                                TextStyle(color: Colors.white, fontSize: 16)),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 15),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F0E3),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: DropdownButton<String>(
                            value: _selectedDegree,
                            underline: Container(),
                            dropdownColor: const Color(0xFFF8F0E3),
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
                          backgroundColor: const Color(0xFFF8F0E3),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30)),
                        ),
                        child: _isLoading
                            ? CircularProgressIndicator(color: Colors.black)
                            : const Text('Sign Up',
                                style: TextStyle(
                                    color: Colors.black, fontSize: 18)),
                      ),
                    ),
                  ),
                  // Bottom Image
                  Container(
                    height: 150,
                    child: Stack(
                      children: [
                        Positioned(
                          bottom: 0,
                          left: 0,
                          child: Image.asset('assets/hand_with_phone.png',
                              width: 150),
                        ),
                      ],
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
        decoration: InputDecoration(
          filled: true,
          fillColor: const Color(0xFFF8F0E3),
          hintText: label,
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
        Text(title, style: TextStyle(color: Colors.white, fontSize: 16)),
        Checkbox(
          value: groupValue,
          onChanged: onChanged,
          fillColor: MaterialStateProperty.all(Colors.white),
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

      final loginResponse = await ApiService.login(
        _emailController.text,
        _passwordController.text,
      );

      if (loginResponse.statusCode != 200) {
        throw jsonDecode(loginResponse.body)['error'] ?? 'Login failed';
      }

      final loginData = json.decode(loginResponse.body);
      await storage.write(key: 'auth_token', value: loginData['access']);
      await storage.write(key: 'refresh_token', value: loginData['refresh']);
      await storage.write(
        key: 'current_semester',
        value: _isLetSelected ? 'semester_3' : 'semester_1',
      );

      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account created successfully!')));
      Navigator.pushNamed(context, '/gpa');
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    } finally {
      setState(() => _isLoading = false);
    }
  }
}
*/
