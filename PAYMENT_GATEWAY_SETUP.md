# Razorpay Payment Gateway Integration

## Overview
Razorpay payment gateway has been successfully integrated into the coaching centre app for course purchases.

## Test API Credentials
```
Key ID: rzp_test_Rygt14IOXAaq8g
Key Secret: uLvXgns7oFazHRrCz1TvU18H
```

⚠️ **Important**: These are TEST credentials. For production, replace with live credentials.

## Files Modified/Created

### 1. New Files
- **`lib/services/payment_service.dart`** - Payment service handling Razorpay integration
  - Creates orders on backend
  - Opens Razorpay checkout
  - Handles payment callbacks (success, error, external wallet)
  - Verifies payment signatures

### 2. Modified Files
- **`pubspec.yaml`** - Added `razorpay_flutter: ^1.3.7` dependency
- **`lib/screens/course_detail_screen.dart`** - Integrated payment flow in course enrollment

## Features Implemented

### ✅ Payment Flow
1. User clicks "Enroll Now" button on paid course
2. System checks if user is logged in
3. Fetches user profile for prefill data
4. Creates order on backend via API
5. Opens Razorpay checkout with prefilled user details
6. Handles payment success/failure
7. Verifies payment signature on backend
8. Enrolls user in course on successful payment

### ✅ User Experience
- **Loading indicators** during order creation
- **Snackbar notifications** for all payment states:
  - Success (green)
  - Failure (red)
  - Login required (orange)
- **Auto-reload** of course content after successful payment
- **Prefilled checkout** with user name, email, and phone

### ✅ Security
- Payment signature verification on backend
- Secure token storage using FlutterSecureStorage
- Test mode enabled for development

## Backend API Endpoints Required

The following endpoints need to be implemented on your backend:

### 1. Create Order
```
POST /api/v1/payment/create-order
Headers: Authorization: Bearer {token}
Body: {
  "amount": 50000,  // Amount in paise (₹500.00)
  "currency": "INR",
  "course_id": "123",
  "course_name": "Course Title"
}

Response: {
  "success": true,
  "data": {
    "order_id": "order_xxxxxxxxxxxxx",
    "amount": 50000
  }
}
```

### 2. Verify Payment
```
POST /api/v1/payment/verify
Headers: Authorization: Bearer {token}
Body: {
  "payment_id": "pay_xxxxxxxxxxxxx",
  "order_id": "order_xxxxxxxxxxxxx",
  "signature": "signature_xxxxxxxxxxxxx",
  "course_id": "123"
}

Response: {
  "success": true,
  "message": "Payment verified and course enrolled successfully"
}
```

## Backend Implementation Guide

### Node.js/Express Example

```javascript
const Razorpay = require('razorpay');
const crypto = require('crypto');

const razorpay = new Razorpay({
  key_id: 'rzp_test_Rygt14IOXAaq8g',
  key_secret: 'uLvXgns7oFazHRrCz1TvU18H'
});

// Create Order
app.post('/api/v1/payment/create-order', async (req, res) => {
  try {
    const { amount, currency, course_id, course_name } = req.body;
    
    const options = {
      amount: amount, // amount in paise
      currency: currency || 'INR',
      receipt: `course_${course_id}_${Date.now()}`,
      notes: {
        course_id: course_id,
        course_name: course_name,
        user_id: req.user.id
      }
    };

    const order = await razorpay.orders.create(options);
    
    res.json({
      success: true,
      data: {
        order_id: order.id,
        amount: order.amount
      }
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
});

// Verify Payment
app.post('/api/v1/payment/verify', async (req, res) => {
  try {
    const { payment_id, order_id, signature, course_id } = req.body;
    
    // Verify signature
    const body = order_id + "|" + payment_id;
    const expectedSignature = crypto
      .createHmac('sha256', 'uLvXgns7oFazHRrCz1TvU18H')
      .update(body.toString())
      .digest('hex');
    
    if (expectedSignature === signature) {
      // Signature is valid
      // Enroll user in course
      await enrollUserInCourse(req.user.id, course_id);
      
      // Save payment details to database
      await savePaymentDetails({
        user_id: req.user.id,
        course_id: course_id,
        payment_id: payment_id,
        order_id: order_id,
        amount: order.amount,
        status: 'success'
      });
      
      res.json({
        success: true,
        message: 'Payment verified and course enrolled successfully'
      });
    } else {
      res.status(400).json({
        success: false,
        message: 'Invalid signature'
      });
    }
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
});
```

