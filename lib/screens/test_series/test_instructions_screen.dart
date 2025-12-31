import 'package:flutter/material.dart';
import 'package:coaching/models/test_series_models.dart';
import 'package:coaching/services/api_service.dart';
import 'package:coaching/screens/test_series/test_questions_screen.dart';

class TestInstructionsScreen extends StatefulWidget {
  final int testId;
  final String testTitle;

  const TestInstructionsScreen({
    Key? key,
    required this.testId,
    required this.testTitle,
  }) : super(key: key);

  @override
  State<TestInstructionsScreen> createState() => _TestInstructionsScreenState();
}

class _TestInstructionsScreenState extends State<TestInstructionsScreen> {
  bool _isLoading = true;
  TestInSeries? _testDetails;
  String? _error;
  bool _acceptedInstructions = false;

  @override
  void initState() {
    super.initState();
    _fetchTestDetails();
  }

  Future<void> _fetchTestDetails() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Using getTestQuestions endpoint as per user logic to get instructions first
      // Or we could have a specific endpoint. Assuming getTestQuestions returns test details wrapper
      final response = await ApiService.getTestQuestions(widget.testId);

      if (response['success'] == true && response['data'] != null) {
        // Adjust based on your actual API response structure for test metadata
        final testData = response['data']['test'];
        if (testData != null) {
          setState(() {
            _testDetails = TestInSeries.fromJson(testData);
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _error = response['message'] ?? 'Failed to load instructions';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  void _startTest() {
    if (_testDetails != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => TestQuestionsScreen(
            testId: widget.testId,
            testTitle: widget.testTitle,
            duration: _testDetails!.duration,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.testTitle),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      backgroundColor: const Color(0xFFF8F9FD),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoCard(),
                        const SizedBox(height: 24),
                        const Text(
                          'Instructions',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.grey.withOpacity(0.2),
                            ),
                          ),
                          child: Text(
                            _testDetails?.instructions ??
                                '1. Read all questions carefully.\n2. Each question carries marks as indicated.\n3. Negative marking allows deduction for wrong answers.\n4. Do not minimize the app during the test.',
                            style: const TextStyle(
                              fontSize: 15,
                              height: 1.6,
                              color: Color(0xFF334155),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Transform.scale(
                            scale: 1.2,
                            child: Checkbox(
                              value: _acceptedInstructions,
                              onChanged: (val) {
                                setState(
                                  () => _acceptedInstructions = val ?? false,
                                );
                              },
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              activeColor: const Color(0xFF6366F1),
                            ),
                          ),
                          const Expanded(
                            child: Text(
                              'I have read and understood the instructions',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _acceptedInstructions ? _startTest : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6366F1),
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.grey[200],
                            disabledForegroundColor: Colors.grey,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'START TEST',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildInfoItem(
                Icons.timer,
                '${_testDetails?.duration} mins',
                'Duration',
              ),
              Container(
                width: 1,
                height: 40,
                color: Colors.white.withOpacity(0.2),
              ),
              _buildInfoItem(
                Icons.analytics,
                '${_testDetails?.totalMarks}',
                'Marks',
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white24),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildInfoItem(
                Icons.quiz,
                '${_testDetails?.questionsCount}',
                'Questions',
              ),
              Container(
                width: 1,
                height: 40,
                color: Colors.white.withOpacity(0.2),
              ),
              _buildInfoItem(
                Icons.remove_circle_outline,
                '-${_testDetails?.negativeMarking}',
                'Neg. Mark',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
        ),
      ],
    );
  }
}
