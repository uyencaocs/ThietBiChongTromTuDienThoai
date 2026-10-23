import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dashboard_screen.dart';
import 'main.dart';
import 'config.dart';
import 'face_utils.dart';
import 'package:flutter_tts/flutter_tts.dart';

enum GuardMode {
  always24h, // Cảnh giác suốt 24 giờ
  enabled,   // Bật cảnh giác
  disabled,  // Tắt cảnh giác
}

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  bool _isCameraInitialized = false;
  bool _isUploading = false;
  bool _isProcessingImage = false;

  GuardMode _guardMode = GuardMode.always24h;

  final FlutterTts flutterTts = FlutterTts();
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  DateTime? _lastAlertTime;

  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: false,
      enableClassification: false,
    ),
  );


  @override
  void initState() {
    super.initState();
    _loadGuardSettings();
    _initCamera();
    _initVibrationSensor();
    _initTts();
    loadKnownPersons(); // Pre-load known_faces.json into cache
  }

  Future<void> _loadGuardSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final modeStr = prefs.getString('guard_mode') ?? 'always24h';
      if (mounted) {
        setState(() {
          _guardMode = GuardMode.values.firstWhere(
            (e) => e.name == modeStr,
            orElse: () => GuardMode.always24h,
          );
        });
      }
    } catch (_) {}
  }

  Future<void> _setGuardMode(GuardMode mode) async {
    setState(() {
      _guardMode = mode;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('guard_mode', mode.name);
    } catch (_) {}

    final (msg, color) = switch (mode) {
      GuardMode.always24h => ('Đã bật chế độ cảnh giác suốt 24 giờ liên tục!', Colors.blue),
      GuardMode.enabled => ('Đã bật chế độ cảnh giác an ninh!', Colors.green),
      GuardMode.disabled => ('Đã tắt chế độ cảnh giác!', Colors.orange),
    };

    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: color,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  bool _isGuardingActive() {
    return switch (_guardMode) {
      GuardMode.always24h => true,
      GuardMode.enabled => true,
      GuardMode.disabled => false,
    };
  }

  void _initTts() async {
    try {
      await flutterTts.setLanguage('vi-VN');
      await flutterTts.setVolume(1.0);
      await flutterTts.setSpeechRate(0.5);
      await flutterTts.setPitch(1.0);
    } catch (e) {
      debugPrint('TTS không khả dụng trên thiết bị ảo: $e');
    }
  }

  int _selectedCameraIndex = 0;

  Future<void> _switchCamera() async {
    if (cameras.length < 2) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chỉ có 1 camera khả dụng. Để dùng webcam thật, cấu hình trong Android Studio Device Manager.')),
        );
      }
      return;
    }
    _selectedCameraIndex = (_selectedCameraIndex + 1) % cameras.length;
    await _controller?.dispose();
    if (mounted) {
      setState(() {
        _isCameraInitialized = false;
      });
    }
    await _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      if (cameras.isEmpty) {
        cameras = await availableCameras();
      }
      if (cameras.isEmpty) {
        debugPrint('Không tìm thấy camera khả dụng trên thiết bị');
        return;
      }

      final cameraToUse = cameras[_selectedCameraIndex < cameras.length ? _selectedCameraIndex : 0];

      _controller = CameraController(
        cameraToUse,
        ResolutionPreset.medium,
        enableAudio: false, // Tắt audio để tránh lỗi đòi quyền RECORD_AUDIO / mic ảo crash
        imageFormatGroup: ImageFormatGroup.nv21,
      );

      await _controller!.initialize();
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
      await _controller!.startImageStream(_processCameraImage);
    } catch (e) {
      debugPrint('Lỗi khởi tạo camera: $e');
    }
  }

  void _initVibrationSensor() {
    try {
      _accelerometerSubscription = accelerometerEventStream().listen(
        (AccelerometerEvent event) {
          if (!_isGuardingActive()) return;

          double acceleration = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
          if (acceleration > 15.0) {
            _triggerAlert(reason: 'RUNG_LAC');
          }
        },
        onError: (e) {
          debugPrint('Cảm biến gia tốc không hỗ trợ trên thiết bị ảo: $e');
        },
      );
    } catch (e) {
      debugPrint('Lỗi đăng ký cảm biến gia tốc: $e');
    }
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isProcessingImage || !_isGuardingActive()) return;
    _isProcessingImage = true;

    try {
      final inputImage = _convertCameraImageToInputImage(image);
      if (inputImage == null) {
        _isProcessingImage = false;
        return;
      }

      final faces = await _faceDetector.processImage(inputImage);

      if (faces.isNotEmpty) {
        final embedding = await _extractFaceEmbedding(image, faces.first);
        final bool known = embedding != null && await isKnownPerson(embedding);
        _triggerAlert(reason: known ? 'NGUOI_NHA' : 'NGUOI_LA');
      }
    } catch (e) {
      print('Lỗi nhận diện AI: $e');
    } finally {
      _isProcessingImage = false;
    }
  }

  /// PLACEHOLDER: compute a face embedding for [face] from [image].
  ///
  /// Replace with a real TensorFlow Lite model (e.g. MobileFaceNet / FaceNet,
  /// 128- or 192-float output) that:
  ///   1. crops `face.boundingBox` from the camera frame,
  ///   2. resizes to the model input (e.g. 112x112) and normalizes pixels,
  ///   3. runs inference and returns the output vector.
  /// The vector length must match the embeddings in `assets/known_faces.json`.
  ///
  /// Returning `null` means "no embedding available" and the face is treated
  /// as "Người lạ" (fail-safe: an unrecognised face always raises an alert).
  Future<List<double>?> _extractFaceEmbedding(CameraImage image, Face face) async {
    return null;
  }

  InputImage? _convertCameraImageToInputImage(CameraImage image) {
    if (cameras.isEmpty) return null;
    final camera = cameras[_selectedCameraIndex < cameras.length ? _selectedCameraIndex : 0];
    final sensorOrientation = camera.sensorOrientation;

    final InputImageRotation? rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw) ?? InputImageFormat.nv21;
    if (image.planes.isEmpty) return null;

    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes[0].bytesPerRow,
      ),
    );
  }

  Future<void> _triggerAlert({required String reason}) async {
    // Household member recognised – no alert.
    if (reason == 'NGUOI_NHA') {
      print('Nhận diện: Người nhà – bỏ qua cảnh báo.');
      return;
    }

    final now = DateTime.now();
    if (_lastAlertTime != null && now.difference(_lastAlertTime!).inSeconds < 15) {
      return;
    }

    _lastAlertTime = now;
    print('PHÁT HIỆN: $reason! Đang xử lý...');

    try {
      await _controller!.stopImageStream();

      // Gửi ảnh kèm thông tin cảnh báo lên backend (Backend Discord Bot sẽ gửi ảnh kèm nút bấm tương tác)
      final alertId = await _captureAndUpload(isEmergency: true, reason: reason);

      // Nếu Discord Webhook trực tiếp được cấu hình riêng trên client, gửi dự phòng
      if (!kDiscordWebhookUrl.contains('YOUR_WEBHOOK_ID')) {
        unawaited(_sendDiscordAlert(reason: reason));
      }

      await flutterTts.speak('Cảnh báo an ninh. Khu vực hạn chế. Vui lòng đọc mật khẩu xác thực trong 7 giây, nếu không hệ thống sẽ báo động.');

      // Lắng nghe phản hồi thời gian thực từ nút bấm Discord trong 8 giây
      bool resolved = false;
      if (alertId != null && alertId.isNotEmpty) {
        for (int i = 0; i < 8; i++) {
          await Future.delayed(const Duration(seconds: 1));
          if (!mounted) break;

          final status = await _checkAlertStatus(alertId);
          if (status == 'ConfirmedHome') {
            resolved = true;
            await flutterTts.speak('Đã xác nhận người nhà qua Discord. Hủy chế độ cảnh báo.');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('✅ Đã xác nhận người nhà qua Discord. Hủy báo động.'),
                  backgroundColor: Colors.green,
                ),
              );
            }
            break;
          } else if (status == 'AlarmTriggered') {
            resolved = true;
            await flutterTts.speak('Báo động khẩn cấp được kích hoạt từ Discord!');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('🚨 BÁO ĐỘNG KHẨN CẤP ĐÃ ĐƯỢC BẬT TỪ DISCORD!'),
                  backgroundColor: Colors.red,
                ),
              );
            }
            break;
          }
        }
      } else {
        await Future.delayed(const Duration(seconds: 7));
      }

      if (!resolved) {
        print('Hết thời gian chờ phản hồi. Tiếp tục canh gác.');
      }

      if (_controller != null && _controller!.value.isInitialized) {
        await _controller!.startImageStream(_processCameraImage);
      }
    } catch (e) {
      print('Lỗi chu kỳ cảnh báo: $e');
    }
  }

  /// Kiểm tra trạng thái phản hồi của nút bấm Discord từ Backend
  Future<String?> _checkAlertStatus(String alertId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token') ?? '';
      final response = await http.get(
        Uri.parse('$kBaseApiUrl/api/Alerts/$alertId'),
        headers: {
          'Content-Type': 'application/json',
          if (token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['status']?.toString();
      }
    } catch (_) {}
    return null;
  }

  /// Posts an alert to the Discord webhook with interactive action buttons.
  Future<void> _sendDiscordAlert({required String reason}) async {
    if (kDiscordWebhookUrl.contains('YOUR_WEBHOOK_ID')) {
      return;
    }

    final String content = switch (reason) {
      'NGUOI_LA' => 'Cảnh báo: Người lạ phát hiện!',
      'RUNG_LAC' => 'Cảnh báo: Phát hiện rung lắc thiết bị!',
      _ => 'Cảnh báo an ninh: $reason',
    };
    final timestamp = DateTime.now().toLocal().toString().split('.').first;

    final payload = {
      'content': '$content\n🕒 $timestamp',
    };

    try {
      final uri = Uri.parse(kDiscordWebhookUrl);
      const headers = {'Content-Type': 'application/json'};
      await http.post(uri, headers: headers, body: jsonEncode(payload));
    } catch (e) {
      print('Lỗi gửi Discord fallback: $e');
    }
  }

  Future<String?> _captureAndUpload({bool isEmergency = false, String reason = 'NGUOI_LA'}) async {
    if (!_controller!.value.isInitialized || _isUploading) return null;

    setState(() { _isUploading = true; });

    try {
      final XFile image = await _controller!.takePicture();
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token') ?? '';

      var request = http.MultipartRequest('POST', Uri.parse('$kBaseApiUrl/api/Camera/upload'));
      request.headers['Authorization'] = 'Bearer $token';
      request.fields['isEmergency'] = isEmergency.toString();
      request.fields['reason'] = reason;
      request.files.add(await http.MultipartFile.fromPath('file', image.path));

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        if (isEmergency && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Đã gửi ảnh cảnh báo lên máy chủ!'), backgroundColor: Colors.red,)
          );
        }
        final data = jsonDecode(response.body);
        return data['alertId']?.toString();
      }
    } catch (e) {
      print('Lỗi tải ảnh: $e');
    } finally {
      if (mounted) { setState(() { _isUploading = false; }); }
    }
    return null;
  }

  @override
  void dispose() {
    _accelerometerSubscription?.cancel();
    _faceDetector.close();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Giám sát An ninh AI'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.flip_camera_android),
            tooltip: 'Đổi Camera Trước / Sau',
            onPressed: _switchCamera,
          ),
          IconButton(
            icon: const Icon(Icons.dashboard),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const DashboardScreen()),
              );
            },
          ),
        ],
      ),
      backgroundColor: Colors.black,
      body: _isCameraInitialized
          ? Stack(
              children: [
                Center(child: CameraPreview(_controller!)),
          // Huy hiệu trạng thái cảnh giác
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _isGuardingActive()
                    ? Colors.red.withValues(alpha: 0.85)
                    : Colors.grey.shade800.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _isGuardingActive() ? Colors.redAccent : Colors.grey,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isGuardingActive() ? Icons.shield : Icons.shield_outlined,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    switch (_guardMode) {
                      GuardMode.always24h => 'CANH GÁC 24/24H (BẬT)',
                      GuardMode.enabled => 'ĐANG CANH GÁC',
                      GuardMode.disabled => 'ĐÃ TẮT CANH GÁC',
                    },
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isUploading)
            const Positioned(
              top: 16,
              right: 16,
              child: CircularProgressIndicator(color: Colors.red),
            ),
          // Bảng điều khiển chế độ cảnh giác (Bật 24/24, Bật ngay, Tắt cảnh giác)
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white24, width: 1),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black54,
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Nút 1: Cảnh giác suốt 24 giờ
                  Expanded(
                    child: _buildGuardButton(
                      title: '24/24 Giờ',
                      icon: Icons.all_inclusive,
                      isSelected: _guardMode == GuardMode.always24h,
                      selectedColor: Colors.blueAccent,
                      onTap: () => _setGuardMode(GuardMode.always24h),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Nút 2: Bật cảnh giác
                  Expanded(
                    child: _buildGuardButton(
                      title: 'Bật cảnh giác',
                      icon: Icons.security,
                      isSelected: _guardMode == GuardMode.enabled,
                      selectedColor: Colors.green,
                      onTap: () => _setGuardMode(GuardMode.enabled),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Nút 3: Tắt cảnh giác
                  Expanded(
                    child: _buildGuardButton(
                      title: 'Tắt cảnh giác',
                      icon: Icons.power_settings_new,
                      isSelected: _guardMode == GuardMode.disabled,
                      selectedColor: Colors.redAccent,
                      onTap: () => _setGuardMode(GuardMode.disabled),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      )
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Colors.tealAccent),
                  const SizedBox(height: 16),
                  const Text(
                    'Đang khởi tạo camera an ninh...',
                    style: TextStyle(color: Colors.white70, fontSize: 15),
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: _initCamera,
                    icon: const Icon(Icons.refresh, color: Colors.tealAccent),
                    label: const Text(
                      'Thử kết nối lại camera',
                      style: TextStyle(color: Colors.tealAccent),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildGuardButton({
    required String title,
    required IconData icon,
    required bool isSelected,
    required Color selectedColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? selectedColor : Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.grey.shade400,
              size: 20,
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey.shade300,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
  }