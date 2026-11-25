import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../models/test_series_models.dart';
import '../../registration/login_screen.dart';
import '../../services/api_service.dart';
import '../../widgets/ios_components.dart';
import 'test_questions_screen.dart';

class TestInstructionsScreen extends StatefulWidget {
  final int testId;
  final String testTitle;
  final TestInSeries? fallbackTest;

  const TestInstructionsScreen({
    super.key,
    required this.testId,
    required this.testTitle,
    this.fallbackTest,
  });

  @override
  State<TestInstructionsScreen> createState() => _TestInstructionsScreenState();
}

class _TestInstructionsScreenState extends State<TestInstructionsScreen> {
  bool _isLoading = true;
  bool _isStarting = false;
  bool _requiresLogin = false;
  TestInSeries? _testDetails;
  List<TestQuestion> _prefetchedQuestions = [];
  String? _error;
  bool _acceptedInstructions = false;

  @override
  void initState() {
    super.initState();
    _testDetails = widget.fallbackTest;
    _fetchTestDetails();
  }

  Future<void> _fetchTestDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _requiresLogin = false;
    });

    final loggedIn = await ApiService.isLoggedIn();
    if (!loggedIn) {
      if (!mounted) return;
      setState(() {
        _requiresLogin = true;
        _error = 'Please sign in to view test instructions and start the exam.';
        _isLoading = false;
      });
      return;
    }

    try {
      final response = await ApiService.getTestQuestions(widget.testId);
      if (!mounted) return;

      if (response['success'] == true && response['data'] != null) {
        final testData = response['data']['test'];
        final rawQs = response['data']['questions'] as List? ?? [];
        setState(() {
          if (testData is Map<String, dynamic>) {
            _testDetails = TestInSeries.fromJson(testData);
          }
          _prefetchedQuestions =
              rawQs.map((e) => TestQuestion.fromJson(e)).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _requiresLogin = response['status_code'] == 401;
          _error = ApiService.extractErrorMessage(
            response,
            fallback: 'Failed to load test instructions.',
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

  Future<void> _startTest() async {
    if (_testDetails == null || _isStarting) return;

    setState(() => _isStarting = true);
    try {
      // POST /tests/{id}/start -> initializes attempt and returns questions
      final startRes = await ApiService.startTest(widget.testId);
      if (!mounted) return;

      if (startRes['success'] == true && startRes['data'] != null) {
        final data = startRes['data'] as Map<String, dynamic>;
        final attemptMap = data['attempt'] as Map<String, dynamic>? ?? {};
        final attemptId = attemptMap['id'] is int
            ? attemptMap['id'] as int
            : int.tryParse('${attemptMap['id'] ?? 0}') ?? 0;

        final rawQuestions = data['questions'] as List?;
        final questions = rawQuestions != null && rawQuestions.isNotEmpty
            ? rawQuestions.map((e) => TestQuestion.fromJson(e)).toList()
            : _prefetchedQuestions;

        Navigator.pushReplacement(
          context,
          CupertinoPageRoute(
            builder: (context) => TestQuestionsScreen(
              testId: widget.testId,
              testTitle: widget.testTitle,
              duration: _testDetails!.duration > 0 ? _testDetails!.duration : 30,
              attemptId: attemptId,
              initialQuestions: questions,
            ),
          ),
        );
      } else {
        showIosToast(
          context,
          title: 'Cannot Start Test',
          message: ApiService.extractErrorMessage(
            startRes,
            fallback: 'Failed to start test attempt.',
          ),
          icon: CupertinoIcons.exclamationmark_circle_fill,
          iconColor: IosTheme.systemRed,
        );
      }
    } finally {
      if (mounted) setState(() => _isStarting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IosTheme.groupedBg,
      appBar: IosNavBar(title: widget.testTitle, subtitle: 'Instructions'),
      body: _isLoading
          ? const Center(child: CupertinoActivityIndicator(radius: 14))
          : _error != null
              ? _buildError()
              : Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildSpecsCard(),
                            const SizedBox(height: 22),
                            const IosSectionLabel('Exam Instructions'),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: IosTheme.separator,
                                  width: 0.6,
                                ),
                              ),
                              child: Text(
                                _testDetails?.instructions ??
                                    '1. Read all questions carefully before answering.\n'
                                        '2. Your selected answers are saved automatically in real time.\n'
                                        '3. Negative marks apply for incorrect responses where specified.\n'
                                        '4. The test auto-submits when the timer reaches 00:00.',
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  height: 1.55,
                                  color: IosTheme.labelSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    _buildBottomBar(),
                  ],
                ),
    );
  }

  Widget _buildSpecsCard() {
    final details = _testDetails!;
    final qCount = details.questionsCount > 0
        ? details.questionsCount
        : _prefetchedQuestions.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: IosTheme.separator, width: 0.6),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildSpecCell(
                  CupertinoIcons.timer,
                  '${details.duration} mins',
                  'Duration',
                  IosTheme.primaryBlue,
                ),
              ),
              Container(width: 0.6, height: 44, color: IosTheme.separator),
              Expanded(
                child: _buildSpecCell(
                  CupertinoIcons.chart_bar_alt_fill,
                  '${details.totalMarks % 1 == 0 ? details.totalMarks.toInt() : details.totalMarks}',
                  'Total Marks',
                  IosTheme.systemGreen,
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 0.5, color: IosTheme.separator),
          ),
          Row(
            children: [
              Expanded(
                child: _buildSpecCell(
                  CupertinoIcons.question_circle_fill,
                  '$qCount',
                  'Questions',
                  IosTheme.systemIndigo,
                ),
              ),
              Container(width: 0.6, height: 44, color: IosTheme.separator),
              Expanded(
                child: _buildSpecCell(
                  CupertinoIcons.minus_circle_fill,
                  '-${details.negativeMarking}',
                  'Neg. Marking',
                  IosTheme.systemOrange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSpecCell(
    IconData icon,
    String value,
    String label,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: IosTheme.labelPrimary,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: IosTheme.labelTertiary,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0x26000000), width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () {
                setState(() => _acceptedInstructions = !_acceptedInstructions);
              },
              child: Row(
                children: [
                  Icon(
                    _acceptedInstructions
                        ? CupertinoIcons.checkmark_square_fill
                        : CupertinoIcons.square,
                    color: _acceptedInstructions
                        ? IosTheme.primaryBlue
                        : IosTheme.labelTertiary,
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'I have read and understood all exam instructions',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        color: IosTheme.labelPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            IosPrimaryButton(
              label: 'Begin Test',
              isLoading: _isStarting,
              onPressed: _acceptedInstructions ? _startTest : null,
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
            Icon(
              _requiresLogin
                  ? CupertinoIcons.person_crop_circle_badge_exclam
                  : CupertinoIcons.exclamationmark_triangle,
              color: _requiresLogin ? IosTheme.primaryBlue : IosTheme.systemRed,
              size: 46,
            ),
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: IosTheme.labelTertiary),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: 170,
              child: _requiresLogin
                  ? IosPrimaryButton(
                      label: 'Sign In',
                      onPressed: () async {
                        final ok = await Navigator.push<bool>(
                          context,
                          CupertinoPageRoute(
                            builder: (context) => const LoginScreen(),
                          ),
                        );
                        if (ok == true) _fetchTestDetails();
                      },
                    )
                  : IosPrimaryButton(
                      label: 'Retry',
                      onPressed: _fetchTestDetails,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
