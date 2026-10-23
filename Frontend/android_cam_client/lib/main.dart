import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'welcome_screen.dart';
import 'theme.dart';

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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