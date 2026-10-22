import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'welcome_screen.dart';
import 'theme.dart';

List<CameraDescription> cameras = [];

Future<void> main() async {

  WidgetsFlutterBinding.ensureInitialized();

  try {
    cameras = await availableCameras();
  } catch (e) {
    print('Lỗi quét camera: $e');
  }

  runApp(const AndroidCamApp());
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