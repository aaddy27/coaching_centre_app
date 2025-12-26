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
  
  /// Register new user - Step 1: Send OTP
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
  
  /// Verify Registration OTP - Step 2: Complete Registration
  /// POST /auth/verify-registration-otp
  static Future<Map<String, dynamic>> verifyRegistrationOtp({
    required String phone,
    required String otp,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/verify-registration-otp'),
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
  
  // ==================== Course APIs ====================
  
  /// Get All Courses (Public)
  /// GET /courses
  static Future<Map<String, dynamic>> getAllCourses() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/courses'),
        headers: headers,
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Connection timeout. Please check your internet connection.');
        },
      );
      
      return _handleResponse(response);
    } catch (e) {
      print('getAllCourses Error Details: $e');
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }
  
  /// Get Course Details by Slug (Public)
  /// GET /courses/{slug}
  static Future<Map<String, dynamic>> getCourseBySlug(String slug) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/courses/$slug'),
        headers: headers,
      );
      
      return _handleResponse(response);
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }
  
  /// Get My Enrolled Courses (Protected)
  /// GET /my-courses
  static Future<Map<String, dynamic>> getMyCourses() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/my-courses'),
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
  
  /// Get Course Subjects with Video Count (Protected)
  /// GET /courses/{courseId}/subjects
  static Future<Map<String, dynamic>> getCourseSubjects(int courseId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/courses/$courseId/subjects'),
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
  
  /// Get Course Videos (Protected)
  /// GET /courses/{courseId}/videos
  /// Note: API returns all videos for a course, we filter by subject on client side
  static Future<Map<String, dynamic>> getSubjectVideos({
    required int courseId,
    required int subjectId,
    String? filter, // unwatched, watched, in_progress
    String? sort, // order, duration, -duration, title
  }) async {
    try {
      // According to API docs, endpoint is /courses/{courseId}/videos
      String url = '$baseUrl/courses/$courseId/videos';
      
      // Add query parameters
      List<String> queryParams = [];
      if (filter != null) queryParams.add('filter=$filter');
      if (sort != null) queryParams.add('sort=$sort');
      
      if (queryParams.isNotEmpty) {
        url += '?${queryParams.join('&')}';
      }
      
      print('Fetching videos from: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: await authHeaders,
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Connection timeout');
        },
      );
      
      print('Videos API Response Status: ${response.statusCode}');
      
      final result = _handleResponse(response);
      
      // Filter videos by subject on client side
      if (result['success'] == true && result['data'] != null) {
        final videosData = result['data']['videos'] as List?;
        if (videosData != null) {
          // Filter videos that belong to this subject
          final filteredVideos = videosData.where((video) {
            final videoSubject = video['subject'];
            return videoSubject != null && videoSubject['id'] == subjectId;
          }).toList();
          
          print('Total videos: ${videosData.length}, Filtered for subject $subjectId: ${filteredVideos.length}');
          
          return {
            'success': true,
            'message': result['message'],
            'data': {
              'course': result['data']['course'],
              'videos': filteredVideos,
            },
          };
        }
      }
      
      return result;
    } catch (e) {
      print('getSubjectVideos Error: $e');
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }
  
  /// Get Course Curriculum (All subjects with videos) (Protected)
  /// GET /courses/{courseId}/curriculum
  static Future<Map<String, dynamic>> getCourseCurriculum(int courseId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/courses/$courseId/curriculum'),
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
  
  /// Get Subject Statistics (Protected)
  /// GET /courses/{courseId}/subjects/{subjectId}/stats
  static Future<Map<String, dynamic>> getSubjectStats({
    required int courseId,
    required int subjectId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/courses/$courseId/subjects/$subjectId/stats'),
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
  
  /// Search Videos in Subject (Protected)
  /// GET /courses/{courseId}/subjects/{subjectId}/videos/search
  static Future<Map<String, dynamic>> searchVideosInSubject({
    required int courseId,
    required int subjectId,
    required String query,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/courses/$courseId/subjects/$subjectId/videos/search?q=$query'),
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
  
  /// Stream Video (Protected)
  /// GET /videos/{videoId}/stream
  static Future<Map<String, dynamic>> streamVideo(int videoId) async {
    try {
      final url = '$baseUrl/videos/$videoId/stream';
      final headers = await authHeaders;
      
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('📹 Stream Video API Request');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('URL: $url');
      print('Method: GET');
      print('Headers: ${headers.keys.join(", ")}');
      print('Auth Token Present: ${headers['Authorization'] != null}');
      if (headers['Authorization'] != null) {
        final token = headers['Authorization']!;
        final maskedToken = token.length > 20 
            ? '${token.substring(0, 20)}...${token.substring(token.length - 10)}'
            : token;
        print('Authorization Header: $maskedToken');
      }
      
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Request timeout after 30 seconds');
        },
      );
      
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('📥 Stream Video API Response');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('Status Code: ${response.statusCode}');
      print('Response Body Length: ${response.body.length} bytes');
      print('Response Body Preview: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}...');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      
      final result = _handleResponse(response);
      
      if (result['success'] == false) {
        print('❌ API Error: ${result['message']}');
      } else {
        print('✅ API Success');
      }
      
      return result;
    } catch (e, stackTrace) {
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('❌ Stream Video Exception');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('Error: $e');
      print('Stack Trace: $stackTrace');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }
  
  /// Update Video Progress (Protected)
  /// POST /videos/{videoId}/progress
  static Future<Map<String, dynamic>> updateVideoProgress({
    required int videoId,
    required int progress, // 0-100
    required int watchedSeconds,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/videos/$videoId/progress'),
        headers: await authHeaders,
        body: jsonEncode({
          'progress': progress,
          'watched_seconds': watchedSeconds,
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
  
  // ==================== Test Series APIs ====================
  
  /// Get All Tests (Public)
  /// GET /tests
  static Future<Map<String, dynamic>> getAllTests() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/tests'),
        headers: headers,
      );
      
      return _handleResponse(response);
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }
  
  /// Get Test Details (Public)
  /// GET /tests/{testId}
  static Future<Map<String, dynamic>> getTestDetails(int testId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/tests/$testId'),
        headers: headers,
      );
      
      return _handleResponse(response);
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }
  
  /// Get My Test Attempts (Protected)
  /// GET /my-attempts
  static Future<Map<String, dynamic>> getMyAttempts() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/my-attempts'),
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
  
  /// Start Test Attempt (Protected)
  /// POST /tests/{testId}/start
  static Future<Map<String, dynamic>> startTest(int testId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/tests/$testId/start'),
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
