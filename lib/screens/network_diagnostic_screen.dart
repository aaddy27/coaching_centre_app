import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';

class NetworkDiagnosticScreen extends StatefulWidget {
  const NetworkDiagnosticScreen({Key? key}) : super(key: key);

  @override
  State<NetworkDiagnosticScreen> createState() => _NetworkDiagnosticScreenState();
}

class _NetworkDiagnosticScreenState extends State<NetworkDiagnosticScreen> {
  bool _isChecking = false;
  Map<String, dynamic> _results = {};

  @override
  void initState() {
    super.initState();
    _runDiagnostics();
  }

  Future<void> _runDiagnostics() async {
    setState(() {
      _isChecking = true;
      _results = {};
    });

    Map<String, dynamic> results = {};

    // 1. Check Internet Connectivity
    results['internet'] = await _checkInternetConnection();

    // 2. Check API Server Reachability
    results['server'] = await _checkServerReachability();

    // 3. Check API Endpoint
    results['api'] = await _checkApiEndpoint();

    setState(() {
      _results = results;
      _isChecking = false;
    });
  }

  Future<Map<String, dynamic>> _checkInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com').timeout(
        const Duration(seconds: 5),
      );
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        return {
          'status': 'success',
          'message': 'Internet connection is working',
        };
      }
    } catch (e) {
      return {
        'status': 'error',
        'message': 'No internet connection: ${e.toString()}',
      };
    }
    return {
      'status': 'error',
      'message': 'Unable to verify internet connection',
    };
  }

  Future<Map<String, dynamic>> _checkServerReachability() async {
    try {
      final uri = Uri.parse(ApiService.baseUrl);
      final result = await InternetAddress.lookup(uri.host).timeout(
        const Duration(seconds: 10),
      );
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        return {
          'status': 'success',
          'message': 'Server ${uri.host} is reachable',
        };
      }
    } catch (e) {
      return {
        'status': 'error',
        'message': 'Server unreachable: ${e.toString()}',
      };
    }
    return {
      'status': 'error',
      'message': 'Unable to reach server',
    };
  }

  Future<Map<String, dynamic>> _checkApiEndpoint() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/courses'),
        headers: ApiService.headers,
      ).timeout(
        const Duration(seconds: 15),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {
          'status': 'success',
          'message': 'API endpoint is working (Status: ${response.statusCode})',
          'details': 'Response length: ${response.body.length} bytes',
        };
      } else {
        return {
          'status': 'warning',
          'message': 'API returned status code: ${response.statusCode}',
          'details': response.body.substring(0, response.body.length > 200 ? 200 : response.body.length),
        };
      }
    } catch (e) {
      return {
        'status': 'error',
        'message': 'API endpoint failed: ${e.toString()}',
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text(
          'Network Diagnostics',
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
            onPressed: _isChecking ? null : _runDiagnostics,
          ),
        ],
      ),
      body: _isChecking
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6C5CE7)),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Running diagnostics...',
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildInfoCard(),
                const SizedBox(height: 16),
                _buildDiagnosticCard(
                  title: '1. Internet Connection',
                  result: _results['internet'],
                ),
                const SizedBox(height: 12),
                _buildDiagnosticCard(
                  title: '2. Server Reachability',
                  result: _results['server'],
                ),
                const SizedBox(height: 12),
                _buildDiagnosticCard(
                  title: '3. API Endpoint',
                  result: _results['api'],
                ),
                const SizedBox(height: 24),
                _buildRecommendations(),
              ],
            ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF6C5CE7).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF6C5CE7).withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline,
            color: Color(0xFF6C5CE7),
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'API Server',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6C5CE7),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  ApiService.baseUrl,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiagnosticCard({
    required String title,
    Map<String, dynamic>? result,
  }) {
    IconData icon;
    Color color;
    
    if (result == null) {
      icon = Icons.help_outline;
      color = Colors.grey;
    } else if (result['status'] == 'success') {
      icon = Icons.check_circle;
      color = Colors.green;
    } else if (result['status'] == 'warning') {
      icon = Icons.warning;
      color = Colors.orange;
    } else {
      icon = Icons.error;
      color = Colors.red;
    }

    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1F36),
                  ),
                ),
              ),
            ],
          ),
          if (result != null) ...[
            const SizedBox(height: 12),
            Text(
              result['message'] ?? 'No message',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
            if (result['details'] != null) ...[
              const SizedBox(height: 8),
              Text(
                result['details'],
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildRecommendations() {
    bool hasErrors = _results.values.any((r) => r['status'] == 'error');
    
    if (!hasErrors) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.green.withOpacity(0.3),
          ),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'All checks passed! Network is working properly.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.green,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.orange.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lightbulb_outline, color: Colors.orange),
              SizedBox(width: 12),
              Text(
                'Recommendations',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildRecommendationItem('Check your internet connection'),
          _buildRecommendationItem('Try switching between WiFi and mobile data'),
          _buildRecommendationItem('Restart your router if using WiFi'),
          _buildRecommendationItem('Contact support if the problem persists'),
        ],
      ),
    );
  }

  Widget _buildRecommendationItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 14)),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
