import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../models/test_series_models.dart';
import '../../registration/login_screen.dart';
import '../../services/api_service.dart';
import '../../services/payment_service.dart';
import '../../widgets/ios_components.dart';
import 'subject_tests_screen.dart';

class TestSeriesSubjectsScreen extends StatefulWidget {
  final int testSeriesId;
  final String title;

  const TestSeriesSubjectsScreen({
    super.key,
    required this.testSeriesId,
    required this.title,
  });

  @override
  State<TestSeriesSubjectsScreen> createState() =>
      _TestSeriesSubjectsScreenState();
}

class _TestSeriesSubjectsScreenState extends State<TestSeriesSubjectsScreen> {
  bool _isLoading = true;
  bool _isPurchasing = false;
  TestSeries? _seriesDetails;
  String? _error;
  String? _pendingOrderId;
  late final PaymentService _paymentService;

  @override
  void initState() {
    super.initState();
    _paymentService = PaymentService();
    _paymentService.onPaymentSuccess = _handlePaymentSuccess;
    _paymentService.onPaymentError = _handlePaymentError;
    _paymentService.onExternalWallet = _handleExternalWallet;
    _fetchSubjects();
  }

  @override
  void dispose() {
    _paymentService.dispose();
    super.dispose();
  }

  Future<void> _fetchSubjects() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Load test series detail for price/metadata + subjects endpoint
      final results = await Future.wait([
        ApiService.getTestSeriesDetail(widget.testSeriesId),
        ApiService.getTestSeriesSubjects(widget.testSeriesId),
      ]);

      if (!mounted) return;

      final detailRes = results[0];
      final subjectsRes = results[1];

