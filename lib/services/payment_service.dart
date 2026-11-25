import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_service.dart';

class PaymentService {
  late Razorpay _razorpay;
  
  // Razorpay Test Credentials
  static const String keyId = 'rzp_test_Rygt14IOXAaq8g';
  static const String keySecret = 'uLvXgns7oFazHRrCz1TvU18H';
  
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
    debugPrint('✅ Payment Success: ${response.paymentId}');
    debugPrint('Order ID: ${response.orderId}');
    debugPrint('Signature: ${response.signature}');
    
    if (onPaymentSuccess != null) {
      onPaymentSuccess!(response);
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    debugPrint('❌ Payment Error: ${response.code} - ${response.message}');
    
    if (onPaymentError != null) {
      onPaymentError!(response);
    }
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    debugPrint('💳 External Wallet: ${response.walletName}');
    
    if (onExternalWallet != null) {
      onExternalWallet!(response);
    }
  }

  /// Create Razorpay Order on Backend
  Future<Map<String, dynamic>> createOrder({
    required int amount, // Amount in rupees (will be converted to paise)
    required String courseId,
    required String courseName,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/payment/create-order'),
        headers: await ApiService.authHeaders,
        body: jsonEncode({
          'amount': amount * 100, // Convert to paise
          'currency': 'INR',
          'course_id': courseId,
          'course_name': courseName,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'order_id': data['data']['order_id'],
          'amount': data['data']['amount'],
        };
      } else {
        return {
          'success': false,
          'message': 'Failed to create order: ${response.body}',
        };
      }
    } catch (e) {
      debugPrint('❌ Create Order Error: $e');
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  /// Open Razorpay Checkout
  void openCheckout({
    required int amount, // Amount in rupees
    required String orderId,
    required String courseName,
    required String userName,
    required String userEmail,
    required String userPhone,
  }) {
    var options = {
      'key': keyId,
      'amount': amount * 100, // Amount in paise
      'currency': 'INR',
      'name': 'Coaching Centre',
      'description': courseName,
      'order_id': orderId,
      'prefill': {
        'contact': userPhone,
        'email': userEmail,
        'name': userName,
      },
      'theme': {
        'color': '#6366F1', // Indigo color
      },
      'modal': {
        'ondismiss': () {
          debugPrint('Payment dismissed by user');
        }
      }
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      debugPrint('❌ Error opening Razorpay: $e');
    }
  }

  /// Verify Payment Signature on Backend
  Future<Map<String, dynamic>> verifyPayment({
    required String paymentId,
    required String orderId,
    required String signature,
    required String courseId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/payment/verify'),
        headers: await ApiService.authHeaders,
        body: jsonEncode({
          'payment_id': paymentId,
          'order_id': orderId,
          'signature': signature,
          'course_id': courseId,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'message': data['message'] ?? 'Payment verified successfully',
        };
      } else {
        return {
          'success': false,
          'message': 'Payment verification failed',
        };
      }
    } catch (e) {
      debugPrint('❌ Verify Payment Error: $e');
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  /// Dispose Razorpay instance
  void dispose() {
    _razorpay.clear();
  }
}
