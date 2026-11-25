import 'package:flutter/foundation.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'api_service.dart';

class PaymentService {
  late final Razorpay _razorpay;

  // Razorpay Test Key
  static const String keyId = 'rzp_test_Rygt14IOXAaq8g';

  // Callbacks
  Function(PaymentSuccessResponse)? onPaymentSuccess;
  Function(PaymentFailureResponse)? onPaymentError;
  Function(ExternalWalletResponse)? onExternalWallet;

  PaymentService() {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    debugPrint('Payment Success: ${response.paymentId} | Order: ${response.orderId}');
    onPaymentSuccess?.call(response);
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    debugPrint('Payment Error: ${response.code} - ${response.message}');
    onPaymentError?.call(response);
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    debugPrint('External Wallet: ${response.walletName}');
    onExternalWallet?.call(response);
  }

  /// Initiate Purchase / Create Order on Backend
  /// POST /purchase with purchasable_type ('course' | 'test') & purchasable_id
  Future<Map<String, dynamic>> initiateOrder({
    required String purchasableType,
    required int purchasableId,
    String paymentProvider = 'razorpay',
  }) async {
    final result = await ApiService.initiatePurchase(
      purchasableType: purchasableType,
      purchasableId: purchasableId,
      paymentProvider: paymentProvider,
    );

    if (result['success'] == true) {
      final data = result['data'] as Map<String, dynamic>? ?? {};
      final status = data['status']?.toString().toLowerCase() ?? 'pending';
      final amountRaw = data['amount'];
      final amountNum = amountRaw is num
          ? amountRaw.toDouble()
          : (double.tryParse('${amountRaw ?? 0}') ?? 0.0);

      return {
        'success': true,
        'order_id': data['order_id']?.toString() ?? '',
        'amount': amountNum,
        'currency': data['currency']?.toString() ?? 'INR',
        'item_title': data['item_title']?.toString() ?? '',
        'status': status,
        'is_free_instant': status == 'completed' || amountNum <= 0,
        'message': result['message'] ?? 'Purchase initiated successfully',
      };
    }

    return {
      'success': false,
      'message': ApiService.extractErrorMessage(
        result,
        fallback: 'Failed to create order',
      ),
    };
  }

  /// Open Razorpay Native Checkout Sheet
  void openCheckout({
    required double amountRupees,
    required String orderId,
    required String itemTitle,
    required String userName,
    required String userEmail,
    required String userPhone,
  }) {
    final options = {
      'key': keyId,
      'amount': (amountRupees * 100).round(), // paise
      'currency': 'INR',
      'name': 'Olive Learnings',
      'description': itemTitle,
      'order_id': orderId,
      'prefill': {
        'contact': userPhone,
        'email': userEmail.isNotEmpty ? userEmail : 'student@olivelearnings.in',
        'name': userName,
      },
      'theme': {
        'color': '#007AFF', // Apple iOS System Blue
      },
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      debugPrint('Error opening Razorpay: $e');
    }
  }

  /// Verify Payment Gateway Callback on Backend
  /// POST /payment/verify
  Future<Map<String, dynamic>> verifyPayment({
    required String orderId,
    required String paymentId,
    String? signature,
  }) async {
    final result = await ApiService.verifyPayment(
      orderId: orderId,
      paymentId: paymentId,
      signature: signature,
    );

    if (result['success'] == true) {
      return {
        'success': true,
        'message': result['message'] ?? 'Payment verified successfully! Access granted.',
        'data': result['data'],
      };
    }

    return {
      'success': false,
      'message': ApiService.extractErrorMessage(
        result,
        fallback: 'Payment verification failed',
      ),
    };
  }

  void dispose() {
    _razorpay.clear();
  }
}
