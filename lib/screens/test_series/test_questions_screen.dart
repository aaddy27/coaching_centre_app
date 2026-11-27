import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/test_series_models.dart';
import '../../services/api_service.dart';
import '../../widgets/ios_components.dart';
import 'test_report_screen.dart';

class TestQuestionsScreen extends StatefulWidget {
  final int testId;
  final String testTitle;
  final int duration;
  final int? attemptId;
  final List<TestQuestion>? initialQuestions;

  const TestQuestionsScreen({
    super.key,
    required this.testId,
    required this.testTitle,
    required this.duration,
    this.attemptId,
    this.initialQuestions,
  });

  @override
  State<TestQuestionsScreen> createState() => _TestQuestionsScreenState();
}

class _TestQuestionsScreenState extends State<TestQuestionsScreen>
    with WidgetsBindingObserver {
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _hasEnded = false;
  String? _endReason;
  String? _submissionError;
  int? _attemptId;
  List<TestQuestion> _questions = [];
  final Map<int, String> _answers = {};
  final Set<int> _markedForReview = {};
  int _currentIndex = 0;
  Timer? _timer;
  int _remainingSeconds = 0;
  String? _error;

  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _remainingSeconds = (widget.duration > 0 ? widget.duration : 30) * 60;
    _attemptId = widget.attemptId;

    if (widget.initialQuestions != null &&
        widget.initialQuestions!.isNotEmpty &&
        _attemptId != null &&
        _attemptId! > 0) {
      _questions = widget.initialQuestions!;
      _isLoading = false;
      ApiService.markTestAttempted(widget.testId, attemptId: _attemptId);
      _startTimer();
    } else {
      _initAttemptAndQuestions();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      if (!_isLoading &&
          !_hasEnded &&
          !_isSubmitting &&
          _questions.isNotEmpty) {
        _autoEndAndSubmit(
          reason:
              'Test auto-submitted because you switched apps or left the exam screen.',
        );
      }
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        timer.cancel();
        _autoEndAndSubmit(
          reason: 'Test auto-submitted because the time limit expired.',
        );
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _initAttemptAndQuestions() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await ApiService.startTest(widget.testId);
      if (!mounted) return;

      if (response['success'] == true && response['data'] != null) {
        final data = response['data'] as Map<String, dynamic>;
        final attemptMap = data['attempt'] as Map<String, dynamic>? ?? {};
        final list = data['questions'] as List? ?? [];
        final parsedAttemptId = attemptMap['id'] is int
            ? attemptMap['id'] as int
            : int.tryParse('${attemptMap['id'] ?? 0}');

        await ApiService.markTestAttempted(
          widget.testId,
          attemptId: parsedAttemptId,
        );
        if (!mounted) return;

        setState(() {
          _attemptId = parsedAttemptId;
          _questions = list.map((e) => TestQuestion.fromJson(e)).toList();
          _isLoading = false;
        });
        _startTimer();
      } else {
        setState(() {
          _error = ApiService.extractErrorMessage(
            response,
            fallback: 'Failed to start test.',
          );
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Error starting test: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _selectAnswer(int questionId, String optionKey) async {
    if (_hasEnded || _isSubmitting) return;
    HapticFeedback.selectionClick();
    setState(() {
      _answers[questionId] = optionKey;
    });

    // Save answer in real-time via POST /attempts/{id}/answer
    if (_attemptId != null && _attemptId! > 0) {
      final res = await ApiService.saveAttemptAnswer(
        attemptId: _attemptId!,
        questionId: questionId,
        answer: optionKey,
      );
      if (res['success'] != true) {
        debugPrint('Warning: real-time save answer failed: ${res['message']}');
      }
    }
  }

  Future<void> _autoEndAndSubmit({required String reason}) async {
    if (_isSubmitting) return;
    _timer?.cancel();

    setState(() {
      _hasEnded = true;
      _endReason = reason;
      _submissionError = null;
      _isSubmitting = true;
    });

    await ApiService.markTestAttempted(widget.testId, attemptId: _attemptId);
    await _finishAndNavigate(autoReason: reason);
  }

  Future<void> _submitTest({bool auto = false, String? autoReason}) async {
    if (_isSubmitting) return;

    if (!auto) {
      final confirm = await showCupertinoDialog<bool>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('Submit Test?'),
          content: Text(
            'You have answered ${_answers.length} out of ${_questions.length} questions. You cannot retake this test once submitted.',
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Continue Test'),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Submit'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    _timer?.cancel();
    setState(() {
      _hasEnded = true;
      _endReason = autoReason;
      _submissionError = null;
      _isSubmitting = true;
    });

    await ApiService.markTestAttempted(widget.testId, attemptId: _attemptId);
    await _finishAndNavigate(autoReason: autoReason);
  }

  Future<void> _finishAndNavigate({String? autoReason}) async {
    try {
      if (_attemptId != null && _attemptId! > 0) {
        final response = await ApiService.finishTestAttempt(_attemptId!);
        if (!mounted) return;

        if (response['success'] == true && response['data'] != null) {
          final report = TestReport.fromJson(response['data']);
          final resolvedAttemptId =
              report.attemptId > 0 ? report.attemptId : _attemptId!;
          await ApiService.markTestAttempted(
            widget.testId,
            attemptId: resolvedAttemptId,
          );
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            CupertinoPageRoute(
              builder: (context) => TestReportScreen(
                attemptId: resolvedAttemptId,
                testTitle: widget.testTitle,
                initialReport: report,
                autoSubmitReason: autoReason,
              ),
            ),
          );
          return;
        } else {
          setState(() {
            _submissionError = ApiService.extractErrorMessage(
              response,
              fallback: 'Could not submit test.',
            );
          });
          return;
        }
      }

      if (mounted) {
        Navigator.pop(context);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _showPalette() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) => Container(
        height: MediaQuery.of(context).size.height * 0.62,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFD1D1D6),
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Question Palette',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: IosTheme.labelPrimary,
                      ),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => Navigator.pop(sheetCtx),
                      child: const Text(
                        'Done',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: IosTheme.primaryBlue,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 0.5, color: IosTheme.separator),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: _questions.length,
                  itemBuilder: (context, index) {
                    final qId = _questions[index].id;
                    final isAnswered = _answers.containsKey(qId);
                    final isMarked = _markedForReview.contains(qId);
                    final isCurrent = index == _currentIndex;

                    Color bgColor = IosTheme.groupedBg;
                    Color fgColor = IosTheme.labelPrimary;
                    if (isMarked) {
                      bgColor = IosTheme.systemOrange.withValues(alpha: 0.16);
                      fgColor = IosTheme.systemOrange;
                    } else if (isAnswered) {
                      bgColor = IosTheme.systemGreen.withValues(alpha: 0.16);
                      fgColor = IosTheme.systemGreen;
                    }

                    return GestureDetector(
                      onTap: () {
                        _pageController.jumpToPage(index);
                        setState(() => _currentIndex = index);
                        Navigator.pop(sheetCtx);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(10),
                          border: isCurrent
                              ? Border.all(color: IosTheme.primaryBlue, width: 2)
                              : Border.all(
                                  color: IosTheme.separator,
                                  width: 0.6,
                                ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: fgColor,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLowTime = _remainingSeconds < 300;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_isLoading || _error != null) {
          Navigator.pop(context);
          return;
        }
        if (_hasEnded) {
          if (!_isSubmitting) {
            Navigator.pop(context);
          }
          return;
        }
        _autoEndAndSubmit(
          reason:
              'Test auto-submitted because you pressed Back during the exam.',
        );
      },
      child: Scaffold(
        backgroundColor: IosTheme.groupedBg,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: Colors.white,
          elevation: 0,
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(0.5),
            child: Divider(height: 0.5, color: Color(0x26000000)),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: (isLowTime
                          ? IosTheme.systemRed
                          : IosTheme.primaryBlue)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      CupertinoIcons.timer,
                      size: 16,
                      color:
                          isLowTime ? IosTheme.systemRed : IosTheme.primaryBlue,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _formatTime(_remainingSeconds),
                      style: TextStyle(
                        fontSize: 14,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w700,
                        color: isLowTime
                            ? IosTheme.systemRed
                            : IosTheme.primaryBlue,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                'Q ${_questions.isEmpty ? 0 : _currentIndex + 1} / ${_questions.length}',
                style: const TextStyle(
                  color: IosTheme.labelPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          actions: [
            if (!_hasEnded)
              CupertinoButton(
                padding: const EdgeInsets.only(right: 12),
                onPressed: _showPalette,
                child: const Icon(
                  CupertinoIcons.square_grid_2x2,
                  color: IosTheme.primaryBlue,
                  size: 22,
                ),
              ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CupertinoActivityIndicator(radius: 14))
            : _hasEnded
                ? _buildEndedLockView()
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: IosTheme.labelTertiary,
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: 150,
                                child: IosPrimaryButton(
                                  label: 'Retry',
                                  onPressed: _initAttemptAndQuestions,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Column(
                        children: [
                          Expanded(
                            child: PageView.builder(
                              controller: _pageController,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _questions.length,
                              onPageChanged: (index) {
                                setState(() => _currentIndex = index);
                              },
                              itemBuilder: (context, index) =>
                                  _buildQuestionPage(_questions[index], index),
                            ),
                          ),
                          _buildBottomBar(),
                        ],
                      ),
      ),
    );
  }

  Widget _buildEndedLockView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isSubmitting) ...[
              const CupertinoActivityIndicator(radius: 16),
              const SizedBox(height: 16),
              const Text(
                'Submitting Test...',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: IosTheme.labelPrimary,
                ),
              ),
              if (_endReason != null) ...[
                const SizedBox(height: 8),
                Text(
                  _endReason!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: IosTheme.labelTertiary,
                  ),
                ),
              ],
            ] else ...[
              const Icon(
                CupertinoIcons.shield_lefthalf_fill,
                color: IosTheme.systemOrange,
                size: 52,
              ),
              const SizedBox(height: 14),
              const Text(
                'Test Ended',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: IosTheme.labelPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _submissionError ??
                    _endReason ??
                    'Your test session has ended.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: IosTheme.labelTertiary,
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: 210,
                child: IosPrimaryButton(
                  label: 'Submit & View Report',
                  onPressed: () {
                    setState(() {
                      _submissionError = null;
                      _isSubmitting = true;
                    });
                    _finishAndNavigate(autoReason: _endReason);
                  },
                ),
              ),
              const SizedBox(height: 10),
              CupertinoButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Close',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: IosTheme.labelTertiary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionPage(TestQuestion question, int index) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: IosTheme.separator, width: 0.6),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Question ${index + 1}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: IosTheme.primaryBlue,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: IosTheme.groupedBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '+${question.marks} / -${question.negativeMarks}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: IosTheme.labelTertiary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  question.questionText,
                  style: const TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w600,
                    color: IosTheme.labelPrimary,
                    height: 1.45,
                  ),
                ),
                if (question.questionImage != null &&
                    question.questionImage!.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      question.questionImage!,
                      errorBuilder: (_, __, ___) => const SizedBox(),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          ...question.options.entries.map((entry) {
            final isSelected = _answers[question.id] == entry.key;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: () => _selectAnswer(question.id, entry.key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? IosTheme.primaryBlue.withValues(alpha: 0.08)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? IosTheme.primaryBlue
                          : IosTheme.separator,
                      width: isSelected ? 1.8 : 0.6,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected
                              ? IosTheme.primaryBlue
                              : IosTheme.groupedBg,
                        ),
                        alignment: Alignment.center,
                        child: isSelected
                            ? const Icon(
                                CupertinoIcons.checkmark,
                                color: Colors.white,
                                size: 15,
                              )
                            : Text(
                                entry.key.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: IosTheme.labelSecondary,
                                ),
                              ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          entry.value,
                          style: TextStyle(
                            fontSize: 15,
                            color: IosTheme.labelPrimary,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    final qId = _questions.isNotEmpty ? _questions[_currentIndex].id : -1;
    final isMarked = _markedForReview.contains(qId);
    final isLast = _currentIndex >= _questions.length - 1;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0x26000000), width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            CupertinoButton(
              padding: const EdgeInsets.all(12),
              color: IosTheme.groupedBg,
              borderRadius: BorderRadius.circular(12),
              onPressed: _currentIndex > 0
                  ? () {
                      _pageController.previousPage(
                        duration: const Duration(milliseconds: 240),
                        curve: Curves.easeOutCubic,
                      );
                    }
                  : null,
              child: const Icon(
                CupertinoIcons.chevron_left,
                size: 18,
                color: IosTheme.labelPrimary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: CupertinoButton(
                padding: const EdgeInsets.symmetric(vertical: 12),
                color: isMarked
                    ? IosTheme.systemOrange.withValues(alpha: 0.14)
                    : IosTheme.groupedBg,
                borderRadius: BorderRadius.circular(12),
                onPressed: () {
                  setState(() {
                    if (isMarked) {
                      _markedForReview.remove(qId);
                    } else {
                      _markedForReview.add(qId);
                    }
                  });
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isMarked ? CupertinoIcons.flag_fill : CupertinoIcons.flag,
                      size: 16,
                      color: isMarked
                          ? IosTheme.systemOrange
                          : IosTheme.labelSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isMarked ? 'Marked' : 'Review',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isMarked
                            ? IosTheme.systemOrange
                            : IosTheme.labelSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: CupertinoButton(
                padding: const EdgeInsets.symmetric(vertical: 12),
                color: isLast ? IosTheme.systemGreen : IosTheme.primaryBlue,
                borderRadius: BorderRadius.circular(12),
                onPressed: _isSubmitting
                    ? null
                    : () {
                        if (!isLast) {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 240),
                            curve: Curves.easeOutCubic,
                          );
                        } else {
                          _submitTest(auto: false);
                        }
                      },
                child: _isSubmitting
                    ? const CupertinoActivityIndicator(color: Colors.white)
                    : Text(
                        isLast ? 'Submit' : 'Next',
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
