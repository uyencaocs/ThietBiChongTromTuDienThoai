import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'config.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<dynamic> _images = [];
  bool _isAdmin = false;
  bool _isLoading = true;
  final String _baseUrl = kBaseApiUrl;

  @override
  void initState() {
    super.initState();
    _checkRoleAndFetchData();
  }

  Future<void> _checkRoleAndFetchData() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token') ?? '';

    if (token.isNotEmpty) {
      final parts = token.split('.');
      if (parts.length == 3) {
        final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
        _isAdmin = payload.contains('Admin');
      }
    }

    await _fetchImages(token);
  }

  Future<void> _fetchImages(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/Camera/images'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        setState(() {
          _images = jsonDecode(response.body);
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Lỗi tải danh sách: $e');
    }
  }

  Future<void> _deleteImage(String fileName) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token') ?? '';

    final response = await http.delete(
      Uri.parse('$_baseUrl/api/Camera/images/$fileName'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      setState(() {
        _images.removeWhere((img) => img['fileName'] == fileName);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xóa dữ liệu')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bảng điều khiển An ninh')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _images.isEmpty
          ? const Center(child: Text('Chưa có dữ liệu cảnh báo.'))
          : ListView.builder(
        itemCount: _images.length,
        itemBuilder: (context, index) {
          final item = _images[index];
          return Card(
            margin: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                Image.network('$_baseUrl${item['url']}'),
                ListTile(
                  title: Text('Tệp: ${item['fileName']}'),
                  trailing: _isAdmin
                      ? IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteImage(item['fileName']),
                  )
                      : null,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}