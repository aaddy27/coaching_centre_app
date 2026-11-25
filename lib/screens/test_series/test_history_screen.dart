import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../widgets/ios_components.dart';
import 'test_report_screen.dart';

class TestHistoryScreen extends StatefulWidget {
  const TestHistoryScreen({super.key});

  @override
  State<TestHistoryScreen> createState() => _TestHistoryScreenState();
}

class _TestHistoryScreenState extends State<TestHistoryScreen> {
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _attempts = [];

  @override
  void initState() {
    super.initState();
    _loadAttempts();
  }

  Future<void> _loadAttempts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final response = await ApiService.getMyAttempts();
    if (!mounted) return;

    if (response['success'] == true && response['data'] != null) {
      final raw = response['data'];
      final List list = raw is List
          ? raw
          : (raw is Map && raw['data'] is List
              ? raw['data']
              : (raw is Map && raw['attempts'] is List ? raw['attempts'] : []));

      setState(() {
        _attempts = list.whereType<Map<String, dynamic>>().toList();
        _isLoading = false;
      });
    } else {
      setState(() {
        _error = ApiService.extractErrorMessage(
          response,
          fallback: 'Could not load test history.',
        );
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IosTheme.groupedBg,
      appBar: const IosNavBar(title: 'My Test History'),
      body: _isLoading
          ? const Center(child: CupertinoActivityIndicator(radius: 14))
          : _error != null
              ? _buildError()
              : _attempts.isEmpty
                  ? _buildEmpty()
                  : RefreshIndicator(
                      onRefresh: _loadAttempts,
                      color: IosTheme.primaryBlue,
                      child: ListView.builder(
                        physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                        padding: const EdgeInsets.all(16),
                        itemCount: _attempts.length,
                        itemBuilder: (context, index) =>
                            _buildAttemptCard(_attempts[index]),
                      ),
                    ),
    );
  }

  Widget _buildAttemptCard(Map<String, dynamic> att) {
    final int attemptId = att['id'] is int
        ? att['id']
        : int.tryParse('${att['attempt_id'] ?? att['id'] ?? 0}') ?? 0;
    final String title = att['test_title']?.toString() ??
        (att['test'] is Map ? att['test']['title']?.toString() : null) ??
        'Mock Test #$attemptId';
    final score = att['score'];
    final dateStr =
        att['completed_at']?.toString() ?? att['created_at']?.toString() ?? '';
    final formattedDate =
        dateStr.length >= 10 ? dateStr.substring(0, 10) : dateStr;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: IosTheme.separator, width: 0.6),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: attemptId > 0
              ? () {
                  Navigator.push(
                    context,
                    CupertinoPageRoute(
                      builder: (context) => TestReportScreen(
                        attemptId: attemptId,
                        testTitle: title,
                      ),
                    ),
                  );
                }
              : null,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: IosTheme.systemIndigo.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(
                    CupertinoIcons.doc_checkmark_fill,
                    color: IosTheme.systemIndigo,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: IosTheme.labelPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        formattedDate.isNotEmpty
                            ? 'Attempted on $formattedDate'
                            : 'Tap to view scorecard',
                        style: const TextStyle(
                          fontSize: 12,
                          color: IosTheme.labelTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (score != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: IosTheme.systemGreen.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$score pts',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: IosTheme.systemGreen,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                const Icon(
                  CupertinoIcons.chevron_right,
                  size: 14,
                  color: Color(0xFFC7C7CC),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.doc_text,
              size: 48,
              color: IosTheme.labelTertiary,
            ),
            SizedBox(height: 12),
            Text(
              'No Test Attempts Yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: IosTheme.labelPrimary,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Attempt a test series mock exam to view your scorecards and detailed reports here.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, color: IosTheme.labelTertiary),
            ),
          ],
        ),
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
              child: IosPrimaryButton(label: 'Retry', onPressed: _loadAttempts),
            ),
          ],
        ),
      ),
    );
  }
}
