import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/test_series_models.dart';
import '../../services/api_service.dart';
import '../../widgets/ios_components.dart';
import 'test_history_screen.dart';
import 'test_series_subjects_screen.dart';

class TestSeriesListScreen extends StatefulWidget {
  const TestSeriesListScreen({super.key});

  @override
  State<TestSeriesListScreen> createState() => _TestSeriesListScreenState();
}

class _TestSeriesListScreenState extends State<TestSeriesListScreen> {
  bool _isLoading = true;
  List<TestSeries> _testSeriesList = [];
  String? _error;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int _selectedSegment = 0; // 0: All, 1: Free, 2: Purchased

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
      if (!mounted) return;

      if (response['success'] == true && response['data'] != null) {
        final raw = response['data'];
        final List<dynamic> list = raw is List
            ? raw
            : (raw is Map && raw['data'] is List
                ? raw['data']
                : (raw is Map && raw['test_series'] is List
                    ? raw['test_series']
                    : []));
        final parsedList = list.map((e) => TestSeries.fromJson(e)).toList();

        setState(() {
          _testSeriesList = parsedList;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = ApiService.extractErrorMessage(
            response,
            fallback: 'Failed to load test series',
          );
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Error loading tests: $e';
        _isLoading = false;
      });
    }
  }

  List<TestSeries> get _filteredSeriesList {
    return _testSeriesList.where((series) {
      if (_selectedSegment == 1) {
        final isFree = series.isFree || series.price <= 0.0;
        if (!isFree) return false;
      } else if (_selectedSegment == 2) {
        final isPurchased = series.isPurchased || series.isAccessible;
        if (!isPurchased) return false;
      }

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

  void _showShareSheet(TestSeries series) {
    final shareUrl = 'https://eduapp.hkrdn.in/test-series/${series.id}';
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
            color: IosTheme.labelPrimary,
          ),
        ),
        message: Text(
          'Price: $priceText • $subjectsText\nShare this test series with friends & study groups',
          style: const TextStyle(fontSize: 13, color: IosTheme.labelTertiary),
        ),
        actions: <CupertinoActionSheetAction>[
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(sheetContext);
              Clipboard.setData(ClipboardData(text: shareUrl));
              showIosToast(
                context,
                title: 'Link Copied',
                message: 'Test series link copied to clipboard.',
                icon: CupertinoIcons.link,
                iconColor: IosTheme.primaryBlue,
              );
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.link, color: IosTheme.primaryBlue, size: 20),
                SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Copy Test Series Link',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: IosTheme.primaryBlue,
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
              showIosToast(
                context,
                title: 'Ready to Share',
                message: 'Message copied! Paste in WhatsApp or Telegram.',
                icon: CupertinoIcons.chat_bubble_2_fill,
                iconColor: IosTheme.systemGreen,
              );
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  CupertinoIcons.chat_bubble_2_fill,
                  color: IosTheme.systemGreen,
                  size: 20,
                ),
                SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Share on WhatsApp / Telegram',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: IosTheme.systemGreen,
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
              color: IosTheme.primaryBlue,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IosTheme.groupedBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildIosHeader(),
            _buildSearchBar(),
            _buildSegmentedTabs(),
            const Divider(height: 1, thickness: 0.5, color: IosTheme.separator),
            Expanded(
              child: _isLoading
                  ? const Center(child: CupertinoActivityIndicator(radius: 14))
                  : _error != null
                      ? _buildErrorView()
                      : _buildListView(),
            ),
          ],
        ),
      ),
    );
  }

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
                      color: IosTheme.primaryBlue,
                      size: 22,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Back',
                      style: TextStyle(
                        color: IosTheme.primaryBlue,
                        fontSize: 17,
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
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Test Series',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: IosTheme.labelPrimary,
                        letterSpacing: -0.6,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Exam-oriented mock papers & scorecards',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: IosTheme.labelTertiary,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: const Size(36, 36),
                onPressed: () {
                  Navigator.push(
                    context,
                    CupertinoPageRoute(
                      builder: (_) => const TestHistoryScreen(),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: IosTheme.groupedBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    CupertinoIcons.doc_chart_fill,
                    size: 18,
                    color: IosTheme.systemIndigo,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: const Size(36, 36),
                onPressed: _fetchTestSeries,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: IosTheme.groupedBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    CupertinoIcons.arrow_clockwise,
                    size: 18,
                    color: IosTheme.primaryBlue,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: CupertinoSearchTextField(
        controller: _searchController,
        placeholder: 'Search test series, exam, subjects...',
        backgroundColor: IosTheme.groupedBg,
        borderRadius: BorderRadius.circular(12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        style: const TextStyle(fontSize: 15, color: IosTheme.labelPrimary),
        placeholderStyle:
            const TextStyle(fontSize: 15, color: IosTheme.labelTertiary),
        onChanged: (value) => setState(() => _searchQuery = value),
        onSuffixTap: () {
          _searchController.clear();
          setState(() => _searchQuery = '');
        },
      ),
    );
  }

  Widget _buildSegmentedTabs() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: SizedBox(
        width: double.infinity,
        child: CupertinoSlidingSegmentedControl<int>(
          groupValue: _selectedSegment,
          backgroundColor: const Color(0xFFEFEFF4),
          thumbColor: Colors.white,
          padding: const EdgeInsets.all(3),
          children: {
            0: _buildSegmentItem('All', _allCount, 0),
            1: _buildSegmentItem('Free', _freeCount, 1),
            2: _buildSegmentItem('Unlocked', _purchasedCount, 2),
          },
          onValueChanged: (val) {
            if (val != null) setState(() => _selectedSegment = val);
          },
        ),
      ),
    );
  }

  Widget _buildSegmentItem(String title, int count, int index) {
    final isSelected = _selectedSegment == index;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
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
                    ? IosTheme.labelPrimary
                    : IosTheme.labelTertiary,
              ),
            ),
            if (count > 0 || index == 0) ...[
              const SizedBox(width: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: isSelected
                      ? IosTheme.primaryBlue
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

  Widget _buildListView() {
    final list = _filteredSeriesList;
    if (list.isEmpty) return _buildEmptyState();

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      slivers: [
        CupertinoSliverRefreshControl(onRefresh: _fetchTestSeries),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildSeriesCard(list[index], index),
              childCount: list.length,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSeriesCard(TestSeries series, int index) {
    final bool isFree = series.isFree || series.price <= 0.0;
    final bool isPurchased = series.isPurchased || series.isAccessible;

    const palette = [
      IosTheme.primaryBlue,
      IosTheme.systemIndigo,
      IosTheme.systemGreen,
      IosTheme.systemOrange,
    ];
    final Color cardColor = palette[index % palette.length];
    final titleLower = series.title.toLowerCase();
    final IconData cardIcon = titleLower.contains('jee') ||
            titleLower.contains('physic')
        ? CupertinoIcons.bolt_fill
        : (titleLower.contains('neet') || titleLower.contains('bio')
            ? CupertinoIcons.heart_fill
            : CupertinoIcons.doc_checkmark_fill);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: IosTheme.separator, width: 0.8),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              CupertinoPageRoute(
                builder: (_) => TestSeriesSubjectsScreen(
                  testSeriesId: series.id,
                  title: series.title,
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(cardIcon, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            series.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w700,
                              color: IosTheme.labelPrimary,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            series.description.isNotEmpty
                                ? series.description
                                : 'Full-length Mock Test Series with detailed explanations.',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              color: IosTheme.labelTertiary,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (isPurchased && !isFree)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: IosTheme.primaryBlue.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'UNLOCKED',
                          style: TextStyle(
                            color: IosTheme.primaryBlue,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    else if (isFree)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: IosTheme.systemGreen.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'FREE',
                          style: TextStyle(
                            color: IosTheme.systemGreen,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: IosTheme.groupedBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '₹${series.price.toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: IosTheme.labelPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
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
                      ),
                  ],
                ),
                if (series.subjects != null && series.subjects!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: series.subjects!.take(4).map((sub) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: IosTheme.groupedBg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          sub.name,
                          style: const TextStyle(
                            fontSize: 11,
                            color: IosTheme.labelSecondary,
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
                  color: IosTheme.separator,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      isFree
                          ? 'Free Practice'
                          : (isPurchased
                              ? 'Access Granted'
                              : '₹${series.price.toStringAsFixed(0)} One-Time'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isPurchased || isFree
                            ? IosTheme.systemGreen
                            : IosTheme.labelSecondary,
                      ),
                    ),
                    const Spacer(),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(36, 36),
                      onPressed: () => _showShareSheet(series),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: IosTheme.groupedBg,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Icon(
                          CupertinoIcons.share,
                          size: 18,
                          color: IosTheme.primaryBlue,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      minimumSize: const Size(36, 36),
                      color: isFree
                          ? IosTheme.systemGreen
                          : (isPurchased
                              ? IosTheme.primaryBlue
                              : IosTheme.labelPrimary),
                      borderRadius: BorderRadius.circular(18),
                      onPressed: () {
                        Navigator.push(
                          context,
                          CupertinoPageRoute(
                            builder: (_) => TestSeriesSubjectsScreen(
                              testSeriesId: series.id,
                              title: series.title,
                            ),
                          ),
                        );
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isFree
                                ? 'Start Free'
                                : (isPurchased
                                    ? 'Open Tests'
                                    : 'Unlock • ₹${series.price.toStringAsFixed(0)}'),
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
        color: IosTheme.groupedBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: IosTheme.labelTertiary),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: IosTheme.labelSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    IconData emptyIcon;
    String emptyTitle;
    String emptySubtitle;
    String buttonText;
    VoidCallback onButtonTap;

    if (_searchQuery.trim().isNotEmpty) {
      emptyIcon = CupertinoIcons.search;
      emptyTitle = 'No Matches Found';
      emptySubtitle = 'No test series matched "$_searchQuery".';
      buttonText = 'Clear Search';
      onButtonTap = () {
        _searchController.clear();
        setState(() => _searchQuery = '');
      };
    } else if (_selectedSegment == 2) {
      emptyIcon = CupertinoIcons.lock_open;
      emptyTitle = 'No Unlocked Series';
      emptySubtitle =
          'You have not unlocked any test series yet. Browse all packages to get started.';
      buttonText = 'Browse All Tests';
      onButtonTap = () => setState(() => _selectedSegment = 0);
    } else if (_selectedSegment == 1) {
      emptyIcon = CupertinoIcons.gift;
      emptyTitle = 'No Free Tests Right Now';
      emptySubtitle =
          'New mock tests are added regularly. Check all test series.';
      buttonText = 'View All Series';
      onButtonTap = () => setState(() => _selectedSegment = 0);
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
                color: Colors.white,
                borderRadius: BorderRadius.circular(40),
                border: Border.all(color: IosTheme.separator),
              ),
              child: Icon(emptyIcon, size: 38, color: IosTheme.labelTertiary),
            ),
            const SizedBox(height: 18),
            Text(
              emptyTitle,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: IosTheme.labelPrimary,
                letterSpacing: -0.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              emptySubtitle,
              style: const TextStyle(
                fontSize: 13,
                color: IosTheme.labelTertiary,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              color: IosTheme.primaryBlue,
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
              color: IosTheme.systemRed,
              size: 48,
            ),
            const SizedBox(height: 12),
            const Text(
              'Could Not Load Tests',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: IosTheme.labelPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _error ?? 'Please check your internet connection.',
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 13, color: IosTheme.labelTertiary),
            ),
            const SizedBox(height: 16),
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              color: IosTheme.primaryBlue,
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
