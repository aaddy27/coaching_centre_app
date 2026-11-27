import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../models/course.dart';
import '../models/subject.dart';
import '../models/video.dart';
import '../registration/login_screen.dart';
import '../services/api_service.dart';
import '../services/payment_service.dart';
import '../widgets/ios_components.dart';
import 'subject_videos_screen.dart';
import 'video_player_screen.dart';

class CourseDetailScreen extends StatefulWidget {
  final Course course;

  const CourseDetailScreen({super.key, required this.course});

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  late Course _course;
  List<Subject> _subjects = [];
  List<Video> _courseVideos = [];
  bool _isLoading = true;
  bool _isPurchasing = false;
  bool _hasPurchased = false;
  String? _pendingOrderId;
  int? _lastWatchedVideoId;
  late final PaymentService _paymentService;

  @override
  void initState() {
    super.initState();
    _course = widget.course;
    _hasPurchased = widget.course.isPurchased || widget.course.price <= 0;

    _paymentService = PaymentService();
    _paymentService.onPaymentSuccess = _handlePaymentSuccess;
    _paymentService.onPaymentError = _handlePaymentError;
    _paymentService.onExternalWallet = _handleExternalWallet;

    _loadCourseDetails();
  }

  @override
  void dispose() {
    _paymentService.dispose();
    super.dispose();
  }

  Future<void> _loadCourseDetails() async {
    setState(() => _isLoading = true);

    try {
      // 1. Fetch fresh course detail by slug if available
      if (_course.slug.isNotEmpty) {
        final detailRes = await ApiService.getCourseBySlug(_course.slug);
        if (detailRes['success'] == true && detailRes['data'] != null) {
          final rawCourse = detailRes['data']['course'] ?? detailRes['data'];
          if (rawCourse is Map<String, dynamic>) {
            _course = Course.fromJson(rawCourse);
          }
        }
      }

      // 2. Map subjects from course object or /subjects endpoint
      if (_course.subjects != null && _course.subjects!.isNotEmpty) {
        _subjects = _course.subjects!.map((cs) {
          return Subject(
            id: cs.id,
            name: cs.name,
            slug: cs.slug,
            description: cs.description,
            totalVideos: cs.videosCount ?? 0,
            completedVideos: 0,
            progressPercentage: 0,
            order: 0,
          );
        }).toList();
      } else {
        final subjectsRes = await ApiService.getCourseSubjects(_course.id);
        if (subjectsRes['success'] == true && subjectsRes['data'] != null) {
          final List list = subjectsRes['data']['subjects'] ?? [];
          _subjects = list.map((e) => Subject.fromJson(e)).toList();
        }
      }

      // 3. Load /courses/{id}/videos to get authoritative has_purchased & video lock status
      final videosRes = await ApiService.getCourseVideos(_course.id);
      final localProgMap = await ApiService.getLocalVideoProgressMap();
      final lastVideoId = await ApiService.getCourseLastVideoId(_course.id);

      if (videosRes['success'] == true && videosRes['data'] != null) {
        final data = videosRes['data'] as Map<String, dynamic>;
        final hasPurchasedApi = data['has_purchased'] == true;
        final List rawVideos = data['videos'] ?? [];
        _courseVideos = rawVideos.map((v) {
          final parsed = Video.fromJson(v);
          final local = localProgMap[parsed.id];
          if (local == null) return parsed;
          final lp = local['progress'] is int ? local['progress'] as int : 0;
          final ls = local['watched_seconds'] is int
              ? local['watched_seconds'] as int
              : 0;
          final lc = local['completed'] == true;
          return parsed.copyWithProgress(
            watchProgress: lp > parsed.watchProgress ? lp : parsed.watchProgress,
            watchedSeconds:
                ls > parsed.watchedSeconds ? ls : parsed.watchedSeconds,
            isWatched: parsed.isWatched || lc || lp >= 90,
          );
        }).toList();
        _hasPurchased =
            hasPurchasedApi || _course.isPurchased || _course.price <= 0;
        _lastWatchedVideoId = lastVideoId;

        if (_courseVideos.isNotEmpty) {
          final completedCount = _courseVideos
              .where((v) => v.isWatched || v.watchProgress >= 90)
              .length;
          await ApiService.saveCourseProgressSummary(
            courseId: _course.id,
            completedVideos: completedCount,
            totalVideos: _courseVideos.length,
          );
        }
      } else {
        _hasPurchased = _course.isPurchased || _course.price <= 0;
        _lastWatchedVideoId = lastVideoId;
      }

      // 4. Recompute subject-level progress from merged course videos
      if (_subjects.isNotEmpty && _courseVideos.isNotEmpty) {
        _subjects = _subjects.map((subj) {
          final subVideos =
              _courseVideos.where((v) => v.subjectId == subj.id).toList();
          if (subVideos.isEmpty) return subj;
          final comp = subVideos
              .where((v) => v.isWatched || v.watchProgress >= 90)
              .length;
          final pct = ((comp / subVideos.length) * 100).round().clamp(0, 100);
          return Subject(
            id: subj.id,
            name: subj.name,
            slug: subj.slug,
            description: subj.description,
            totalVideos: subVideos.length,
            totalDuration: subj.totalDuration,
            completedVideos: comp,
            progressPercentage: pct,
            thumbnail: subj.thumbnail,
            order: subj.order,
          );
        }).toList();
      }
    } catch (e) {
      debugPrint('Error loading course details: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _purchaseCourse() async {
    if (_isPurchasing) return;

    final isLoggedIn = await ApiService.isLoggedIn();
    if (!isLoggedIn) {
      if (!mounted) return;
      final goLogin = await showCupertinoDialog<bool>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('Sign In Required'),
          content: const Text('Please sign in to enroll or purchase this course.'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sign In'),
            ),
          ],
        ),
      );

      if (goLogin == true && mounted) {
        final loggedIn = await Navigator.push<bool>(
          context,
          CupertinoPageRoute(builder: (context) => const LoginScreen()),
        );
        if (loggedIn == true) {
          _loadCourseDetails();
        }
      }
      return;
    }

