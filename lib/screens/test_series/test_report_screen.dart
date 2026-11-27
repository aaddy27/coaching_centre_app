import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../models/test_series_models.dart';
import '../../services/api_service.dart';
import '../../widgets/ios_components.dart';

class TestReportScreen extends StatefulWidget {
  final int attemptId;
  final String? testTitle;
  final TestReport? initialReport;
  final String? autoSubmitReason;

  const TestReportScreen({
    super.key,
    required this.attemptId,
    this.testTitle,
    this.initialReport,
    this.autoSubmitReason,
  });

  @override
  State<TestReportScreen> createState() => _TestReportScreenState();
}

class _TestReportScreenState extends State<TestReportScreen> {
  bool _isLoading = true;
  TestReport? _report;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.initialReport != null) {
      _report = widget.initialReport;
      _isLoading = false;
    } else {
      _loadReport();
    }
  }

  Future<void> _loadReport() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final response = await ApiService.getAttemptReport(widget.attemptId);
    if (!mounted) return;

    if (response['success'] == true && response['data'] != null) {
      setState(() {
        _report = TestReport.fromJson(response['data']);
        _isLoading = false;
      });
    } else {
      setState(() {
        _error = ApiService.extractErrorMessage(
          response,
          fallback: 'Failed to load test report.',
        );
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.testTitle ?? _report?.testTitle ?? 'Scorecard';

    return Scaffold(
      backgroundColor: IosTheme.groupedBg,
      appBar: IosNavBar(title: title, subtitle: 'Performance Report'),
      body: _isLoading
          ? const Center(child: CupertinoActivityIndicator(radius: 14))
          : _error != null
              ? _buildError()
              : _buildReportBody(),
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
              size: 44,
            ),
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: IosTheme.labelTertiary),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 160,
              child: IosPrimaryButton(label: 'Retry', onPressed: _loadReport),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportBody() {
    final report = _report!;
    final attempted = report.correctCount + report.incorrectCount;
    final accuracy = attempted > 0
        ? ((report.correctCount / attempted) * 100).round()
        : 0;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.autoSubmitReason != null &&
              widget.autoSubmitReason!.isNotEmpty) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: IosTheme.systemOrange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: IosTheme.systemOrange.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    CupertinoIcons.shield_lefthalf_fill,
                    color: IosTheme.systemOrange,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.autoSubmitReason!,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: IosTheme.labelPrimary,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          // Score Summary Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: IosTheme.separator, width: 0.6),
            ),
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: IosTheme.primaryBlue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    CupertinoIcons.rosette,
                    color: IosTheme.primaryBlue,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '${report.score % 1 == 0 ? report.score.toInt() : report.score.toStringAsFixed(2)}'
                  '${report.totalMarks != null ? " / ${report.totalMarks!.toInt()}" : ""}',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: IosTheme.labelPrimary,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'FINAL SCORE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: IosTheme.labelTertiary,
                    letterSpacing: 0.7,
                  ),
                ),
                const SizedBox(height: 18),
                const Divider(height: 1, color: IosTheme.separator),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatPill(
                      'Correct',
                      '${report.correctCount}',
                      IosTheme.systemGreen,
                    ),
                    _buildStatPill(
                      'Wrong',
                      '${report.incorrectCount}',
                      IosTheme.systemRed,
                    ),
                    _buildStatPill(
                      'Skipped',
                      '${report.unansweredCount}',
                      IosTheme.systemOrange,
                    ),
                    _buildStatPill(
                      'Accuracy',
                      '$accuracy%',
                      IosTheme.primaryBlue,
                    ),
                  ],
                ),
                if (report.durationMinutes > 0) ...[
                  const SizedBox(height: 14),
                  Text(
                    'Completed in ${report.durationMinutes} min${report.durationMinutes == 1 ? "" : "s"}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: IosTheme.labelTertiary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 22),

          if (report.detailedResults.isNotEmpty) ...[
            IosSectionLabel(
              'Question Solutions (${report.detailedResults.length})',
            ),
            ...List.generate(report.detailedResults.length, (index) {
              final item = report.detailedResults[index];
              return _buildQuestionAnalysisCard(item, index);
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildStatPill(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
            color: IosTheme.labelTertiary,
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionAnalysisCard(QuestionResultDetail item, int index) {
    final bool skipped =
        item.userAnswer == null || item.userAnswer!.trim().isEmpty;
    final Color statusColor = skipped
        ? IosTheme.systemOrange
        : (item.isCorrect ? IosTheme.systemGreen : IosTheme.systemRed);
    final String statusText =
        skipped ? 'Skipped' : (item.isCorrect ? 'Correct' : 'Incorrect');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: IosTheme.separator, width: 0.6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Q${index + 1}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: IosTheme.primaryBlue,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '${item.marksObtained >= 0 ? "+" : ""}${item.marksObtained % 1 == 0 ? item.marksObtained.toInt() : item.marksObtained} marks',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            item.questionText,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              color: IosTheme.labelPrimary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildAnswerChip(
                  'Your Answer',
                  skipped ? '—' : item.userAnswer!.toUpperCase(),
                  statusColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildAnswerChip(
                  'Correct Key',
                  (item.correctAnswer ?? '—').toUpperCase(),
                  IosTheme.systemGreen,
                ),
              ),
            ],
          ),
          if (item.explanation != null && item.explanation!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: IosTheme.groupedBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Explanation: ${item.explanation!}',
                style: const TextStyle(
                  fontSize: 12.5,
                  color: IosTheme.labelSecondary,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAnswerChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              color: IosTheme.labelTertiary,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
