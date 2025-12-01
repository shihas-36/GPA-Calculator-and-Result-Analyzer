import 'package:flutter/material.dart';
import 'login_page.dart';
import '../theme/colors.dart'; // Import AppColors
import '../services/api_service.dart';

class VerificationScreen extends StatefulWidget {
  final String email;
  final String token; // Add token as a parameter

  const VerificationScreen({
    required this.email,
    required this.token,
    Key? key,
  }) : super(key: key);

  @override
  _VerificationScreenState createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final TextEditingController _otpController = TextEditingController();
  bool _isVerifying = false;
  bool _isResending = false;

  Future<void> _verifyOTP() async {
    setState(() => _isVerifying = true);
    try {
      final response = await ApiService.verifyOtp(
        widget.email,
        _otpController.text,
      );

      // Print the response for debugging
      print('Response Status Code: ${response.statusCode}');
      print('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Email verified successfully!')),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => LoginPage()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invalid OTP')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isVerifying = false);
    }
  }

  Future<void> _resendOTP() async {
    setState(() => _isResending = true);
    try {
      final response = await ApiService.resendOtp(widget.email);

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('A new OTP has been sent to your email.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to resend OTP.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isResending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Email'),
        backgroundColor: AppColors.blue, // Use AppColors for AppBar
      ),
      backgroundColor: AppColors.blue, // Use AppColors for background
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Enter the OTP sent to your email',
              style: TextStyle(
                fontSize: 18,
                color: AppColors.lightYellow, // Use AppColors for text
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              style:
                  TextStyle(color: AppColors.blue), // Text color inside field
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.lightYellow, // Use AppColors for field
                labelText: 'OTP',
                labelStyle: TextStyle(color: AppColors.blue),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isVerifying ? null : _verifyOTP,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    AppColors.lightYellow, // Use AppColors for button
                padding:
                    const EdgeInsets.symmetric(vertical: 15, horizontal: 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: _isVerifying
                  ? const CircularProgressIndicator(color: Colors.black)
                  : const Text(
                      'Verify OTP',
                      style: TextStyle(
                        color: AppColors.blue, // Use AppColors for button text
                        fontSize: 16,
                      ),
                    ),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: _isResending ? null : _resendOTP,
              child: _isResending
                  ? const CircularProgressIndicator(
                      color: AppColors.lightYellow)
                  : const Text(
                      'Resend OTP',
                      style: TextStyle(
                        color: AppColors.lightYellow, // Use AppColors for text
                        fontSize: 16,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