      if (subjectsRes['success'] == true && subjectsRes['data'] != null) {
        var series = TestSeries.fromJson(subjectsRes['data']);

        if (detailRes['success'] == true && detailRes['data'] != null) {
          final detail = TestSeries.fromJson(detailRes['data']);
          series = series.copyWith(
            price: detail.price > 0 ? detail.price : series.price,
            isFree: detail.isFree,
            isPurchased: detail.isPurchased || series.isPurchased,
            isAccessible: detail.isAccessible || series.isAccessible,
            description: detail.description.isNotEmpty
                ? detail.description
                : series.description,
          );
        }

        setState(() {
          _seriesDetails = series;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = ApiService.extractErrorMessage(
            subjectsRes,
            fallback: 'Failed to load test series subjects.',
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

  Future<void> _handlePurchase() async {
    if (_isPurchasing || _seriesDetails == null) return;

    final isLoggedIn = await ApiService.isLoggedIn();
    if (!isLoggedIn) {
      if (!mounted) return;
      final goLogin = await showCupertinoDialog<bool>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('Sign In Required'),
          content: const Text(
            'Please sign in to unlock and attempt this test series.',
          ),
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
        final ok = await Navigator.push<bool>(
          context,
          CupertinoPageRoute(builder: (context) => const LoginScreen()),
        );
        if (ok == true) _fetchSubjects();
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
        purchasableType: 'test',
        purchasableId: widget.testSeriesId,
      );

      if (!mounted) return;

      if (orderResult['success'] == true) {
        if (orderResult['is_free_instant'] == true) {
          showIosToast(
            context,
            title: 'Access Granted',
            message: 'Test series unlocked!',
          );
          await _fetchSubjects();
          return;
        }

        _pendingOrderId = orderResult['order_id']?.toString();
        final amount =
            (orderResult['amount'] as double?) ?? _seriesDetails!.price;

        _paymentService.openCheckout(
          amountRupees: amount > 0 ? amount : _seriesDetails!.price,
          orderId: _pendingOrderId ?? '',
          itemTitle: orderResult['item_title']?.toString().isNotEmpty == true
              ? orderResult['item_title'].toString()
              : widget.title,
          userName: userName,
          userEmail: userEmail,
          userPhone: userPhone,
        );
      } else {
        showIosToast(
          context,
          title: 'Checkout Error',
          message: orderResult['message'] ?? 'Could not create order.',
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
        title: 'Payment Verified',
        message: verifyResult['message'] ?? 'Test series unlocked!',
      );
      await _fetchSubjects();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IosTheme.groupedBg,
      appBar: IosNavBar(title: widget.title, subtitle: 'Test Series'),
      body: _isLoading
          ? const Center(child: CupertinoActivityIndicator(radius: 14))
          : _error != null
              ? _buildError()
              : _seriesDetails == null
                  ? const Center(child: Text('No details found'))
                  : RefreshIndicator(
                      onRefresh: _fetchSubjects,
                      color: IosTheme.primaryBlue,
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (!_seriesDetails!.isPurchased &&
                                !_seriesDetails!.isAccessible &&
                                !_seriesDetails!.isFree)
                              _buildPurchaseCard()
                            else
                              _buildAccessGrantedBanner(),
                            const SizedBox(height: 20),
                            IosSectionLabel(
                              'Subjects (${_seriesDetails!.subjects?.length ?? 0})',
                            ),
                            if (_seriesDetails!.subjects != null &&
                                _seriesDetails!.subjects!.isNotEmpty)
                              IosGroupedCard(
                                children: List.generate(
                                  _seriesDetails!.subjects!.length,
                                  (index) => _buildSubjectRow(
                                    _seriesDetails!.subjects![index],
                                    index ==
                                        _seriesDetails!.subjects!.length - 1,
                                  ),
                                ),
                              )
                            else
                              const Padding(
                                padding: EdgeInsets.all(24),
                                child: Center(
                                  child: Text(
                                    'No subjects found in this test series.',
                                    style: TextStyle(
                                      color: IosTheme.labelTertiary,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
    );
  }

  Widget _buildAccessGrantedBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: IosTheme.systemGreen.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: IosTheme.systemGreen.withValues(alpha: 0.28),
        ),
      ),
      child: const Row(
        children: [
          Icon(
            CupertinoIcons.checkmark_alt_circle_fill,
            color: IosTheme.systemGreen,
            size: 22,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Access Unlocked • Attempt any subject mock test below',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: IosTheme.systemGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPurchaseCard() {
    return Container(
      padding: const EdgeInsets.all(18),
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
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: IosTheme.systemOrange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  CupertinoIcons.lock_fill,
                  color: IosTheme.systemOrange,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Unlock Full Test Series',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: IosTheme.labelPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _seriesDetails!.price > 0
                          ? 'Get full access to all mock tests & solutions for ₹${_seriesDetails!.price.toStringAsFixed(0)}'
                          : 'Get instant access to all mock tests & solutions',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: IosTheme.labelTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          IosPrimaryButton(
            label: _seriesDetails!.price > 0
                ? 'Unlock Now • ₹${_seriesDetails!.price.toStringAsFixed(0)}'
                : 'Unlock Free',
            isLoading: _isPurchasing,
            icon: CupertinoIcons.creditcard_fill,
            onPressed: _handlePurchase,
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectRow(TestSeriesSubject subject, bool isLast) {
    final bool isLocked = !_seriesDetails!.isAccessible &&
        !_seriesDetails!.isFree &&
        !subject.isAccessible;

    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              if (isLocked) {
                showIosToast(
                  context,
                  title: 'Test Series Locked',
                  message: 'Unlock the test series above to attempt mock tests.',
                  icon: CupertinoIcons.lock_fill,
                  iconColor: IosTheme.systemOrange,
                );
              } else {
                Navigator.push(
                  context,
                  CupertinoPageRoute(
                    builder: (context) => SubjectTestsScreen(
                      testSeriesId: widget.testSeriesId,
                      subjectId: subject.id,
                      title: subject.name,
                      seriesTitle: widget.title,
                    ),
                  ),
                );
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: (isLocked
                              ? IosTheme.labelTertiary
                              : IosTheme.primaryBlue)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isLocked
                          ? CupertinoIcons.lock_fill
                          : CupertinoIcons.doc_text_fill,
                      color: isLocked
                          ? IosTheme.labelTertiary
                          : IosTheme.primaryBlue,
                      size: 19,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                          '${subject.testCount} Mock Paper${subject.testCount == 1 ? "" : "s"}'
                          '${subject.questionCount > 0 ? " • ${subject.questionCount} Questions" : ""}',
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
            indent: 66,
            color: IosTheme.separator,
          ),
      ],
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
              width: 150,
              child: IosPrimaryButton(label: 'Retry', onPressed: _fetchSubjects),
            ),
          ],
        ),
      ),
    );
  }
}
