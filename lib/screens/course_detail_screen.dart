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
      if (videosRes['success'] == true && videosRes['data'] != null) {
        final data = videosRes['data'] as Map<String, dynamic>;
        final hasPurchasedApi = data['has_purchased'] == true;
        final List rawVideos = data['videos'] ?? [];
        _courseVideos = rawVideos.map((v) => Video.fromJson(v)).toList();
        _hasPurchased =
            hasPurchasedApi || _course.isPurchased || _course.price <= 0;
      } else {
        _hasPurchased = _course.isPurchased || _course.price <= 0;
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
        builder: (context) => VideoPlayerScreen(video: video),
      ),
    ).then((_) => _loadCourseDetails());
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
                                          Text(
                                            subject.name,
                                            style: const TextStyle(
                                              fontSize: 15.5,
                                              fontWeight: FontWeight.w600,
                                              color: IosTheme.labelPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${subject.totalVideos} Video Lecture${subject.totalVideos == 1 ? "" : "s"}',
                                            style: const TextStyle(
                                              fontSize: 12.5,
                                              color: IosTheme.labelTertiary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
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
                                        color: (canPlay
                                                ? IosTheme.primaryBlue
                                                : IosTheme.labelTertiary)
                                            .withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        canPlay
                                            ? CupertinoIcons.play_fill
                                            : CupertinoIcons.lock_fill,
                                        color: canPlay
                                            ? IosTheme.primaryBlue
                                            : IosTheme.labelTertiary,
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
                                          Row(
                                            children: [
                                              if (video.displayDuration != null)
                                                Text(
                                                  video.displayDuration!,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: IosTheme.labelTertiary,
                                                  ),
                                                ),
                                              if (video.isPreview == true ||
                                                  video.isFree == true) ...[
                                                if (video.displayDuration !=
                                                    null)
                                                  const Text(
                                                    ' • ',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color:
                                                          IosTheme.labelTertiary,
                                                    ),
                                                  ),
                                                const Text(
                                                  'Free Preview',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                    color: IosTheme.systemGreen,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
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
