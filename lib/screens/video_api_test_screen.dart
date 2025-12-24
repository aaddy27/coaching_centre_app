import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'dart:convert';

class VideoApiTestScreen extends StatefulWidget {
  const VideoApiTestScreen({Key? key}) : super(key: key);

  @override
  State<VideoApiTestScreen> createState() => _VideoApiTestScreenState();
}

class _VideoApiTestScreenState extends State<VideoApiTestScreen> {
  final TextEditingController _videoIdController = TextEditingController(text: '1');
  String _response = 'Enter a video ID and press "Test Video Stream API"';
  bool _isLoading = false;
  String? _authToken;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final token = await ApiService.getToken();
    final loggedIn = await ApiService.isLoggedIn();
    setState(() {
      _authToken = token;
      _isLoggedIn = loggedIn;
    });
  }

  Future<void> _testVideoStreamApi() async {
    final videoId = int.tryParse(_videoIdController.text);
    
    if (videoId == null) {
      setState(() {
        _response = 'Error: Please enter a valid video ID (number)';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _response = 'Testing video stream API...\n\n';
    });

    try {
      // Add detailed logging
      _appendResponse('📋 Test Details:');
      _appendResponse('Video ID: $videoId');
      _appendResponse('API Endpoint: ${ApiService.baseUrl}/videos/$videoId/stream');
      _appendResponse('Auth Token: ${_authToken != null ? "✅ Present (${_authToken!.substring(0, 20)}...)" : "❌ Missing"}');
      _appendResponse('Logged In: ${_isLoggedIn ? "✅ Yes" : "❌ No"}');
      _appendResponse('\n🔄 Making API Request...\n');

      final response = await ApiService.streamVideo(videoId);
      
      // Pretty print JSON
      const encoder = JsonEncoder.withIndent('  ');
      final prettyJson = encoder.convert(response);
      
      _appendResponse('📥 API Response:');
      _appendResponse(prettyJson);
      
      // Analyze response
      _appendResponse('\n📊 Response Analysis:');
      if (response['success'] == true) {
        _appendResponse('✅ Success: true');
        if (response['data'] != null) {
          final videoData = response['data']['video'];
          _appendResponse('✅ Video Data Found');
          _appendResponse('   - Video Type: ${videoData?['video_type']}');
          _appendResponse('   - Vimeo ID: ${videoData?['vimeo_id']}');
          _appendResponse('   - YouTube ID: ${videoData?['youtube_id']}');
          _appendResponse('   - Video URL: ${videoData?['video_url']}');
        }
      } else {
        _appendResponse('❌ Success: false');
        _appendResponse('❌ Error Message: ${response['message']}');
        
        // Check for common errors
        if (response['message']?.toString().contains('Unauthenticated') == true) {
          _appendResponse('\n⚠️ Authentication Error Detected!');
          _appendResponse('   - You need to login first');
          _appendResponse('   - Token might be expired or invalid');
        } else if (response['message']?.toString().contains('not found') == true) {
          _appendResponse('\n⚠️ Video Not Found!');
          _appendResponse('   - Video ID $videoId does not exist');
          _appendResponse('   - Try a different video ID');
        } else if (response['message']?.toString().contains('not enrolled') == true) {
          _appendResponse('\n⚠️ Enrollment Required!');
          _appendResponse('   - You need to enroll in the course first');
        }
      }
      
      setState(() {
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      _appendResponse('\n❌ Exception Occurred:');
      _appendResponse('Error: $e');
      _appendResponse('\nStack Trace:');
      _appendResponse(stackTrace.toString());
      
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _appendResponse(String text) {
    setState(() {
      _response += '$text\n';
    });
  }

  Future<void> _testMultipleVideos() async {
    setState(() {
      _isLoading = true;
      _response = '🔄 Testing Multiple Video IDs...\n\n';
    });

    final videoIds = [1, 2, 3, 5, 10]; // Test different IDs
    
    for (final videoId in videoIds) {
      _appendResponse('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      _appendResponse('Testing Video ID: $videoId');
      _appendResponse('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
      
      try {
        final response = await ApiService.streamVideo(videoId);
        
        if (response['success'] == true) {
          _appendResponse('✅ Video $videoId: SUCCESS');
          final videoData = response['data']?['video'];
          if (videoData != null) {
            _appendResponse('   Type: ${videoData['video_type']}');
            _appendResponse('   Title: ${videoData['title'] ?? 'N/A'}');
          }
        } else {
          _appendResponse('❌ Video $videoId: FAILED');
          _appendResponse('   Error: ${response['message']}');
        }
      } catch (e) {
        _appendResponse('❌ Video $videoId: EXCEPTION');
        _appendResponse('   Error: $e');
      }
      
      _appendResponse('');
      
      // Small delay between requests
      await Future.delayed(const Duration(milliseconds: 500));
    }
    
    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text(
          'Video Stream API Test',
          style: TextStyle(
            color: Color(0xFF1A1F36),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF1A1F36)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _checkAuth,
            tooltip: 'Refresh Auth Status',
          ),
        ],
      ),
      body: Column(
        children: [
          // Auth Status Card
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _isLoggedIn ? Colors.green.shade50 : Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isLoggedIn ? Colors.green : Colors.red,
                width: 2,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _isLoggedIn ? Icons.check_circle : Icons.error,
                  color: _isLoggedIn ? Colors.green : Colors.red,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isLoggedIn ? 'Logged In' : 'Not Logged In',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _isLoggedIn ? Colors.green.shade900 : Colors.red.shade900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _authToken != null 
                            ? 'Token: ${_authToken!.substring(0, 20)}...'
                            : 'No authentication token found',
                        style: TextStyle(
                          fontSize: 12,
                          color: _isLoggedIn ? Colors.green.shade700 : Colors.red.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Video ID Input
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _videoIdController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Video ID',
                hintText: 'Enter video ID to test',
                prefixIcon: const Icon(Icons.video_library),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Test Buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _testVideoStreamApi,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.play_arrow),
                    label: const Text('Test Single Video'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C5CE7),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _testMultipleVideos,
                    icon: const Icon(Icons.playlist_play),
                    label: const Text('Test Multiple'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00B894),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Response Display
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  _response,
                  style: const TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                    color: Color(0xFF1A1F36),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _videoIdController.dispose();
    super.dispose();
  }
}