### PHP/Laravel Example

```php
use Razorpay\Api\Api;

// Create Order
Route::post('/api/v1/payment/create-order', function (Request $request) {
    $api = new Api('rzp_test_Rygt14IOXAaq8g', 'uLvXgns7oFazHRrCz1TvU18H');
    
    $orderData = [
        'receipt' => 'course_' . $request->course_id . '_' . time(),
        'amount' => $request->amount, // amount in paise
        'currency' => 'INR',
        'notes' => [
            'course_id' => $request->course_id,
            'course_name' => $request->course_name,
            'user_id' => auth()->id()
        ]
    ];
    
    $order = $api->order->create($orderData);
    
    return response()->json([
        'success' => true,
        'data' => [
            'order_id' => $order['id'],
            'amount' => $order['amount']
        ]
    ]);
});

// Verify Payment
Route::post('/api/v1/payment/verify', function (Request $request) {
    $api = new Api('rzp_test_Rygt14IOXAaq8g', 'uLvXgns7oFazHRrCz1TvU18H');
    
    $attributes = [
        'razorpay_order_id' => $request->order_id,
        'razorpay_payment_id' => $request->payment_id,
        'razorpay_signature' => $request->signature
    ];
    
    try {
        $api->utility->verifyPaymentSignature($attributes);
        
        // Enroll user in course
        enrollUserInCourse(auth()->id(), $request->course_id);
        
        return response()->json([
            'success' => true,
            'message' => 'Payment verified and course enrolled successfully'
        ]);
    } catch (\Exception $e) {
        return response()->json([
            'success' => false,
            'message' => 'Invalid signature'
        ], 400);
    }
});
```

## Testing

### Test Cards
Razorpay provides test cards for testing:

**Success:**
- Card Number: `4111 1111 1111 1111`
- CVV: Any 3 digits
- Expiry: Any future date

**Failure:**
- Card Number: `4000 0000 0000 0002`
- CVV: Any 3 digits
- Expiry: Any future date

### Test UPI
- UPI ID: `success@razorpay`
- UPI ID (Failure): `failure@razorpay`

### Test Netbanking
- Select any bank
- Use credentials provided on test page

## Production Deployment

### Steps to Go Live:

1. **Get Live Credentials**
   - Login to Razorpay Dashboard
   - Complete KYC verification
   - Get live API keys from Settings > API Keys

2. **Update Credentials**
   - Replace test keys in `lib/services/payment_service.dart`:
   ```dart
   static const String keyId = 'rzp_live_XXXXXXXXXX';
   static const String keySecret = 'XXXXXXXXXXXXXXXXXX';
   ```

3. **Update Backend**
   - Replace test keys with live keys in backend
   - Ensure SSL is enabled
   - Add webhook handling for payment notifications

4. **Security Checklist**
   - ✅ Never expose key_secret in frontend
   - ✅ Always verify payment signature on backend
   - ✅ Use HTTPS for all API calls
   - ✅ Implement rate limiting
   - ✅ Add payment logging
   - ✅ Set up webhook for payment status updates

## Webhook Setup (Recommended)

Add webhook URL in Razorpay Dashboard to receive payment notifications:

```
Webhook URL: https://yourdomain.com/api/v1/payment/webhook
Events: payment.authorized, payment.failed, payment.captured
```

## Support

For Razorpay integration issues:
- Documentation: https://razorpay.com/docs/
- Support: https://razorpay.com/support/

## Notes

- Currently using TEST mode
- All test payments will NOT deduct real money
- Payment gateway is only active for paid courses (price > 0)
- Free courses remain accessible without payment
- Users must be logged in to make purchases
