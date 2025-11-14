import 'package:flutter/material.dart';
import 'screens/login_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cho Thuê Máy Ảnh',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF6B35), // Màu cam sáng, năng động
          brightness: Brightness.light,
          primary: const Color(0xFFFF6B35), // Cam chính
          secondary: const Color(0xFFFFB627), // Vàng cam
          tertiary: const Color(0xFF4ECDC4), // Cyan sáng
          error: const Color(0xFFFF4757),
          surface: Colors.white,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onTertiary: Colors.white,
        ),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
