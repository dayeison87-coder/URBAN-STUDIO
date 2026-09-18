import 'package:flutter/material.dart';
import 'core/theme/urban_theme.dart';
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
      theme: UrbanTheme.dark(),
      home: const LoginScreen(),
    );
  }
}
