import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  // Base URL - Production
  static const String baseUrl = 'https://eduapp.hkrdn.in/api/v1';
  
  
  // Secure storage for token
  static const storage = FlutterSecureStorage();
  
  // Common headers
  static Map<String, String> get headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };
  
  // Headers with authentication token
  static Future<Map<String, String>> get authHeaders async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }
  
  // ==================== Token Management ====================
  
  /// Save authentication token
  static Future<void> saveToken(String token) async {
    await storage.write(key: 'auth_token', value: token);
  }
  
  /// Get authentication token
  static Future<String?> getToken() async {
    return await storage.read(key: 'auth_token');
  }
  
  /// Delete authentication token
  static Future<void> deleteToken() async {
    await storage.delete(key: 'auth_token');
  }
  
  /// Check if user is logged in
  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }
  
  // ==================== Authentication APIs ====================
  
  /// Register new user
  /// POST /auth/register
  static Future<Map<String, dynamic>> register({
    required String name,
    required String phone,
    required String password,
    required String passwordConfirmation,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: headers,
        body: jsonEncode({
          'name': name,
          'phone': phone,
          'password': password,
          'password_confirmation': passwordConfirmation,
        }),
      );
      
      return _handleResponse(response);
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }
  
  /// Login user
  /// POST /auth/login
  static Future<Map<String, dynamic>> login({
    required String phone,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: headers,
        body: jsonEncode({
          'phone': phone,
          'password': password,
        }),
      );
      
      return _handleResponse(response);
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }
  
  /// Forgot Password - Send OTP
  /// POST /auth/forgot-password
  static Future<Map<String, dynamic>> forgotPassword({
    required String phone,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/forgot-password'),
        headers: headers,
        body: jsonEncode({
          'phone': phone,
        }),
      );
      
      return _handleResponse(response);
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }
  
  /// Verify OTP
  /// POST /auth/verify-otp
  static Future<Map<String, dynamic>> verifyOtp({
    required String phone,
    required String otp,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/verify-otp'),
        headers: headers,
        body: jsonEncode({
          'phone': phone,
          'otp': otp,
        }),
      );
      
      return _handleResponse(response);
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }
  
  /// Reset Password
  /// POST /auth/reset-password
  static Future<Map<String, dynamic>> resetPassword({
    required String phone,
    required String resetToken,
    required String password,
    required String passwordConfirmation,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/reset-password'),
        headers: headers,
        body: jsonEncode({
          'phone': phone,
          'reset_token': resetToken,
          'password': password,
          'password_confirmation': passwordConfirmation,
        }),
      );
      
      return _handleResponse(response);
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }
  
  /// Change Password (for logged-in users)
  /// POST /auth/change-password
  static Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String password,
    required String passwordConfirmation,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/change-password'),
        headers: await authHeaders,
        body: jsonEncode({
          'current_password': currentPassword,
          'password': password,
          'password_confirmation': passwordConfirmation,
        }),
      );
      
      return _handleResponse(response);
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }
  
  /// Get User Profile
  /// GET /auth/profile
  static Future<Map<String, dynamic>> getProfile() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/auth/profile'),
        headers: await authHeaders,
      );
      
      return _handleResponse(response);
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }
  
  /// Update User Profile
  /// PUT /auth/profile
  static Future<Map<String, dynamic>> updateProfile({
    String? name,
    String? email,
    String? city,
    String? state,
  }) async {
    try {
      final Map<String, dynamic> body = {};
      if (name != null) body['name'] = name;
      if (email != null) body['email'] = email;
      if (city != null) body['city'] = city;
      if (state != null) body['state'] = state;
      
      final response = await http.put(
        Uri.parse('$baseUrl/auth/profile'),
        headers: await authHeaders,
        body: jsonEncode(body),
      );
      
      return _handleResponse(response);
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }
  
  /// Logout from current device
  /// POST /auth/logout
  static Future<Map<String, dynamic>> logout() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/logout'),
        headers: await authHeaders,
      );
      
      final result = _handleResponse(response);
      
      // Delete token from local storage
      if (result['success'] == true) {
        await deleteToken();
      }
      
      return result;
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }
  
  /// Logout from all devices
  /// POST /auth/logout-all
  static Future<Map<String, dynamic>> logoutAll() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/logout-all'),
        headers: await authHeaders,
      );
      
      final result = _handleResponse(response);
      
      // Delete token from local storage
      if (result['success'] == true) {
        await deleteToken();
      }
      
      return result;
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }
  
  // ==================== Helper Methods ====================
  
  /// Handle HTTP response
  static Map<String, dynamic> _handleResponse(http.Response response) {
    try {
      final Map<String, dynamic> data = jsonDecode(response.body);
      
      // Handle different status codes
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return data;
      } else if (response.statusCode == 401) {
        // Unauthorized - token expired or invalid
        deleteToken(); // Clear invalid token
        return data;
      } else {
        return data;
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to parse response: ${e.toString()}',
      };
    }
  }
}
