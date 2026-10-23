import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'welcome_screen.dart';
import 'theme.dart';

/// Bỏ qua kiểm tra chứng chỉ SSL tự ký (Self-signed) khi chạy thử nghiệm
/// qua Conveyor hoặc địa chỉ IP HTTPS cục bộ (ví dụ: https://192.168.0.41:45455).
class DevHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = DevHttpOverrides();

  // Khởi động giao diện ngay lập tức để không bị Android OS kill do ANR/Timeout
  runApp(const AndroidCamApp());

  // Quét camera ngầm trong nền
  try {
    cameras = await availableCameras();
  } catch (e) {
    debugPrint('Lỗi quét camera ban đầu: $e');
  }
}

class AndroidCamApp extends StatelessWidget {
  const AndroidCamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Android Cam',
      theme: AppTheme.darkTheme,
      home: const WelcomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}