import 'package:flutter/material.dart';
import 'features/auth/login_screen.dart';

void main() {
  runApp(const UrbanStudioApp());
}

class UrbanStudioApp extends StatelessWidget {
  const UrbanStudioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Urban Studio',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      home: const LoginScreen(),
    );
  }
}