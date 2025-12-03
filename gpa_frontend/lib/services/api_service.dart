import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'dart:io';

class ApiService {
  static const String _androidEmulatorUrl = 'http://10.142.38.35:8000';
  static const String _localUrl = 'http://10.142.38.35:8000';
  // static const String _productionUrl = 'https://your-production-domain.com'; // Uncomment for production

  static const storage = FlutterSecureStorage();

  // Get the appropriate base URL based on platform and environment
  static String get baseUrl {
    if (Platform.isAndroid) {
      return _androidEmulatorUrl;
    } else if (Platform.isIOS) {
      return _localUrl; // or your machine's IP for iOS simulator
    } else {
      return _localUrl; // For web/desktop
    }
  }

  // Helper method to build full URL
  static String _buildUrl(String endpoint) {
    // Remove leading slash if present to avoid double slashes
    String cleanEndpoint =
        endpoint.startsWith('/') ? endpoint.substring(1) : endpoint;
    return '$baseUrl/$cleanEndpoint';
  }

  // Helper method to get authorization headers
  static Future<Map<String, String>> _getHeaders({bool withAuth = true}) async {
    Map<String, String> headers = {
      'Content-Type': 'application/json',
    };

    if (withAuth) {
      final token = await storage.read(key: 'auth_token');
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  // Generic GET request
  static Future<http.Response> get(String endpoint,
      {bool withAuth = true}) async {
    final headers = await _getHeaders(withAuth: withAuth);
    return await http.get(
      Uri.parse(_buildUrl(endpoint)),
      headers: headers,
    );
  }

  // Generic POST request
  static Future<http.Response> post(
    String endpoint, {
    Map<String, dynamic>? body,
    bool withAuth = true,
  }) async {
    final headers = await _getHeaders(withAuth: withAuth);
    return await http.post(
      Uri.parse(_buildUrl(endpoint)),
      headers: headers,
      body: body != null ? json.encode(body) : null,
    );
  }

  // Generic PUT request
  static Future<http.Response> put(
    String endpoint, {
    Map<String, dynamic>? body,
    bool withAuth = true,
  }) async {
    final headers = await _getHeaders(withAuth: withAuth);
    return await http.put(
      Uri.parse(_buildUrl(endpoint)),
      headers: headers,
      body: body != null ? json.encode(body) : null,
    );
  }

  // Generic DELETE request
  static Future<http.Response> delete(String endpoint,
      {bool withAuth = true}) async {
    final headers = await _getHeaders(withAuth: withAuth);
    return await http.delete(
      Uri.parse(_buildUrl(endpoint)),
      headers: headers,
    );
  }

  // Authentication APIs
  static Future<http.Response> login(String email, String password) async {
    return await post(
      'token/',
      body: {'email': email, 'password': password},
      withAuth: false,
    );
  }

  static Future<http.Response> signUp(Map<String, dynamic> data) async {
    return await post('api/signup/', body: data, withAuth: false);
  }

  static Future<http.Response> facultySignUp(Map<String, dynamic> data) async {
    return await post('api/faculty/', body: data, withAuth: false);
  }

  // OTP Verification APIs
  static Future<http.Response> verifyOtp(String email, String otp) async {
    return await post(
      'api/verify-otp/',
      body: {'email': email, 'otp': otp},
      withAuth: false,
    );
  }

  static Future<http.Response> resendOtp(String email) async {
    return await post(
      'api/resend-otp/',
      body: {'email': email},
      withAuth: false,
    );
  }

  static Future<http.Response> checkIsAdmin() async {
    return await get('api/is_admin/');
  }

  static Future<http.Response> checkIsFaculty() async {
    return await get('api/is_faculty/');
  }

  // User Data APIs
  static Future<http.Response> getUserData() async {
    return await get('get_user_data/');
  }

  static Future<http.Response> getSubjects() async {
    return await get('get_subjects/');
  }

  // GPA Calculation APIs
  static Future<http.Response> calculateGpa(Map<String, dynamic> data) async {
    return await post('calculate_gpa/', body: data);
  }

  static Future<http.Response> calculateGrade(Map<String, dynamic> data) async {
    return await post('calculate_grade/', body: data);
  }

  static Future<http.Response> calculateMinor(Map<String, dynamic> data) async {
    return await post('calculate_minor/', body: data);
  }

  // Minor/Honor Course APIs
  static Future<http.Response> getMinorSubjects() async {
    return await get('get_minor_subjects/');
  }

  static Future<http.Response> checkMinorStatus() async {
    return await get('check_minor_status/');
  }

  // Notifications APIs
  static Future<http.Response> getNotifications() async {
    return await get('api/notifications/');
  }

  static Future<http.Response> markNotificationAsRead(
      int notificationId) async {
    return await post('api/notifications/$notificationId/read/');
  }

  static Future<http.Response> updateMinorStatus(
      Map<String, dynamic> data) async {
    return await post('update_minor_status/', body: data);
  }

  static Future<http.Response> updateHonorStatus(
      Map<String, dynamic> data) async {
    return await post('update_honor_status/', body: data);
  }

  static Future<http.Response> checkIncrementNotification() async {
    return await get('check_increment_notification/');
  }

  static Future<http.Response> confirmIncrementNotification() async {
    return await post('confirm_increment_notification/');
  }

  static Future<http.Response> denyIncrementNotification() async {
    return await post('deny_increment_notification/');
  }

  // Summary and Export APIs
  static Future<http.Response> getSummary() async {
    return await get('Summary/');
  }

  static Future<http.Response> exportGpaData(
      [Map<String, dynamic>? data]) async {
    return await post('export-pdf/', body: data);
  }

  // Faculty APIs
  static Future<http.Response> fetchStudentsByFaculty() async {
    return await get('fetch_students_by_faculty/');
  }

  // Admin APIs
  static Future<http.Response> incrementSemester() async {
    return await post('api/increment_semester/');
  }

  static Future<http.Response> sendNotification(
      Map<String, dynamic> data) async {
    return await post('api/send_notification/', body: data);
  }

  // Grade Prediction API (for your new feature)
  static Future<http.Response> predictGrade(Map<String, dynamic> data) async {
    return await post('predict_grade/', body: data);
  }

  // CGPA Prediction APIs
  static Future<http.Response> predictCgpa(Map<String, dynamic> data) async {
    return await post('predict_cgpa/', body: data);
  }

  static Future<http.Response> predictCgpaFromUserData(
      Map<String, dynamic> data) async {
    return await post('predict_cgpa_from_user_data/', body: data);
  }

  static Future<http.Response> getPredictionFormData() async {
    return await get('get_prediction_form_data/');
  }

  static Future<http.Response> getPredictionHistory() async {
    return await get('get_prediction_history/');
  }

  static Future<http.Response> trainPredictionModel() async {
    return await post('train_prediction_model/');
  }

  // Legacy method support (if needed)
  static Future<http.Response> fillGrades(
      Map<String, dynamic> data, String token) async {
    return await post('Fill_grades/', body: data);
  }
}
