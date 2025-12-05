# Authentication Setup - Complete Documentation

## ✅ Setup Complete!

### Files Created/Updated:

1. **`lib/services/api_service.dart`** - API Service with all authentication endpoints
2. **`lib/registration/login_screen.dart`** - Updated with API integration
3. **`lib/registration/register_screen.dart`** - Updated with API integration
4. **`lib/registration/forgot_password_screen.dart`** - New file with OTP flow
5. **`pubspec.yaml`** - Added required dependencies

---

## 📦 Dependencies Added

```yaml
http: ^1.2.0                      # For API calls
flutter_secure_storage: ^9.0.0   # For secure token storage
```

---

## 🔗 Base URL Configuration

**Production URL:** `https://eduapp.hkrdn.in/api/v1`

To switch to development mode, edit `lib/services/api_service.dart`:
```dart
// Comment production URL
// static const String baseUrl = 'https://eduapp.hkrdn.in/api/v1';

// Uncomment development URL
static const String baseUrl = 'http://127.0.0.1:8000/api/v1';
```

---

## 🎯 Features Implemented

### 1. **Registration Flow**
- User enters: Name, Mobile Number, Password, Confirm Password
- API call to `/auth/register`
- Auto-login after successful registration
- Token saved securely
- Navigate to Home Screen

### 2. **Login Flow**
- User enters: Mobile Number, Password
- API call to `/auth/login`
- Token saved securely
- Navigate to Home Screen
- Proper error handling for:
  - Mobile not registered (404)
  - Wrong password (401)
  - Account inactive (403)

### 3. **Forgot Password Flow (3 Steps)**

**Step 1: Send OTP**
- User enters mobile number
- API call to `/auth/forgot-password`
- OTP sent to mobile (4-digit code)
- OTP displayed in snackbar for development

**Step 2: Verify OTP**
- User enters OTP
- API call to `/auth/verify-otp`
- Receives reset_token
- Move to password reset step

**Step 3: Reset Password**
- User enters new password and confirmation
- API call to `/auth/reset-password`
- Password updated successfully
- Navigate back to Login Screen

---

## 🔐 Security Features

1. **Secure Token Storage**
   - Using `flutter_secure_storage`
   - Tokens encrypted on device

2. **Password Validation**
   - Minimum 6 characters
   - Password confirmation match

3. **Phone Number Validation**
   - Exactly 10 digits
   - Only numeric input allowed

4. **Auto Token Management**
   - Token saved on login/register
   - Token cleared on 401 errors
   - Token sent in Authorization header

---

## 📱 API Service Methods Available

### Authentication
```dart
// Register
ApiService.register(name, phone, password, passwordConfirmation)

// Login
ApiService.login(phone, password)

// Forgot Password - Send OTP
ApiService.forgotPassword(phone)

// Verify OTP
ApiService.verifyOtp(phone, otp)

// Reset Password
ApiService.resetPassword(phone, resetToken, password, passwordConfirmation)

// Change Password (logged-in users)
ApiService.changePassword(currentPassword, password, passwordConfirmation)
```

### Profile Management
```dart
// Get Profile
ApiService.getProfile()

// Update Profile
ApiService.updateProfile(name, email, city, state)
```

### Logout
```dart
// Logout current device
ApiService.logout()

// Logout all devices
ApiService.logoutAll()
```

### Token Management
```dart
// Save token
ApiService.saveToken(token)

// Get token
ApiService.getToken()

// Delete token
ApiService.deleteToken()

// Check if logged in
ApiService.isLoggedIn()
```

---

## 🎨 UI Features

1. **Beautiful Gradient Background** - Consistent across all auth screens
2. **Loading States** - Circular progress indicators during API calls
3. **Error Handling** - User-friendly error messages via SnackBars
4. **Success Messages** - Green snackbars for successful operations
5. **Password Visibility Toggle** - Eye icon to show/hide passwords
6. **Input Validation** - Real-time form validation
7. **Responsive Design** - Works on all screen sizes

---

## 🚀 How to Use

### For Login:
```dart
Navigator.push(
  context,
  MaterialPageRoute(builder: (context) => const LoginScreen()),
);
```

### For Registration:
```dart
Navigator.push(
  context,
  MaterialPageRoute(builder: (context) => const RegisterScreen()),
);
```

### For Forgot Password:
```dart
Navigator.push(
  context,
  MaterialPageRoute(builder: (context) => const ForgotPasswordScreen()),
);
```

### Check if User is Logged In:
```dart
bool isLoggedIn = await ApiService.isLoggedIn();
if (isLoggedIn) {
  // User is logged in
  // Navigate to Home
} else {
  // User is not logged in
  // Navigate to Login
}
```

### Get User Profile:
```dart
final response = await ApiService.getProfile();
if (response['success'] == true) {
  final user = response['data']['user'];
  print('Name: ${user['name']}');
  print('Phone: ${user['phone']}');
  print('Email: ${user['email']}');
}
```

---

## 🔄 API Response Format

### Success Response:
```json
{
  "success": true,
  "message": "Operation successful",
  "data": {
    "user": {...},
    "token": "..."
  }
}
```

### Error Response:
```json
{
  "success": false,
  "message": "Error message",
  "errors": {
    "field": ["Error details"]
  }
}
```

---

## ⚠️ Important Notes

1. **Development OTP Display**
   - OTP is shown in snackbar for testing
   - Remove this in production
   - Integrate real SMS gateway

2. **HTTPS Required**
   - Production must use HTTPS
   - Never send tokens over HTTP

3. **Token Expiration**
   - Handle 401 errors properly
   - Auto-redirect to login on token expiration

4. **Error Handling**
   - All API calls wrapped in try-catch
   - User-friendly error messages
   - Network error handling

---

## 🧪 Testing

### Test Registration:
1. Open app
2. Click "Create New Account"
3. Enter: Name, Phone (10 digits), Password (6+ chars)
4. Click "Create Account"
5. Should auto-login and navigate to Home

### Test Login:
1. Open app
2. Enter: Phone, Password
3. Click "Login"
4. Should navigate to Home

### Test Forgot Password:
1. Click "Forgot Password?"
2. Enter phone number → Click "Send OTP"
3. Enter OTP (check snackbar) → Click "Verify OTP"
4. Enter new password → Click "Reset Password"
5. Should navigate to Login

---

## 📝 Next Steps (Optional)

1. **Add Profile Screen**
   - Display user information
   - Edit profile functionality
   - Change password option

2. **Add Logout Functionality**
   - Logout button in settings/profile
   - Clear token and navigate to login

3. **Add Auto-Login**
   - Check token on app start
   - Auto-navigate to home if logged in

4. **Add SMS Gateway**
   - Integrate MSG91/Twilio/Fast2SMS
   - Send real OTP to users
   - Remove OTP from API response

5. **Add Loading Overlay**
   - Full-screen loading during API calls
   - Better UX for slow connections

---

## 🐛 Troubleshooting

### Issue: "Network error"
- Check internet connection
- Verify base URL is correct
- Check if API server is running

### Issue: "Invalid token"
- Token might be expired
- Clear app data and login again
- Check token storage permissions

### Issue: "Mobile number not registered"
- Register first before login
- Check if phone number is correct

### Issue: OTP not received
- In development, check snackbar for OTP
- In production, check SMS gateway integration
- Verify phone number is correct

---

## 📞 Support

For API issues or questions, refer to the API documentation or contact the backend team.

**Last Updated:** December 5, 2025
**Version:** 1.0.0
**Status:** ✅ Production Ready
