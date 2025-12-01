import 'package:flutter/material.dart';
import 'auth/signup_page.dart';
import 'auth/login_page.dart';
import 'gpa.dart';
import 'minor.dart';
import 'pred_screen.dart';
import 'grade.dart';
import 'start.dart'; // Example additional page
import 'export.dart'; // Example additional page
import 'theme/colors.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, // Removes the debug banner
      title: 'GPA Calculator',
      theme: ThemeData(
        primaryColor: AppColors.blue,
        scaffoldBackgroundColor: AppColors.blue, // Blue for background
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.blue, // Blue for AppBar background
          foregroundColor:
              AppColors.lightYellow, // Light yellow for AppBar text
        ),
        buttonTheme: ButtonThemeData(
          buttonColor: AppColors.lightYellow, // Light yellow for buttons
          textTheme: ButtonTextTheme.primary,
        ),
        textTheme: TextTheme(
          bodyLarge: TextStyle(color: AppColors.blue), // Light yellow for fonts
          bodyMedium:
              TextStyle(color: AppColors.black), // Light yellow for fonts
          displayLarge:
              TextStyle(color: AppColors.lightYellow), // Light yellow for fonts
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: AppColors.lightYellow, // Light yellow for FAB
          foregroundColor: AppColors.blue, // Blue for FAB icon
        ),
      ),
      home: LoginPage(),
      routes: {
        '/login': (context) => LoginPage(),
        '/signup': (context) => SignUpPage(),
        '/gpa': (context) => GpaCalculator(),
        '/minor_calculator': (context) => MinorCalculatorPage(),
        '/grade': (context) => GradeCalculatorPage(),
        '/home': (context) => StartPage(), // Example additional route
        '/profile': (context) => ExportPage(), // Example additional route
        '/pred': (context) => StudentDataForm(), // Example additional route
      },
    );
  }
}

class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Home Page'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () {},
          child: Text('Click Me'),
        ),
      ),
    );
  }
}
