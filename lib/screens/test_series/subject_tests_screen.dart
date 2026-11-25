import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../models/test_series_models.dart';
import '../../services/api_service.dart';
import '../../widgets/ios_components.dart';
import 'test_instructions_screen.dart';

class SubjectTestsScreen extends StatefulWidget {
  final int testSeriesId;
  final int subjectId;
  final String title;
  final String seriesTitle;

  const SubjectTestsScreen({
    super.key,
    required this.testSeriesId,
    required this.subjectId,
    required this.title,
    required this.seriesTitle,
  });

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
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await ApiService.getSubjectTests(
        testSeriesId: widget.testSeriesId,
        subjectId: widget.subjectId,
      );

      if (!mounted) return;

      if (response['success'] == true && response['data'] != null) {
        final List<dynamic> list = response['data']['tests'] ?? [];
        setState(() {
          _tests = list.map((e) => TestInSeries.fromJson(e)).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = ApiService.extractErrorMessage(
            response,
            fallback: 'Failed to load mock tests.',
          );
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Network error: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IosTheme.groupedBg,
      appBar: IosNavBar(title: widget.title, subtitle: widget.seriesTitle),
      body: _isLoading
          ? const Center(child: CupertinoActivityIndicator(radius: 14))
          : _error != null
              ? _buildError()
              : _tests.isEmpty
                  ? const Center(
                      child: Text(
                        'No mock papers available yet.',
                        style: TextStyle(color: IosTheme.labelTertiary),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchTests,
                      color: IosTheme.primaryBlue,
                      child: ListView.builder(
                        physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                        padding: const EdgeInsets.all(16),
                        itemCount: _tests.length,
                        itemBuilder: (context, index) =>
                            _buildTestCard(_tests[index]),
                      ),
                    ),
    );
  }

  Widget _buildTestCard(TestInSeries test) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: IosTheme.separator, width: 0.6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: IosTheme.primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  '#${test.testNumber > 0 ? test.testNumber : 1}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: IosTheme.primaryBlue,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  test.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: IosTheme.labelPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: IosTheme.separator),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _buildMetric(CupertinoIcons.time, '${test.duration} mins'),
              _buildMetric(
                CupertinoIcons.chart_bar_alt_fill,
                '${test.totalMarks % 1 == 0 ? test.totalMarks.toInt() : test.totalMarks} marks',
              ),
              _buildMetric(
                CupertinoIcons.question_circle,
                '${test.questionsCount} Qs',
              ),
              if (test.negativeMarking > 0)
                _buildMetric(
                  CupertinoIcons.minus_circle,
                  '-${test.negativeMarking}',
                ),
            ],
          ),
          const SizedBox(height: 16),
          IosPrimaryButton(
            label: 'Start Test',
            onPressed: () {
              Navigator.push(
                context,
                CupertinoPageRoute(
                  builder: (context) => TestInstructionsScreen(
                    testId: test.id,
                    testTitle: test.title,
                    fallbackTest: test,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMetric(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: IosTheme.groupedBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: IosTheme.labelTertiary),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: IosTheme.labelSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              CupertinoIcons.exclamationmark_triangle,
              color: IosTheme.systemRed,
              size: 42,
            ),
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: IosTheme.labelTertiary),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 150,
              child: IosPrimaryButton(label: 'Retry', onPressed: _fetchTests),
            ),
          ],
        ),
      ),
    );
  }
}
