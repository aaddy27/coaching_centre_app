import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:coaching/models/test_series_models.dart';
import 'package:coaching/services/api_service.dart';
import 'package:coaching/screens/test_series/test_series_subjects_screen.dart';

class TestSeriesListScreen extends StatefulWidget {
  const TestSeriesListScreen({super.key});

  @override
  State<TestSeriesListScreen> createState() => _TestSeriesListScreenState();
}

class _TestSeriesListScreenState extends State<TestSeriesListScreen> {
  bool _isLoading = true;
  List<TestSeries> _testSeriesList = [];
  String? _error;

  // Search & Filter State
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int _selectedSegment = 0; // 0: All, 1: Free, 2: Purchased, 3: Completed

  // Completed test series IDs & user ratings
  final Set<int> _completedSeriesIds = {};
  final Map<int, double> _userRatings = {};

  @override
  void initState() {
    super.initState();
    _fetchTestSeries();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchTestSeries() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final response = await ApiService.getTestSeriesList();
      if (response['success'] == true && response['data'] != null) {
        final List<dynamic> list = response['data']['data'] ?? [];
        final parsedList = list.map((e) => TestSeries.fromJson(e)).toList();

        // Gracefully attempt to check completed attempts
        try {
          final attemptsResponse = await ApiService.getMyAttempts();
          if (attemptsResponse['success'] == true && attemptsResponse['data'] != null) {
            final attempts = attemptsResponse['data'] is List
                ? attemptsResponse['data'] as List
                : (attemptsResponse['data']['data'] as List? ?? []);
            for (final att in attempts) {
              final testId = att['test_id'] ?? att['test_series_id'];
              if (testId != null) {
                final idInt = testId is int ? testId : int.tryParse('$testId');
                if (idInt != null) _completedSeriesIds.add(idInt);
              }
            }
          }
        } catch (_) {
          // Guest user or no attempts yet
        }

        if (mounted) {
          setState(() {
            _testSeriesList = parsedList;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _error = response['message'] ?? 'Failed to load test series';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error loading tests: $e';
          _isLoading = false;
        });
      }
    }
  }

  // Filtered list based on active segment & search query
  List<TestSeries> get _filteredSeriesList {
    return _testSeriesList.where((series) {
      // 1. Tab segment filter
      if (_selectedSegment == 1) {
        // Free tab
        final isFree = series.isFree || series.price <= 0.0;
        if (!isFree) return false;
      } else if (_selectedSegment == 2) {
        // Purchased tab
        final isPurchased = series.isPurchased || series.isAccessible;
        if (!isPurchased) return false;
      } else if (_selectedSegment == 3) {
        // Completed tab
        final isCompleted =
            series.isCompleted || _completedSeriesIds.contains(series.id);
        if (!isCompleted) return false;
      }

      // 2. Search query filter
      if (_searchQuery.trim().isNotEmpty) {
        final query = _searchQuery.trim().toLowerCase();
        final titleMatch = series.title.toLowerCase().contains(query);
        final descMatch = series.description.toLowerCase().contains(query);
        final subjectsMatch = series.subjects?.any(
              (s) => s.name.toLowerCase().contains(query),
            ) ??
            false;
        if (!titleMatch && !descMatch && !subjectsMatch) return false;
      }

      return true;
    }).toList();
  }

  int get _allCount => _testSeriesList.length;
  int get _freeCount =>
      _testSeriesList.where((s) => s.isFree || s.price <= 0.0).length;
  int get _purchasedCount =>
      _testSeriesList.where((s) => s.isPurchased || s.isAccessible).length;
  int get _completedCount => _testSeriesList
      .where((s) => s.isCompleted || _completedSeriesIds.contains(s.id))
      .length;

