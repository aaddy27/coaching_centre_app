import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class ApiService {
  // Base URL - Production
  static const String baseUrl = 'https://eduapp.hkrdn.in/api/v1';

  // Secure storage for token
  static const storage = FlutterSecureStorage();
  static const Duration _timeout = Duration(seconds: 30);

  // Common headers
  static Map<String, String> get headers => const {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  // Headers with authentication token (required)
  static Future<Map<String, String>> get authHeaders async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  // Headers with optional authentication token (for catalog / public endpoints)
  static Future<Map<String, String>> get optionalAuthHeaders async {
    return authHeaders;
  }

  // ==================== Token Management ====================

  static Future<void> saveToken(String token) async {
    await storage.write(key: 'auth_token', value: token);
  }

  static Future<String?> getToken() async {
    return await storage.read(key: 'auth_token');
  }

  static Future<void> deleteToken() async {
    await storage.delete(key: 'auth_token');
    await storage.delete(key: _attemptedTestsStorageKey);
    await storage.delete(key: _videoProgressStorageKey);
    await storage.delete(key: _courseProgressStorageKey);
    await storage.delete(key: _courseLastVideoStorageKey);
    await storage.delete(key: _lastWatchedVideoStorageKey);
  }

  static const String _videoProgressStorageKey = 'video_progress_v1';
  static const String _courseProgressStorageKey = 'course_progress_v1';
  static const String _courseLastVideoStorageKey = 'course_last_video_v1';
  static const String _lastWatchedVideoStorageKey = 'last_watched_video_v1';

  static Future<Map<int, Map<String, dynamic>>> getLocalVideoProgressMap() async {
    try {
      final raw = await storage.read(key: _videoProgressStorageKey);
      if (raw == null || raw.isEmpty) return {};
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      final result = <int, Map<String, dynamic>>{};
      decoded.forEach((k, v) {
        final id = int.tryParse(k.toString());
        if (id != null && id > 0 && v is Map) {
          result[id] = Map<String, dynamic>.from(v);
        }
      });
      return result;
    } catch (_) {
      return {};
    }
  }

  static Future<void> saveLocalVideoProgress({
    required int videoId,
    required int progress,
    required int watchedSeconds,
    bool? completed,
    int? courseId,
    String? courseTitle,
    Map<String, dynamic>? videoJson,
    bool syncRemote = true,
  }) async {
    if (videoId <= 0) return;
    final clampedProgress = progress.clamp(0, 100);
    final map = await getLocalVideoProgressMap();
    final existing = map[videoId];
    final bool wasCompleted = existing?['completed'] == true;
    final int prevProgress =
        existing?['progress'] is int ? existing!['progress'] as int : 0;
    final bool isCompleted =
        completed ?? (wasCompleted || clampedProgress >= 90);
    final int finalProgress = isCompleted
        ? 100
        : (clampedProgress > prevProgress ? clampedProgress : prevProgress);

    final nowIso = DateTime.now().toIso8601String();
    map[videoId] = {
      'progress': finalProgress,
      'watched_seconds': watchedSeconds,
      'completed': isCompleted,
      'updated_at': nowIso,
    };

    await storage.write(
      key: _videoProgressStorageKey,
      value: jsonEncode(map.map((k, v) => MapEntry(k.toString(), v))),
    );

    if (videoJson != null) {
      await storage.write(
        key: _lastWatchedVideoStorageKey,
        value: jsonEncode({
          'video': {
            ...videoJson,
            'watch_progress': finalProgress,
            'watched_seconds': watchedSeconds,
            'is_watched': isCompleted,
          },
          'course_id': courseId,
          'course_title': courseTitle,
          'watched_seconds': watchedSeconds,
          'progress': finalProgress,
          'completed': isCompleted,
          'updated_at': nowIso,
        }),
      );
    }

    if (courseId != null && courseId > 0) {
      await saveCourseLastVideoId(courseId, videoId);
    }

    if (syncRemote && await isLoggedIn()) {
      updateVideoProgress(
        videoId: videoId,
        progress: finalProgress,
        watchedSeconds: watchedSeconds,
      ).catchError((_) => <String, dynamic>{'success': false});
    }
  }

  static Future<Map<String, dynamic>?> getLastWatchedVideo() async {
    try {
      final raw = await storage.read(key: _lastWatchedVideoStorageKey);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic> && decoded['video'] is Map) {
        return decoded;
      }
    } catch (_) {}
    return null;
  }

  static Future<void> dismissLastWatchedVideo() async {
    try {
      await storage.delete(key: _lastWatchedVideoStorageKey);
    } catch (_) {}
  }

  static Future<void> saveCourseLastVideoId(int courseId, int videoId) async {
    if (courseId <= 0 || videoId <= 0) return;
    try {
      final raw = await storage.read(key: _courseLastVideoStorageKey);
      final Map<String, dynamic> data =
          (raw != null && raw.isNotEmpty) ? jsonDecode(raw) : {};
      data[courseId.toString()] = videoId;
      await storage.write(
        key: _courseLastVideoStorageKey,
        value: jsonEncode(data),
      );
    } catch (_) {}
  }

  static Future<int?> getCourseLastVideoId(int courseId) async {
    if (courseId <= 0) return null;
    try {
      final raw = await storage.read(key: _courseLastVideoStorageKey);
      if (raw == null || raw.isEmpty) return null;
      final data = jsonDecode(raw);
      if (data is Map) {
        final v = data[courseId.toString()];
        return v is int ? v : int.tryParse('${v ?? ''}');
      }
    } catch (_) {}
    return null;
  }

  static Future<void> saveCourseProgressSummary({
    required int courseId,
    required int completedVideos,
    required int totalVideos,
  }) async {
    if (courseId <= 0 || totalVideos <= 0) return;
    try {
      final raw = await storage.read(key: _courseProgressStorageKey);
      final Map<String, dynamic> data =
          (raw != null && raw.isNotEmpty) ? jsonDecode(raw) : {};
      final pct = ((completedVideos / totalVideos) * 100).round().clamp(0, 100);
      data[courseId.toString()] = {
        'progress': pct,
        'completed_videos': completedVideos,
        'total_videos': totalVideos,
      };
      await storage.write(
        key: _courseProgressStorageKey,
        value: jsonEncode(data),
      );
    } catch (_) {}
  }

  static Future<Map<int, Map<String, int>>> getCourseProgressSummaryMap() async {
    try {
      final raw = await storage.read(key: _courseProgressStorageKey);
      if (raw == null || raw.isEmpty) return {};
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      final out = <int, Map<String, int>>{};
      decoded.forEach((k, v) {
        final cid = int.tryParse(k.toString());
        if (cid != null && v is Map) {
          out[cid] = {
            'progress': int.tryParse('${v['progress'] ?? 0}') ?? 0,
            'completed_videos':
                int.tryParse('${v['completed_videos'] ?? 0}') ?? 0,
            'total_videos': int.tryParse('${v['total_videos'] ?? 0}') ?? 0,
          };
        }
      });
      return out;
    } catch (_) {
      return {};
    }
  }

  static const String _attemptedTestsStorageKey = 'attempted_tests_v1';

  static Future<Map<int, int>> getLocalAttemptedTests() async {
    try {
      final raw = await storage.read(key: _attemptedTestsStorageKey);
      if (raw == null || raw.isEmpty) return {};
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      final result = <int, int>{};
      decoded.forEach((k, v) {
        final testId = int.tryParse(k.toString());
        final attemptId = int.tryParse(v.toString()) ?? 0;
        if (testId != null && testId > 0) {
          result[testId] = attemptId;
        }
      });
      return result;
    } catch (_) {
      return {};
    }
  }

  static Future<void> markTestAttempted(int testId, {int? attemptId}) async {
    if (testId <= 0) return;
    final current = await getLocalAttemptedTests();
    final existingAttemptId = current[testId] ?? 0;
    current[testId] = (attemptId != null && attemptId > 0)
        ? attemptId
        : existingAttemptId;
    final encoded = jsonEncode(
      current.map((k, v) => MapEntry(k.toString(), v)),
    );
    await storage.write(key: _attemptedTestsStorageKey, value: encoded);
  }

  /// Combines server `/my-attempts` and local lock so each test can only be taken once.
  static Future<Map<int, int>> getAttemptedTestsMap() async {
    final map = await getLocalAttemptedTests();
    if (!await isLoggedIn()) return map;

    try {
      final res = await getMyAttempts();
      if (res['success'] == true && res['data'] != null) {
        final raw = res['data'];
        final List list = raw is List
            ? raw
            : (raw is Map && raw['data'] is List
                ? raw['data']
                : (raw is Map && raw['attempts'] is List
                    ? raw['attempts']
                    : []));
        for (final item in list) {
          if (item is! Map) continue;
          final testIdRaw = item['test_id'] ??
              (item['test'] is Map ? item['test']['id'] : null);
          final attemptIdRaw = item['attempt_id'] ?? item['id'];
          final testId = testIdRaw is int
              ? testIdRaw
              : int.tryParse('${testIdRaw ?? ''}');
          final attemptId = attemptIdRaw is int
              ? attemptIdRaw
              : int.tryParse('${attemptIdRaw ?? 0}') ?? 0;
          if (testId != null && testId > 0) {
            final existing = map[testId] ?? 0;
            map[testId] = attemptId > 0 ? attemptId : existing;
          }
        }
      }
    } catch (_) {
      // Keep local lock if network fails
    }
    return map;
  }

  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  /// Formats validation / API errors into a single readable message.
  static String extractErrorMessage(
    Map<String, dynamic> response, {
    String fallback = 'Something went wrong. Please try again.',
  }) {
    if (response['errors'] is Map) {
      final errors = response['errors'] as Map;
      final messages = <String>[];
      for (final value in errors.values) {
        if (value is List && value.isNotEmpty) {
          messages.addAll(value.map((e) => e.toString()));
        } else if (value != null) {
          messages.add(value.toString());
        }
      }
      if (messages.isNotEmpty) {
        return messages.join('\n');
      }
    }
    final msg = response['message']?.toString();
    if (msg != null && msg.isNotEmpty) return msg;
    return fallback;
  }

  // ==================== 1. Authentication & Account ====================

  /// 1.1 Register - Step 1: Send OTP
  /// POST /auth/register
  static Future<Map<String, dynamic>> register({
    required String name,
    required String phone,
    required String password,
    required String passwordConfirmation,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/register'),
            headers: headers,
            body: jsonEncode({
              'name': name,
              'phone': phone,
              'password': password,
              'password_confirmation': passwordConfirmation,
            }),
          )
          .timeout(_timeout);

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  /// 1.2 Register - Step 2: Verify OTP & Complete Account
  /// POST /auth/verify-registration-otp
  static Future<Map<String, dynamic>> verifyRegistrationOtp({
    required String phone,
    required String otp,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/verify-registration-otp'),
            headers: headers,
            body: jsonEncode({'phone': phone, 'otp': otp}),
          )
          .timeout(_timeout);

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  /// 1.3 Password Login
  /// POST /auth/login
  static Future<Map<String, dynamic>> login({
    required String phone,
    required String password,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/login'),
            headers: headers,
            body: jsonEncode({'phone': phone, 'password': password}),
          )
          .timeout(_timeout);

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  /// 1.4 OTP Login - Step 1: Request Login OTP
  /// POST /auth/login-otp
  static Future<Map<String, dynamic>> requestLoginOtp({
    required String phone,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/login-otp'),
            headers: headers,
            body: jsonEncode({'phone': phone}),
          )
          .timeout(_timeout);

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  /// 1.5 OTP Login - Step 2: Verify Login OTP
  /// POST /auth/verify-login-otp
  static Future<Map<String, dynamic>> verifyLoginOtp({
    required String phone,
    required String otp,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/verify-login-otp'),
            headers: headers,
            body: jsonEncode({'phone': phone, 'otp': otp}),
          )
          .timeout(_timeout);

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  /// 1.6 Forgot Password - Step 1: Send Reset OTP
  /// POST /auth/forgot-password
  static Future<Map<String, dynamic>> forgotPassword({
    required String phone,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/forgot-password'),
            headers: headers,
            body: jsonEncode({'phone': phone}),
          )
          .timeout(_timeout);

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  /// 1.6 Forgot Password - Step 2: Verify Reset OTP
  /// POST /auth/verify-otp
  static Future<Map<String, dynamic>> verifyOtp({
    required String phone,
    required String otp,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/verify-otp'),
            headers: headers,
            body: jsonEncode({'phone': phone, 'otp': otp}),
          )
          .timeout(_timeout);

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  /// 1.6 Forgot Password - Step 3: Set New Password
  /// POST /auth/reset-password
  static Future<Map<String, dynamic>> resetPassword({
    required String phone,
    required String resetToken,
    required String password,
    required String passwordConfirmation,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/reset-password'),
            headers: headers,
            body: jsonEncode({
              'phone': phone,
              'reset_token': resetToken,
              'password': password,
              'password_confirmation': passwordConfirmation,
            }),
          )
          .timeout(_timeout);

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  /// 1.7 Change Password (Protected)
  /// POST /auth/change-password
  static Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String password,
    required String passwordConfirmation,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/change-password'),
            headers: await authHeaders,
            body: jsonEncode({
              'current_password': currentPassword,
              'password': password,
              'password_confirmation': passwordConfirmation,
            }),
          )
          .timeout(_timeout);

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  /// 1.7 Get User Profile (Protected)
  /// GET /auth/profile
  static Future<Map<String, dynamic>> getProfile() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/auth/profile'), headers: await authHeaders)
          .timeout(_timeout);

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  /// 1.7 Update User Profile (Protected)
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

      final response = await http
          .put(
            Uri.parse('$baseUrl/auth/profile'),
            headers: await authHeaders,
            body: jsonEncode(body),
          )
          .timeout(_timeout);

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  /// 1.7 Logout current device
  /// POST /auth/logout
  static Future<Map<String, dynamic>> logout() async {
    try {
      final response = await http
          .post(Uri.parse('$baseUrl/auth/logout'), headers: await authHeaders)
          .timeout(_timeout);

      final result = _handleResponse(response);
      await deleteToken();
      return result;
    } catch (e) {
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  /// 1.7 Logout from all devices
  /// POST /auth/logout-all
  static Future<Map<String, dynamic>> logoutAll() async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/logout-all'),
            headers: await authHeaders,
          )
          .timeout(_timeout);

      final result = _handleResponse(response);
      await deleteToken();
      return result;
    } catch (e) {
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  // ==================== 2. Courses & Curriculum ====================

  /// 2.1 Get All Courses (Catalog)
  /// GET /courses
  static Future<Map<String, dynamic>> getAllCourses({
    int? examId,
    int? subjectId,
    String? search,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (examId != null) queryParams['exam_id'] = examId.toString();
      if (subjectId != null) queryParams['subject_id'] = subjectId.toString();
      if (search != null && search.trim().isNotEmpty) {
        queryParams['search'] = search.trim();
      }

      final uri = Uri.parse(
        '$baseUrl/courses',
      ).replace(queryParameters: queryParams.isEmpty ? null : queryParams);

      final response = await http
          .get(uri, headers: await optionalAuthHeaders)
          .timeout(_timeout);

      return _handleResponse(response);
    } catch (e) {
      debugPrint('getAllCourses Error: $e');
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  /// 2.2 Get Course Detail by Slug
  /// GET /courses/{slug}
  static Future<Map<String, dynamic>> getCourseBySlug(String slug) async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/courses/$slug'),
            headers: await optionalAuthHeaders,
          )
          .timeout(_timeout);

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  /// 2.3 Get Course Videos with Lock Status
  /// GET /courses/{id}/videos
  static Future<Map<String, dynamic>> getCourseVideos(
    int courseId, {
    String? filter,
    String? sort,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (filter != null) queryParams['filter'] = filter;
      if (sort != null) queryParams['sort'] = sort;

      final uri = Uri.parse(
        '$baseUrl/courses/$courseId/videos',
      ).replace(queryParameters: queryParams.isEmpty ? null : queryParams);

      final response = await http
          .get(uri, headers: await optionalAuthHeaders)
          .timeout(_timeout);

      return _handleResponse(response);
    } catch (e) {
      debugPrint('getCourseVideos Error: $e');
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  /// Get Subject Videos (uses /courses/{courseId}/videos and filters by subject if present)
  static Future<Map<String, dynamic>> getSubjectVideos({
    required int courseId,
    required int subjectId,
    String? filter,
    String? sort,
  }) async {
    final result = await getCourseVideos(courseId, filter: filter, sort: sort);
    if (result['success'] == true && result['data'] != null) {
      final data = result['data'];
      final videosData = data['videos'] as List?;
      if (videosData != null) {
        final hasSubjectTag = videosData.any(
          (v) => v is Map && (v['subject'] != null || v['subject_id'] != null),
        );

        final filteredVideos = hasSubjectTag
            ? videosData.where((video) {
                if (video is! Map) return false;
                final videoSubject = video['subject'];
                final sid = videoSubject is Map
                    ? videoSubject['id']
                    : video['subject_id'];
                return sid == subjectId;
              }).toList()
            : videosData;

        return {
          'success': true,
          'message': result['message'],
          'data': {
            'course_id': data['course_id'] ?? courseId,
            'course_title': data['course_title'],
            'has_purchased': data['has_purchased'] ?? false,
            'course': data['course'],
            'videos': filteredVideos,
          },
        };
      }
    }
    return result;
  }

  /// 2.4 Get My Enrolled Courses (Protected)
  /// GET /my-courses
  static Future<Map<String, dynamic>> getMyCourses() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/my-courses'), headers: await authHeaders)
          .timeout(_timeout);

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  /// Get Course Subjects with Video Count
  /// GET /courses/{courseId}/subjects
  static Future<Map<String, dynamic>> getCourseSubjects(int courseId) async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/courses/$courseId/subjects'),
            headers: await optionalAuthHeaders,
          )
          .timeout(_timeout);

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  /// Get Course Curriculum
  /// GET /courses/{courseId}/curriculum
  static Future<Map<String, dynamic>> getCourseCurriculum(int courseId) async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/courses/$courseId/curriculum'),
            headers: await optionalAuthHeaders,
          )
          .timeout(_timeout);

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  // ==================== 3. Video Streaming & Playback ====================

  /// 3.1 Stream Video (Access Check - Protected)
  /// GET /videos/{id}/stream
  static Future<Map<String, dynamic>> streamVideo(int videoId) async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/videos/$videoId/stream'),
            headers: await authHeaders,
          )
          .timeout(_timeout);

      return _handleResponse(response);
    } catch (e) {
      debugPrint('streamVideo Error: $e');
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  /// Update Video Progress (Protected)
  /// POST /videos/{videoId}/progress
  static Future<Map<String, dynamic>> updateVideoProgress({
    required int videoId,
    required int progress,
    required int watchedSeconds,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/videos/$videoId/progress'),
            headers: await authHeaders,
            body: jsonEncode({
              'progress': progress,
              'watched_seconds': watchedSeconds,
            }),
          )
          .timeout(_timeout);

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  // ==================== 4. Test Series & Assessments Engine ====================

  /// 4.1 Get All Test Series
  /// GET /test-series
  static Future<Map<String, dynamic>> getTestSeriesList({int? courseId}) async {
    try {
      final uri = Uri.parse('$baseUrl/test-series').replace(
        queryParameters: courseId != null
            ? {'course_id': courseId.toString()}
            : null,
      );

      final response = await http
          .get(uri, headers: await optionalAuthHeaders)
          .timeout(_timeout);

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  /// 4.2 Get Test Series Detail
  /// GET /test-series/{id}
  static Future<Map<String, dynamic>> getTestSeriesDetail(int id) async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/test-series/$id'),
            headers: await optionalAuthHeaders,
          )
          .timeout(_timeout);

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  /// 4.3 Get Subjects in a Test Series
  /// GET /test-series/{testId}/subjects
  static Future<Map<String, dynamic>> getTestSeriesSubjects(int testId) async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/test-series/$testId/subjects'),
            headers: await optionalAuthHeaders,
          )
          .timeout(_timeout);

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  /// 4.4 Get Child Tests for a Subject
  /// GET /test-series/{testId}/subjects/{subjectId}/tests
  static Future<Map<String, dynamic>> getSubjectTests({
    required int testSeriesId,
    required int subjectId,
  }) async {
    try {
      final response = await http
          .get(
            Uri.parse(
              '$baseUrl/test-series/$testSeriesId/subjects/$subjectId/tests',
            ),
            headers: await optionalAuthHeaders,
          )
          .timeout(_timeout);

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  /// 4.5 Get Questions for a Test (Protected)
  /// GET /tests/{testId}/questions
  static Future<Map<String, dynamic>> getTestQuestions(int testId) async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/tests/$testId/questions'),
            headers: await authHeaders,
          )
          .timeout(_timeout);

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  /// 4.6 Start Test Attempt (Protected)
  /// POST /tests/{id}/start
  static Future<Map<String, dynamic>> startTest(int testId) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/tests/$testId/start'),
            headers: await authHeaders,
          )
          .timeout(_timeout);

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  /// 4.7 Save Answer in Real-Time (Protected)
  /// POST /attempts/{id}/answer
  static Future<Map<String, dynamic>> saveAttemptAnswer({
    required int attemptId,
    required int questionId,
    required String answer,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/attempts/$attemptId/answer'),
            headers: await authHeaders,
            body: jsonEncode({'question_id': questionId, 'answer': answer}),
          )
          .timeout(_timeout);

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  /// 4.8 Submit / Finish Test (Protected)
  /// POST /attempts/{id}/finish
  static Future<Map<String, dynamic>> finishTestAttempt(int attemptId) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/attempts/$attemptId/finish'),
            headers: await authHeaders,
          )
          .timeout(_timeout);

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  /// 4.9 Get Detailed Scorecard / Report (Protected)
  /// GET /attempts/{id}/report
  static Future<Map<String, dynamic>> getAttemptReport(int attemptId) async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/attempts/$attemptId/report'),
            headers: await authHeaders,
          )
          .timeout(_timeout);

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  /// 4.10 Get My Test History (Protected)
  /// GET /my-attempts
  static Future<Map<String, dynamic>> getMyAttempts() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/my-attempts'), headers: await authHeaders)
          .timeout(_timeout);

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  /// Get All Tests (for Home preview)
  /// GET /tests
  static Future<Map<String, dynamic>> getAllTests() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/tests'), headers: await optionalAuthHeaders)
          .timeout(_timeout);

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  /// Get Test Details
  /// GET /tests/{testId}
  static Future<Map<String, dynamic>> getTestDetails(int testId) async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/tests/$testId'),
            headers: await optionalAuthHeaders,
          )
          .timeout(_timeout);

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  // ==================== 5. Purchases & Checkout Flow ====================

  /// 5.1 Initiate Purchase / Create Order (Protected)
  /// POST /purchase
  /// purchasableType: 'course' or 'test'
  static Future<Map<String, dynamic>> initiatePurchase({
    required String purchasableType,
    required int purchasableId,
    String paymentProvider = 'razorpay',
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/purchase'),
            headers: await authHeaders,
            body: jsonEncode({
              'purchasable_type': purchasableType,
              'purchasable_id': purchasableId,
              'payment_provider': paymentProvider,
            }),
          )
          .timeout(_timeout);

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  /// 5.2 Verify Payment Gateway Callback (Protected)
  /// POST /payment/verify
  static Future<Map<String, dynamic>> verifyPayment({
    required String orderId,
    required String paymentId,
    String? signature,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/payment/verify'),
            headers: await authHeaders,
            body: jsonEncode({
              'order_id': orderId,
              'payment_id': paymentId,
              if (signature != null && signature.isNotEmpty)
                'signature': signature,
            }),
          )
          .timeout(_timeout);

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  /// 5.3 Get My Purchase History (Protected)
  /// GET /my-purchases
  static Future<Map<String, dynamic>> getMyPurchases() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/my-purchases'), headers: await authHeaders)
          .timeout(_timeout);

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  // ==================== Response Handler ====================

  static Map<String, dynamic> _handleResponse(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      final Map<String, dynamic> data = decoded is Map<String, dynamic>
          ? decoded
          : {'success': response.statusCode < 300, 'data': decoded};

      data['status_code'] = response.statusCode;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        data['success'] ??= true;
        return data;
      }

      if (response.statusCode == 401) {
        deleteToken();
      }

      data['success'] ??= false;
      return data;
    } catch (e) {
      return {
        'success': false,
        'status_code': response.statusCode,
        'message': 'Failed to parse response (${response.statusCode})',
      };
    }
  }
}
