import 'package:flutter/material.dart';
import 'package:coaching/models/test_series_models.dart';
import 'package:coaching/services/api_service.dart';
import 'package:coaching/screens/test_series/test_instructions_screen.dart';

class SubjectTestsScreen extends StatefulWidget {
  final int testSeriesId;
  final int subjectId;
  final String title;
  final String seriesTitle;

  const SubjectTestsScreen({
    Key? key,
    required this.testSeriesId,
    required this.subjectId,
    required this.title,
    required this.seriesTitle,
  }) : super(key: key);

  @override
  State<SubjectTestsScreen> createState() => _SubjectTestsScreenState();
}

class _SubjectTestsScreenState extends State<SubjectTestsScreen> {
  bool _isLoading = true;
  List<TestInSeries> _tests = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchTests();
  }

  Future<void> _fetchTests() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final response = await ApiService.getSubjectTests(
        testSeriesId: widget.testSeriesId,
        subjectId: widget.subjectId,
      );

      if (response['success'] == true && response['data'] != null) {
        final List<dynamic> list = response['data']['tests'] ?? [];
        setState(() {
          _tests = list.map((e) => TestInSeries.fromJson(e)).toList();
          _isLoading = false;
        });
      } else if (response['requires_purchase'] == true) {
        setState(() {
          _error = 'Purchase required';
          _isLoading = false;
        });
        // Optionally navigate back or show purchase dialog
      } else {
        setState(() {
          _error = response['message'] ?? 'Failed to load tests';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title),
            Text(
              widget.seriesTitle,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      backgroundColor: const Color(0xFFF8F9FD),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _fetchTests,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _tests.length,
              itemBuilder: (context, index) {
                final test = _tests[index];
                return _buildTestCard(test);
              },
            ),
    );
  }

  Widget _buildTestCard(TestInSeries test) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${test.testNumber}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      test.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildInfoBadge(Icons.timer_outlined, '${test.duration} mins'),
                _buildInfoBadge(
                  Icons.analytics_outlined,
                  '${test.totalMarks} marks',
                ),
                _buildInfoBadge(
                  Icons.quiz_outlined,
                  '${test.questionsCount} Qs',
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TestInstructionsScreen(
                        testId: test.id,
                        testTitle: test.title,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text('Start Test'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBadge(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[700],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
