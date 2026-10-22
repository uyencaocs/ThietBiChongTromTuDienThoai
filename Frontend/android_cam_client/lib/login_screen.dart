import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'otp_screen.dart';
import 'package:local_auth/local_auth.dart';
import 'config.dart';
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = '';
  final LocalAuthentication auth = LocalAuthentication();

  // Hàm sinh trắc học đã tối giản tham số để tương thích mọi phiên bản
  Future<void> _authenticateBiometric() async {
    try {
      final bool didAuthenticate = await auth.authenticate(
        localizedReason: 'Xác thực để truy cập nhanh hệ thống',
      );
      if (!mounted) return;
      if (didAuthenticate) {
        // Navigate directly to dashboard on successful biometric auth
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const DashboardScreen()),
        );
      } else {
        _showBiometricFallback('Xác thực vân tay không thành công.');
      }
    } catch (e) {
      // Biometric unavailable, locked out or cancelled
      if (mounted) {
        _showBiometricFallback('Không thể xác thực vân tay.');
      }
    }
  }

  void _showBiometricFallback(String reason) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text('$reason Vui lòng thử lại hoặc đăng nhập bằng mật khẩu.'),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Thử lại',
          onPressed: _authenticateBiometric,
        ),
      ),
    );
  }

  // Hàm đăng nhập đã được khôi phục
  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await http.post(
        Uri.parse('$kBaseApiUrl/api/Auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': _emailController.text,
          'password': _passwordController.text,
        }),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OtpScreen(email: _emailController.text),
            ),
          );
        }
      } else {
        setState(() {
          _errorMessage = response.body;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Lỗi kết nối đến máy chủ';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Đăng nhập hệ thống')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Mật khẩu'),
              obscureText: true,
            ),
            const SizedBox(height: 24),
            if (_errorMessage.isNotEmpty)
              Text(_errorMessage, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: _login,
                    child: const Text(
                      'Đăng nhập',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
            const SizedBox(height: 24),
            IconButton(
              icon: const Icon(
                Icons.fingerprint,
                size: 50,
                color: Colors.tealAccent,
              ),
              onPressed: _authenticateBiometric,
            ),
          ],
        ),
      ),
    );
  }
}