  // ==================== iOS Share Action Sheet ====================
  void _showShareSheet(TestSeries series) {
    final shareUrl = 'https://coachingapp.in/test-series/${series.id}';
    final subjectsText = series.subjects != null && series.subjects!.isNotEmpty
        ? series.subjects!.map((s) => s.name).join(', ')
        : 'All Subjects Mock Tests';
    final priceText = (series.isFree || series.price <= 0.0)
        ? 'FREE'
        : '₹${series.price.toStringAsFixed(0)}';

    showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext sheetContext) => CupertinoActionSheet(
        title: Text(
          series.title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1C1C1E),
          ),
        ),
        message: Text(
          'Price: $priceText • $subjectsText\nShare this test series with your friends & study groups',
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF8E8E93),
          ),
        ),
        actions: <CupertinoActionSheetAction>[
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(sheetContext);
              Clipboard.setData(ClipboardData(text: shareUrl));
              _showIosToast(
                title: 'Link Copied',
                message: 'Test series link copied to clipboard.',
                icon: CupertinoIcons.link,
                iconColor: const Color(0xFF007AFF),
              );
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.link, color: Color(0xFF007AFF), size: 20),
                SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Copy Test Series Link',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Color(0xFF007AFF),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(sheetContext);
              final waText = '📚 *${series.title}*\n'
                  '🎯 Prepare with Full-Length Mock Tests & Detailed Solutions.\n'
                  '💰 Price: $priceText\n'
                  '📖 Subjects: $subjectsText\n'
                  '⏱️ Duration: ${series.duration > 0 ? "${series.duration} mins" : "Standard"}\n'
                  '🔗 Attempt Now: $shareUrl';
              Clipboard.setData(ClipboardData(text: waText));
              _showIosToast(
                title: 'Ready to Share',
                message: 'Formatted message copied! Paste in WhatsApp or Telegram.',
                icon: CupertinoIcons.chat_bubble_2_fill,
                iconColor: const Color(0xFF34C759),
              );
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  CupertinoIcons.chat_bubble_2_fill,
                  color: Color(0xFF34C759),
                  size: 20,
                ),
                SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Share on WhatsApp / Telegram',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Color(0xFF34C759),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(sheetContext);
              final summaryText = '📋 ${series.title}\n'
                  '${series.description.isNotEmpty ? "${series.description}\n" : ""}'
                  'Subjects: $subjectsText\n'
                  'Total Marks: ${series.totalMarks > 0 ? series.totalMarks.toStringAsFixed(0) : "100"}\n'
                  'Link: $shareUrl';
              Clipboard.setData(ClipboardData(text: summaryText));
              _showIosToast(
                title: 'Overview Copied',
                message: 'Complete test series overview copied.',
                icon: CupertinoIcons.doc_plaintext,
                iconColor: const Color(0xFF5856D6),
              );
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  CupertinoIcons.doc_plaintext,
                  color: Color(0xFF5856D6),
                  size: 20,
                ),
                SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Copy Full Test Details',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Color(0xFF5856D6),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(sheetContext),
          child: const Text(
            'Cancel',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF007AFF),
            ),
          ),
        ),
      ),
    );
  }

  // ==================== iOS Rating Bottom Sheet ====================
  void _showRatingSheet(TestSeries series) {
    double currentRating = _userRatings[series.id] ?? 5.0;
    final TextEditingController reviewController = TextEditingController();
    final Set<String> selectedTags = {'🎯 Exam Pattern', '💡 Clear Solutions'};

    final List<String> availableTags = [
      '🎯 Exam Pattern',
      '💡 Clear Solutions',
      '⏱️ Great Timing',
      '🔥 High Quality',
      '📊 Detailed Analysis',
      '💯 Highly Recommended',
    ];

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            String sentimentText;
            if (currentRating >= 5) {
              sentimentText = 'Outstanding! 🌟';
            } else if (currentRating >= 4) {
              sentimentText = 'Very Good! 👍';
            } else if (currentRating >= 3) {
              sentimentText = 'Good 🙂';
            } else if (currentRating >= 2) {
              sentimentText = 'Fair 😐';
            } else {
              sentimentText = 'Needs Improvement 😕';
            }

            return Container(
              padding: EdgeInsets.only(
                top: 12,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x1F000000),
                    blurRadius: 20,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // iOS Drag Handle
                    Center(
                      child: Container(
                        width: 36,
                        height: 5,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD1D1D6),
                          borderRadius: BorderRadius.circular(2.5),
                        ),
                      ),
                    ),

                    // Header
                    const Text(
                      'Rate Test Series',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1C1C1E),
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      series.title,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF8E8E93),
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 20),

                    // 5 Interactive Stars
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (index) {
                          final starValue = index + 1;
                          final isSelected = starValue <= currentRating;
                          return GestureDetector(
                            onTap: () {
                              setSheetState(() {
                                currentRating = starValue.toDouble();
                              });
                            },
                            behavior: HitTestBehavior.opaque,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: Icon(
                                isSelected
                                    ? CupertinoIcons.star_fill
                                    : CupertinoIcons.star,
                                color: isSelected
                                    ? const Color(0xFFFF9500)
                                    : const Color(0xFFD1D1D6),
                                size: 38,
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      sentimentText,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1C1C1E),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Quick Feedback Tags
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'WHAT DID YOU LIKE MOST?',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF8E8E93),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: availableTags.map((tag) {
                        final isSelected = selectedTags.contains(tag);
                        return GestureDetector(
                          onTap: () {
                            setSheetState(() {
                              if (isSelected) {
                                selectedTags.remove(tag);
                              } else {
                                selectedTags.add(tag);
                              }
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF007AFF).withValues(alpha: 0.12)
                                  : const Color(0xFFF2F2F7),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF007AFF)
                                    : const Color(0xFFE5E5EA),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              tag,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                color: isSelected
                                    ? const Color(0xFF007AFF)
                                    : const Color(0xFF1C1C1E),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 18),

                    // Cupertino Review Input
                    CupertinoTextField(
                      controller: reviewController,
                      placeholder:
                          'Write a short review or suggestions (optional)...',
                      placeholderStyle: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF8E8E93),
                      ),
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF1C1C1E),
                      ),
                      maxLines: 3,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9F9FA),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFE5E5EA),
                          width: 1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: CupertinoButton(
                        padding: EdgeInsets.zero,
                        color: const Color(0xFF007AFF),
                        borderRadius: BorderRadius.circular(14),
                        onPressed: () {
                          setState(() {
                            _userRatings[series.id] = currentRating;
                          });
                          Navigator.pop(sheetContext);
                          _showIosToast(
                            title: 'Rating Submitted!',
                            message:
                                'Thank you! You rated "${series.title}" ${currentRating.toStringAsFixed(0)} stars.',
                            icon: CupertinoIcons.star_fill,
                            iconColor: const Color(0xFFFF9500),
                          );
                        },
                        child: const Text(
                          'Submit Rating',
                          style: TextStyle(
                            fontSize: 16,
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
          },
        );
      },
    );
  }

  // ==================== iOS Toast Notification ====================
  void _showIosToast({
    required String title,
    required String message,
    IconData icon = CupertinoIcons.checkmark_alt_circle_fill,
    Color iconColor = const Color(0xFF34C759),
  }) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        elevation: 6,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        duration: const Duration(seconds: 3),
        content: Row(
          children: [
            Icon(icon, color: iconColor, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    message,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFE5E5EA),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // 1. iOS Large Header with Title & Refresh
            _buildIosHeader(),

            // 2. Native iOS Search Bar
            _buildSearchBar(),

            // 3. Segmented Tabs (All, Free, Purchased, Completed)
            _buildSegmentedTabs(),

            const Divider(
              height: 1,
              thickness: 0.5,
              color: Color(0xFFE5E5EA),
            ),

            // 4. Content Area
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CupertinoActivityIndicator(radius: 14),
                    )
                  : _error != null
                      ? _buildErrorView()
                      : _buildListView(),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== Header Widget ====================
  Widget _buildIosHeader() {
    final canPop = Navigator.canPop(context);
    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(
        top: canPop ? 6 : 14,
        left: 16,
        right: 16,
        bottom: 8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (canPop)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                alignment: Alignment.centerLeft,
                minimumSize: const Size(32, 32),
                onPressed: () => Navigator.maybePop(context),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      CupertinoIcons.chevron_left,
                      color: Color(0xFF007AFF),
                      size: 22,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Back',
                      style: TextStyle(
                        color: Color(0xFF007AFF),
                        fontSize: 17,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Test Series',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1C1C1E),
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Exam-oriented full mocks & practice sets',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: const Size(36, 36),
                onPressed: _fetchTestSeries,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F2F7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    CupertinoIcons.arrow_clockwise,
                    size: 18,
                    color: Color(0xFF007AFF),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== Native Search Bar ====================
  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: CupertinoSearchTextField(
        controller: _searchController,
        placeholder: 'Search test series, exam, subjects...',
        backgroundColor: const Color(0xFFF2F2F7),
        borderRadius: BorderRadius.circular(12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        style: const TextStyle(
          fontSize: 15,
          color: Color(0xFF1C1C1E),
        ),
        placeholderStyle: const TextStyle(
          fontSize: 15,
          color: Color(0xFF8E8E93),
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
        onSuffixTap: () {
          _searchController.clear();
          setState(() {
            _searchQuery = '';
          });
        },
      ),
    );
  }

  // ==================== Sliding Segmented Control ====================
  Widget _buildSegmentedTabs() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final control = CupertinoSlidingSegmentedControl<int>(
            groupValue: _selectedSegment,
            backgroundColor: const Color(0xFFEFEFF4),
            thumbColor: Colors.white,
            padding: const EdgeInsets.all(3),
            children: {
              0: _buildSegmentItem('All', _allCount, 0),
              1: _buildSegmentItem('Free', _freeCount, 1),
              2: _buildSegmentItem('Purchased', _purchasedCount, 2),
              3: _buildSegmentItem('Completed', _completedCount, 3),
            },
            onValueChanged: (val) {
              if (val != null) {
                setState(() {
                  _selectedSegment = val;
                });
              }
            },
          );

          if (constraints.maxWidth < 380) {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: control,
              ),
            );
          }

          return SizedBox(
            width: double.infinity,
            child: control,
          );
        },
      ),
    );
  }

  Widget _buildSegmentItem(String title, int count, int index) {
    final isSelected = _selectedSegment == index;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 2),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? const Color(0xFF1C1C1E)
                    : const Color(0xFF8E8E93),
              ),
            ),
            if (count > 0 || index == 0) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF007AFF)
                      : const Color(0xFFD1D1D6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : const Color(0xFF3A3A3C),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ==================== Main List View ====================
  Widget _buildListView() {
    final list = _filteredSeriesList;

    if (list.isEmpty) {
      return _buildEmptyState();
    }

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      slivers: [
        CupertinoSliverRefreshControl(
          onRefresh: _fetchTestSeries,
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final series = list[index];
                return _buildSeriesCard(series);
              },
              childCount: list.length,
            ),
          ),
        ),
      ],
    );
  }

  // ==================== iOS Native Series Card ====================
  Widget _buildSeriesCard(TestSeries series) {
    final bool isFree = series.isFree || series.price <= 0.0;
    final bool isPurchased = series.isPurchased || series.isAccessible;
    final bool isCompleted =
        series.isCompleted || _completedSeriesIds.contains(series.id);
    final double userRating = _userRatings[series.id] ?? series.rating;
    final bool hasUserRated = _userRatings.containsKey(series.id);

    // Accent colors based on test exam name
    final titleLower = series.title.toLowerCase();
    List<Color> gradientColors;
    IconData cardIcon;

    if (titleLower.contains('patwar')) {
      gradientColors = const [Color(0xFF34C759), Color(0xFF30D158)];
      cardIcon = CupertinoIcons.map_fill;
    } else if (titleLower.contains('ras')) {
      gradientColors = const [Color(0xFF007AFF), Color(0xFF5856D6)];
      cardIcon = CupertinoIcons.star_circle_fill;
    } else if (titleLower.contains('ia')) {
      gradientColors = const [Color(0xFF5856D6), Color(0xFFAF52DE)];
      cardIcon = CupertinoIcons.device_desktop;
    } else {
      gradientColors = const [Color(0xFFFF9500), Color(0xFFFF5E3A)];
      cardIcon = CupertinoIcons.doc_plaintext;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE5E5EA),
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              CupertinoPageRoute(
                builder: (context) => TestSeriesSubjectsScreen(
                  testSeriesId: series.id,
                  title: series.title,
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Squircle Icon + Title/Description + Badges
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: gradientColors,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: gradientColors[0].withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Icon(
                        cardIcon,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            series.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1C1C1E),
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            series.description.isNotEmpty
                                ? series.description
                                : 'Full-length Mock Test Series with detailed explanations and instant rank.',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF8E8E93),
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Status Badge (FittedBox to prevent overflow)
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: isCompleted
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F9EE),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFF34C759)
                                      .withValues(alpha: 0.3),
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    CupertinoIcons.checkmark_alt_circle_fill,
                                    color: Color(0xFF34C759),
                                    size: 13,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Done',
                                    style: TextStyle(
                                      color: Color(0xFF34C759),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : isPurchased
                              ? Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEBF5FF),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(0xFF007AFF)
                                          .withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        CupertinoIcons.lock_open_fill,
                                        color: Color(0xFF007AFF),
                                        size: 12,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'UNLOCKED',
                                        style: TextStyle(
                                          color: Color(0xFF007AFF),
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : isFree
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 9,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE8F9EE),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Text(
                                        'FREE',
                                        style: TextStyle(
                                          color: Color(0xFF34C759),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    )
                                  : Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 9,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF2F2F7),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '₹${series.price.toStringAsFixed(0)}',
                                        style: const TextStyle(
                                          color: Color(0xFF1C1C1E),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Specs / Metrics Row (Duration, Marks, Subjects)
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (series.duration > 0)
                      _buildMiniBadge(
                        CupertinoIcons.time,
                        '${series.duration} Mins',
                      ),
                    if (series.totalMarks > 0)
                      _buildMiniBadge(
                        CupertinoIcons.chart_bar_alt_fill,
                        '${series.totalMarks.toStringAsFixed(0)} Marks',
                      ),
                    if (series.subjects != null && series.subjects!.isNotEmpty)
                      _buildMiniBadge(
                        CupertinoIcons.square_stack_3d_up,
                        '${series.subjects!.length} Subjects',
                      )
                    else
                      _buildMiniBadge(
                        CupertinoIcons.layers_alt,
                        'Full Syllabus',
                      ),
                  ],
                ),

                // Subjects tags
                if (series.subjects != null && series.subjects!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: series.subjects!.take(3).map((sub) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF2F2F7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          sub.name,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF3C3C43),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],

                const SizedBox(height: 14),
                const Divider(
                  height: 1,
                  thickness: 0.5,
                  color: Color(0xFFE5E5EA),
                ),
                const SizedBox(height: 10),

                // Bottom Action Bar: Rating on Left, Share & CTA on Right
                Row(
                  children: [
                    // Rating Section (Interactive)
                    Flexible(
                      flex: 4,
                      child: GestureDetector(
                        onTap: () => _showRatingSheet(series),
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: hasUserRated
                                ? const Color(0xFFFFF7E6)
                                : const Color(0xFFF9F9FA),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: hasUserRated
                                  ? const Color(0xFFFF9500).withValues(alpha: 0.4)
                                  : const Color(0xFFE5E5EA),
                              width: 0.8,
                            ),
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  CupertinoIcons.star_fill,
                                  color: Color(0xFFFF9500),
                                  size: 15,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  userRating.toStringAsFixed(1),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1C1C1E),
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  hasUserRated ? 'You' : 'Rate',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: hasUserRated
                                        ? const Color(0xFFFF9500)
                                        : const Color(0xFF007AFF),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Right Buttons: Share & Start/Unlock
                    Flexible(
                      flex: 6,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          // Share Button
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(36, 36),
                            onPressed: () => _showShareSheet(series),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF2F2F7),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: const Icon(
                                CupertinoIcons.share,
                                size: 18,
                                color: Color(0xFF007AFF),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // CTA Button
                          Flexible(
                            child: CupertinoButton(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              minimumSize: const Size(36, 36),
                              color: isFree
                                  ? const Color(0xFF34C759)
                                  : (isPurchased
                                      ? const Color(0xFF007AFF)
                                      : const Color(0xFF1C1C1E)),
                              borderRadius: BorderRadius.circular(18),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  CupertinoPageRoute(
                                    builder: (context) =>
                                        TestSeriesSubjectsScreen(
                                      testSeriesId: series.id,
                                      title: series.title,
                                    ),
                                  ),
                                );
                              },
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      isCompleted
                                          ? 'Review'
                                          : (isFree
                                              ? 'Start Free'
                                              : (isPurchased
                                                  ? 'Start Test'
                                                  : 'Unlock • ₹${series.price.toStringAsFixed(0)}')),
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(
                                      CupertinoIcons.chevron_right,
                                      size: 13,
                                      color: Colors.white,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniBadge(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: const Color(0xFF8E8E93),
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF3C3C43),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== Empty State ====================
  Widget _buildEmptyState() {
    IconData emptyIcon;
    String emptyTitle;
    String emptySubtitle;
    String buttonText;
    VoidCallback onButtonTap;

    if (_searchQuery.trim().isNotEmpty) {
      emptyIcon = CupertinoIcons.search;
      emptyTitle = 'No Matches Found';
      emptySubtitle =
          'No test series matched "$_searchQuery". Check spelling or try a different exam name.';
      buttonText = 'Clear Search';
      onButtonTap = () {
        _searchController.clear();
        setState(() {
          _searchQuery = '';
        });
      };
    } else if (_selectedSegment == 3) {
      // Completed Tab
      emptyIcon = CupertinoIcons.checkmark_seal;
      emptyTitle = 'No Completed Tests Yet';
      emptySubtitle =
          'Practice makes perfect! Attempt a free test series to evaluate your preparation and track your score.';
      buttonText = 'Explore Free Tests';
      onButtonTap = () {
        setState(() {
          _selectedSegment = 1;
        });
      };
    } else if (_selectedSegment == 2) {
      // Purchased Tab
      emptyIcon = CupertinoIcons.lock_open;
      emptyTitle = 'No Purchased Series';
      emptySubtitle =
          'You have not unlocked any paid test series yet. Explore our comprehensive test series to boost your rank.';
      buttonText = 'Browse All Tests';
      onButtonTap = () {
        setState(() {
          _selectedSegment = 0;
        });
      };
    } else if (_selectedSegment == 1) {
      // Free Tab
      emptyIcon = CupertinoIcons.gift;
      emptyTitle = 'No Free Tests Right Now';
      emptySubtitle =
          'New mock tests are added regularly. Check all test series to see full available sets.';
      buttonText = 'View All Series';
      onButtonTap = () {
        setState(() {
          _selectedSegment = 0;
        });
      };
    } else {
      emptyIcon = CupertinoIcons.doc_text;
      emptyTitle = 'No Test Series Available';
      emptySubtitle = 'There are no active test series at this time.';
      buttonText = 'Refresh';
      onButtonTap = _fetchTestSeries;
    }

    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFF2F2F7),
                borderRadius: BorderRadius.circular(40),
              ),
              child: Icon(
                emptyIcon,
                size: 38,
                color: const Color(0xFF8E8E93),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              emptyTitle,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1C1C1E),
                letterSpacing: -0.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              emptySubtitle,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF8E8E93),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              color: const Color(0xFF007AFF),
              borderRadius: BorderRadius.circular(20),
              onPressed: onButtonTap,
              child: Text(
                buttonText,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== Error View ====================
  Widget _buildErrorView() {
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              CupertinoIcons.exclamationmark_triangle,
              color: Color(0xFFFF3B30),
              size: 48,
            ),
            const SizedBox(height: 12),
            const Text(
              'Could Not Load Tests',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1C1C1E),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _error ?? 'Please check your internet connection.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF8E8E93),
              ),
            ),
            const SizedBox(height: 16),
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              color: const Color(0xFF007AFF),
              borderRadius: BorderRadius.circular(20),
              onPressed: _fetchTestSeries,
              child: const Text(
                'Try Again',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
