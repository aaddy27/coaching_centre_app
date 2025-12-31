import 'dart:async';
import 'package:flutter/material.dart';
import 'package:coaching/models/test_series_models.dart';
import 'package:coaching/services/api_service.dart';

class TestQuestionsScreen extends StatefulWidget {
  final int testId;
  final String testTitle;
  final int duration;

  const TestQuestionsScreen({
    Key? key,
    required this.testId,
    required this.testTitle,
    required this.duration,
  }) : super(key: key);

  @override
  State<TestQuestionsScreen> createState() => _TestQuestionsScreenState();
}

class _TestQuestionsScreenState extends State<TestQuestionsScreen> {
  bool _isLoading = true;
  List<TestQuestion> _questions = [];
  Map<int, String> _answers = {}; // questionId -> optionKey (a,b,c,d)
  Set<int> _markedForReview = {};
  int _currentIndex = 0;
  late Timer _timer;
  int _remainingSeconds = 0;
  String? _error;

  // Page controller
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.duration * 60;
    _startTimer();
    _fetchQuestions();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        _timer.cancel();
        _submitTest(auto: true);
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _fetchQuestions() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final response = await ApiService.getTestQuestions(widget.testId);

      if (response['success'] == true && response['data'] != null) {
        final List<dynamic> list = response['data']['questions'] ?? [];
        setState(() {
          _questions = list.map((e) => TestQuestion.fromJson(e)).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = response['message'] ?? 'Failed to load questions';
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

  Future<void> _submitTest({bool auto = false}) async {
    // Show confirmation if not auto submit
    if (!auto) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Submit Test?'),
          content: Text(
            'You have answered ${_answers.length} out of ${_questions.length} questions.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Submit'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    _timer.cancel();

    // Mock submission - In real app, call API
    // await ApiService.submitTest(widget.testId, _answers);

    // For now just pop back
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Test Submitted Successfully!')),
      );
      Navigator.pop(context);
    }
  }

  String _formatTime(int seconds) {
    int m = seconds ~/ 60;
    int s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _showPalette() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Question Palette',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: GridView.builder(
                controller: scrollController,
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

                  Color color = Colors.grey[200]!; // Not visited
                  if (isCurrent)
                    color = Colors.blue[100]!;
                  else if (isMarked)
                    color = Colors.orange[100]!;
                  else if (isAnswered)
                    color = Colors.green[100]!;

                  Color textColor = Colors.black;
                  if (isMarked)
                    textColor = Colors.orange[900]!;
                  else if (isAnswered)
                    textColor = Colors.green[900]!;

                  return InkWell(
                    onTap: () {
                      _pageController.jumpToPage(index);
                      setState(() => _currentIndex = index);
                      Navigator.pop(context);
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(8),
                        border: isCurrent
                            ? Border.all(color: Colors.blue, width: 2)
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: textColor,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Exit Test?'),
            content: const Text('Your progress will be lost if you exit now.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Stay'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Exit',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        );
        return confirm ?? false;
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          elevation: 1,
          backgroundColor: Colors.white,
          title: Row(
            children: [
              Icon(
                Icons.timer_outlined,
                color: _remainingSeconds < 300 ? Colors.red : Colors.black87,
              ),
              const SizedBox(width: 8),
              Text(
                _formatTime(_remainingSeconds),
                style: TextStyle(
                  color: _remainingSeconds < 300 ? Colors.red : Colors.black87,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                'Q ${_currentIndex + 1}/${_questions.length}',
                style: const TextStyle(color: Colors.black87, fontSize: 16),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.grid_view, color: Colors.black87),
              onPressed: _showPalette,
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(child: Text(_error!))
            : Column(
                children: [
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      physics:
                          const NeverScrollableScrollPhysics(), // Disable swipe to force navigation buttons
                      itemCount: _questions.length,
                      onPageChanged: (index) {
                        setState(() => _currentIndex = index);
                      },
                      itemBuilder: (context, index) {
                        return _buildQuestionPage(_questions[index], index);
                      },
                    ),
                  ),
                  _buildBottomBar(),
                ],
              ),
      ),
    );
  }

  Widget _buildQuestionPage(TestQuestion question, int index) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Question ${index + 1}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Color(0xFF6366F1),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '+${question.marks} / -${question.negativeMarks}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            question.questionText,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
          ),
          if (question.questionImage != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  question.questionImage!,
                  errorBuilder: (_, __, ___) => const SizedBox(),
                ),
              ),
            ),
          const SizedBox(height: 24),
          ...question.options.entries.map((entry) {
            final isSelected = _answers[question.id] == entry.key;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                onTap: () {
                  setState(() {
                    _answers[question.id] = entry.key;
                  });
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF6366F1).withOpacity(0.1)
                        : Colors.white,
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF6366F1)
                          : Colors.grey.withOpacity(0.3),
                      width: isSelected ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected
                              ? const Color(0xFF6366F1)
                              : Colors.transparent,
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF6366F1)
                                : Colors.grey,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: isSelected
                            ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 16,
                              )
                            : Text(
                                entry.key.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                ),
                              ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          entry.value,
                          style: TextStyle(
                            fontSize: 16,
                            color: isSelected
                                ? const Color(0xFF1E293B)
                                : const Color(0xFF475569),
                            fontWeight: isSelected
                                ? FontWeight.w500
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    final qId = _questions.isNotEmpty ? _questions[_currentIndex].id : -1;
    final isMarked = _markedForReview.contains(qId);

    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Row(
        children: [
          // Previous button
          IconButton(
            onPressed: _currentIndex > 0
                ? () {
                    _pageController.previousPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                : null,
            icon: const Icon(Icons.arrow_back_ios, size: 20),
            style: IconButton.styleFrom(
              backgroundColor: Colors.grey[100],
              padding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(width: 12),

          // Mark for review
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  if (isMarked) {
                    _markedForReview.remove(qId);
                  } else {
                    _markedForReview.add(qId);
                  }
                });
              },
              icon: Icon(
                isMarked ? Icons.flag : Icons.flag_outlined,
                color: isMarked ? Colors.orange : Colors.grey[700],
              ),
              label: Text(
                isMarked ? 'Marked' : 'Review',
                style: TextStyle(
                  color: isMarked ? Colors.orange : Colors.grey[700],
                ),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: BorderSide(
                  color: isMarked ? Colors.orange : Colors.grey[300]!,
                ),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Next / Submit
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                if (_currentIndex < _questions.length - 1) {
                  _pageController.nextPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                } else {
                  _submitTest(auto: false);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _currentIndex == _questions.length - 1
                    ? Colors.green
                    : const Color(0xFF6366F1),
                padding: const EdgeInsets.symmetric(vertical: 12),
                elevation: 0,
              ),
              child: Text(
                _currentIndex == _questions.length - 1 ? 'Submit' : 'Next',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