    setState(() => _isPurchasing = true);

    try {
      final profileResponse = await ApiService.getProfile();
      if (!mounted) return;

      final userData = profileResponse['data']?['user'] ??
          profileResponse['data'] ??
          <String, dynamic>{};
      final userName = userData['name']?.toString() ?? 'Student';
      final userEmail = userData['email']?.toString() ?? '';
      final userPhone = userData['phone']?.toString() ?? '';

      final orderResult = await _paymentService.initiateOrder(
        purchasableType: 'course',
        purchasableId: _course.id,
      );

      if (!mounted) return;

      if (orderResult['success'] == true) {
        if (orderResult['is_free_instant'] == true) {
          showIosToast(
            context,
            title: 'Enrolled!',
            message: 'Course access unlocked successfully.',
          );
          await _loadCourseDetails();
          return;
        }

        _pendingOrderId = orderResult['order_id']?.toString();
        final amount = (orderResult['amount'] as double?) ?? _course.price;

        _paymentService.openCheckout(
          amountRupees: amount > 0 ? amount : _course.price,
          orderId: _pendingOrderId ?? '',
          itemTitle: orderResult['item_title']?.toString().isNotEmpty == true
              ? orderResult['item_title'].toString()
              : _course.title,
          userName: userName,
          userEmail: userEmail,
          userPhone: userPhone,
        );
      } else {
        showIosToast(
          context,
          title: 'Order Failed',
          message: orderResult['message'] ?? 'Could not initiate purchase.',
          icon: CupertinoIcons.exclamationmark_circle_fill,
          iconColor: IosTheme.systemRed,
        );
      }
    } finally {
      if (mounted) setState(() => _isPurchasing = false);
    }
  }

  Future<void> _handlePaymentSuccess(PaymentSuccessResponse response) async {
    final orderId = (response.orderId != null && response.orderId!.isNotEmpty)
        ? response.orderId!
        : (_pendingOrderId ?? '');

    final verifyResult = await _paymentService.verifyPayment(
      orderId: orderId,
      paymentId: response.paymentId ?? '',
      signature: response.signature,
    );

    if (!mounted) return;

    if (verifyResult['success'] == true) {
      showIosToast(
        context,
        title: 'Enrollment Successful',
        message: verifyResult['message'] ?? 'Course unlocked!',
      );
      await _loadCourseDetails();
    } else {
      showIosToast(
        context,
        title: 'Verification Failed',
        message: verifyResult['message'] ?? 'Could not verify payment.',
        icon: CupertinoIcons.exclamationmark_circle_fill,
        iconColor: IosTheme.systemRed,
      );
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    if (!mounted) return;
    showIosToast(
      context,
      title: 'Payment Cancelled',
      message: response.message ?? 'Payment was not completed.',
      icon: CupertinoIcons.xmark_circle_fill,
      iconColor: IosTheme.systemRed,
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    if (!mounted) return;
    showIosToast(
      context,
      title: 'External Wallet',
      message: 'Selected: ${response.walletName ?? 'Wallet'}',
      icon: CupertinoIcons.creditcard_fill,
      iconColor: IosTheme.primaryBlue,
    );
  }

  void _openVideo(Video video) {
    final canPlay = _hasPurchased ||
        video.canPlay ||
        video.isPreview == true ||
        video.isFree == true;

    if (!canPlay) {
      showCupertinoDialog<void>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('Lecture Locked'),
          content: const Text(
            'Enroll in this course to unlock all video lectures and study materials.',
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () {
                Navigator.pop(ctx);
                _purchaseCourse();
              },
              child: Text(
                'Enroll • ₹${_course.price.toStringAsFixed(0)}',
              ),
            ),
          ],
        ),
      );
      return;
    }

    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => VideoPlayerScreen(
          video: video,
          playlist: _courseVideos,
          courseTitle: _course.title,
          courseId: _course.id,
          hasPurchased: _hasPurchased,
        ),
      ),
    ).then((_) => _loadCourseDetails());
  }

  Video? get _recommendedContinueVideo {
    final unlocked = _courseVideos.where((v) {
      return _hasPurchased ||
          v.canPlay ||
          v.isPreview == true ||
          v.isFree == true;
    }).toList();
    if (unlocked.isEmpty) return null;

    if (_lastWatchedVideoId != null) {
      final last = unlocked.where((v) => v.id == _lastWatchedVideoId).toList();
      if (last.isNotEmpty && !last.first.isWatched && last.first.watchProgress < 90) {
        return last.first;
      }
    }

    final firstIncomplete = unlocked
        .where((v) => !v.isWatched && v.watchProgress < 90)
        .toList();
    if (firstIncomplete.isNotEmpty) return firstIncomplete.first;
    return unlocked.first;
  }

  Widget _buildCourseProgressCard() {
    final total = _courseVideos.length;
    final completed = _courseVideos
        .where((v) => v.isWatched || v.watchProgress >= 90)
        .length;
    final sumProgress = _courseVideos.fold<int>(
      0,
      (acc, v) => acc + (v.isWatched ? 100 : v.watchProgress.clamp(0, 100)),
    );
    final pct = total > 0 ? (sumProgress / total).round().clamp(0, 100) : 0;
    final isAllDone = total > 0 && completed == total;
    final nextVideo = _recommendedContinueVideo;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
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
              const Text(
                'YOUR COURSE PROGRESS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: IosTheme.labelTertiary,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: (isAllDone
                          ? IosTheme.systemGreen
                          : IosTheme.primaryBlue)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$pct%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isAllDone
                        ? IosTheme.systemGreen
                        : IosTheme.primaryBlue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: pct / 100.0,
              minHeight: 8,
              backgroundColor: IosTheme.groupedBg,
              valueColor: AlwaysStoppedAnimation<Color>(
                isAllDone ? IosTheme.systemGreen : IosTheme.primaryBlue,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$completed of $total lecture${total == 1 ? '' : 's'} completed',
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: IosTheme.labelTertiary,
            ),
          ),
          if (nextVideo != null) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: IosTheme.separator),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nextVideo.watchProgress > 0 && !nextVideo.isWatched
                            ? 'CONTINUE WATCHING'
                            : 'UP NEXT',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: IosTheme.primaryBlue,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        nextVideo.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: IosTheme.labelPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  minimumSize: const Size(44, 34),
                  color: IosTheme.primaryBlue,
                  borderRadius: BorderRadius.circular(16),
                  onPressed: () => _openVideo(nextVideo),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        CupertinoIcons.play_fill,
                        color: Colors.white,
                        size: 13,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        nextVideo.watchProgress > 0 && !nextVideo.isWatched
                            ? 'Resume'
                            : 'Watch',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isFree = _course.price <= 0;

    return Scaffold(
      backgroundColor: IosTheme.groupedBg,
      appBar: IosNavBar(
        title: _course.title,
        subtitle: _course.examBoard?.name ?? 'Course Details',
      ),
      body: RefreshIndicator(
        onRefresh: _loadCourseDetails,
        color: IosTheme.primaryBlue,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Thumbnail Banner Card
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: _course.effectiveThumbnail != null
                      ? Image.network(
                          _course.effectiveThumbnail!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildPlaceholder(),
                        )
                      : _buildPlaceholder(),
                ),
              ),
              const SizedBox(height: 16),

              // Course Overview Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: IosTheme.separator, width: 0.6),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_course.examBoard != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: IosTheme.primaryBlue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Text(
                          _course.examBoard!.name.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: IosTheme.primaryBlue,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    Text(
                      _course.title,
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                        color: IosTheme.labelPrimary,
                        letterSpacing: -0.4,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _course.description,
                      style: const TextStyle(
                        fontSize: 14,
                        color: IosTheme.labelSecondary,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (_course.level != null && _course.level!.isNotEmpty)
                          _buildChip(CupertinoIcons.chart_bar, _course.level!),
                        if (_course.language != null &&
                            _course.language!.isNotEmpty)
                          _buildChip(CupertinoIcons.globe, _course.language!),
                        if (_course.duration != null &&
                            _course.duration!.isNotEmpty)
                          _buildChip(CupertinoIcons.time, _course.duration!),
                        _buildChip(
                          CupertinoIcons.play_circle,
                          '${_courseVideos.isNotEmpty ? _courseVideos.length : (_course.totalVideos ?? 0)} Videos',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1, color: IosTheme.separator),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'COURSE ACCESS',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: IosTheme.labelTertiary,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isFree
                                    ? 'FREE'
                                    : '₹${_course.price.toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: isFree
                                      ? IosTheme.systemGreen
                                      : IosTheme.labelPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_hasPurchased && !isFree)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              color: IosTheme.systemGreen.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  CupertinoIcons.checkmark_alt_circle_fill,
                                  color: IosTheme.systemGreen,
                                  size: 18,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Enrolled',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: IosTheme.systemGreen,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else if (!_hasPurchased)
                          SizedBox(
                            width: 170,
                            child: IosPrimaryButton(
                              label: isFree ? 'Enroll Free' : 'Enroll Now',
                              isLoading: _isPurchasing,
                              color: isFree
                                  ? IosTheme.systemGreen
                                  : IosTheme.primaryBlue,
                              onPressed: _purchaseCourse,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: CupertinoActivityIndicator(radius: 13)),
                )
              else ...[
                if (_courseVideos.isNotEmpty) _buildCourseProgressCard(),
                // Subjects Section
                if (_subjects.isNotEmpty) ...[
                  IosSectionLabel('Subjects (${_subjects.length})'),
                  IosGroupedCard(
                    children: List.generate(_subjects.length, (index) {
                      final subject = _subjects[index];
                      final isLast = index == _subjects.length - 1;
                      return Column(
                        children: [
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  CupertinoPageRoute(
                                    builder: (context) => SubjectVideosScreen(
                                      courseId: _course.id,
                                      subject: subject,
                                      isEnrolled: _hasPurchased,
                                      coursePrice: _course.price,
                                    ),
                                  ),
                                ).then((_) => _loadCourseDetails());
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 13,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 38,
                                      height: 38,
                                      decoration: BoxDecoration(
                                        color: IosTheme.primaryBlue
                                            .withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                        CupertinoIcons.book_fill,
                                        color: IosTheme.primaryBlue,
                                        size: 19,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  subject.name,
                                                  style: const TextStyle(
                                                    fontSize: 15.5,
                                                    fontWeight: FontWeight.w600,
                                                    color:
                                                        IosTheme.labelPrimary,
                                                  ),
                                                ),
                                              ),
                                              if (subject.progressPercentage >
                                                  0)
                                                Text(
                                                  '${subject.progressPercentage}%',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                    color: subject
                                                                .progressPercentage >=
                                                            100
                                                        ? IosTheme.systemGreen
                                                        : IosTheme.primaryBlue,
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            subject.completedVideos > 0
                                                ? '${subject.completedVideos}/${subject.totalVideos} lectures completed'
                                                : '${subject.totalVideos} Video Lecture${subject.totalVideos == 1 ? "" : "s"}',
                                            style: const TextStyle(
                                              fontSize: 12.5,
                                              color: IosTheme.labelTertiary,
                                            ),
                                          ),
                                          if (subject.progressPercentage >
                                              0) ...[
                                            const SizedBox(height: 6),
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(2),
                                              child: LinearProgressIndicator(
                                                value: (subject
                                                            .progressPercentage
                                                            .clamp(0, 100)) /
                                                    100.0,
                                                minHeight: 4,
                                                backgroundColor:
                                                    IosTheme.groupedBg,
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                        Color>(
                                                  subject.progressPercentage >=
                                                          100
                                                      ? IosTheme.systemGreen
                                                      : IosTheme.primaryBlue,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(
                                      CupertinoIcons.chevron_right,
                                      size: 15,
                                      color: Color(0xFFC7C7CC),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          if (!isLast)
                            const Divider(
                              height: 0.5,
                              indent: 64,
                              color: IosTheme.separator,
                            ),
                        ],
                      );
                    }),
                  ),
                  const SizedBox(height: 22),
                ],

                // All Lectures List (from GET /courses/{id}/videos)
                if (_courseVideos.isNotEmpty) ...[
                  IosSectionLabel('Video Lectures (${_courseVideos.length})'),
                  IosGroupedCard(
                    children: List.generate(_courseVideos.length, (index) {
                      final video = _courseVideos[index];
                      final isLast = index == _courseVideos.length - 1;
                      final canPlay = _hasPurchased ||
                          video.canPlay ||
                          video.isPreview == true ||
                          video.isFree == true;
                      final isCompleted =
                          video.isWatched || video.watchProgress >= 90;
                      final prog =
                          isCompleted ? 100 : video.watchProgress.clamp(0, 100);

                      return Column(
                        children: [
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _openVideo(video),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 38,
                                      height: 38,
                                      decoration: BoxDecoration(
                                        color: (isCompleted
                                                ? IosTheme.systemGreen
                                                : (canPlay
                                                    ? IosTheme.primaryBlue
                                                    : IosTheme.labelTertiary))
                                            .withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        isCompleted
                                            ? CupertinoIcons.checkmark_alt
                                            : (canPlay
                                                ? CupertinoIcons.play_fill
                                                : CupertinoIcons.lock_fill),
                                        color: isCompleted
                                            ? IosTheme.systemGreen
                                            : (canPlay
                                                ? IosTheme.primaryBlue
                                                : IosTheme.labelTertiary),
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            video.title,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 14.5,
                                              fontWeight: FontWeight.w600,
                                              color: IosTheme.labelPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Wrap(
                                            spacing: 6,
                                            runSpacing: 2,
                                            crossAxisAlignment:
                                                WrapCrossAlignment.center,
                                            children: [
                                              if (video.displayDuration != null)
                                                Text(
                                                  video.displayDuration!,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color:
                                                        IosTheme.labelTertiary,
                                                  ),
                                                ),
                                              if (video.isPreview == true ||
                                                  video.isFree == true)
                                                const Text(
                                                  '• Free Preview',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                    color: IosTheme.systemGreen,
                                                  ),
                                                ),
                                              if (isCompleted)
                                                const Text(
                                                  '• Completed',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                    color: IosTheme.systemGreen,
                                                  ),
                                                )
                                              else if (prog > 0)
                                                Text(
                                                  '• $prog% watched',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                    color: IosTheme.primaryBlue,
                                                  ),
                                                ),
                                            ],
                                          ),
                                          if (prog > 0 && !isCompleted) ...[
                                            const SizedBox(height: 6),
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(2),
                                              child: LinearProgressIndicator(
                                                value: prog / 100.0,
                                                minHeight: 3.5,
                                                backgroundColor:
                                                    IosTheme.groupedBg,
                                                valueColor:
                                                    const AlwaysStoppedAnimation<
                                                        Color>(
                                                  IosTheme.primaryBlue,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
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
                          if (!isLast)
                            const Divider(
                              height: 0.5,
                              indent: 64,
                              color: IosTheme.separator,
                            ),
                        ],
                      );
                    }),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: IosTheme.primaryBlue.withValues(alpha: 0.1),
      child: const Center(
        child: Icon(
          CupertinoIcons.play_rectangle_fill,
          size: 56,
          color: IosTheme.primaryBlue,
        ),
      ),
    );
  }

  Widget _buildChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
}
