# ToyyibPay Integration Setup Guide

This guide will help you set up ToyyibPay payment integration for your Flutter app.

## Prerequisites

1. A ToyyibPay merchant account
2. Access to ToyyibPay sandbox environment (dev.toyyibpay.com)
3. Your ToyyibPay API credentials

## Step 1: Get ToyyibPay Credentials

1. Log in to your ToyyibPay merchant account
2. Navigate to the API section
3. Get your:
   - Secret Key
   - Category Code

## Step 2: Update Configuration

Open `lib/config/toyyibpay_config.dart` and update the following values:

```dart
// Replace with your actual ToyyibPay credentials
static const String secretKey = 'your_actual_secret_key';
static const String categoryCode = 'your_actual_category_code';

// Update return URLs to match your app
static const String returnUrl = 'https://your-app-domain.com/payment-success';
static const String callbackUrl = 'https://your-app-domain.com/payment-callback';
```

## Step 3: Install Dependencies

Run the following command to install the required dependencies:

```bash
flutter pub get
```

## Step 4: Test the Integration

1. Run your app in debug mode
2. Navigate to an event registration page
3. Fill in the registration form
4. Click "Register" - this will trigger the ToyyibPay payment flow
5. Complete the payment in the ToyyibPay sandbox

## Step 5: Handle Callbacks (Optional)

If you want to handle payment callbacks on your server:

1. Set up a webhook endpoint on your server
2. Update the `callbackUrl` in the configuration
3. Implement the callback handler to process payment status updates

Example callback handler:

```dart
// In your server-side code
Future<void> handleToyyibPayCallback(Map<String, dynamic> data) async {
  final paymentId = data['paymentId'];
  final status = data['status_id'];
  final signature = data['signature'];
  
  // Verify signature
  if (!ToyyibPayService.verifyPaymentSignature(data, signature)) {
    return; // Invalid signature
  }
  
  // Process payment status
  if (status == '1') {
    // Payment successful
    await PaymentService.completePayment(paymentId, data['order_id']);
  } else if (status == '2') {
    // Payment failed
    await PaymentService.failPayment(paymentId, 'Payment failed');
  }
}
```

## Step 6: Production Deployment

When ready for production:

1. Update the configuration to use production URLs:
   ```dart
   // In toyyibpay_config.dart
   static const String productionUrl = 'https://toyyibpay.com';
   static String get baseUrl => productionUrl; // Change from sandboxUrl
   ```

2. Update your return and callback URLs to production URLs

3. Test thoroughly in production environment

## Features Included

✅ **Sandbox Integration**: Full integration with dev.toyyibpay.com
✅ **Payment Creation**: Create bills for event registrations
✅ **WebView Payment**: In-app payment processing
✅ **Status Checking**: Check payment status via API
✅ **Callback Handling**: Process payment callbacks
✅ **Error Handling**: Comprehensive error handling
✅ **UI Integration**: Beautiful payment page with event summary
✅ **Security**: Signature verification for callbacks

## Payment Flow

1. User registers for an event
2. System creates a ToyyibPay bill
3. User is redirected to ToyyibPay payment page
4. User completes payment
5. System receives callback and updates payment status
6. User receives confirmation

## Troubleshooting

### Common Issues

1. **"Invalid Secret Key" Error**
   - Check your secret key in the configuration
   - Ensure you're using the correct environment (sandbox vs production)

2. **"Category Code Not Found" Error**
   - Verify your category code in ToyyibPay dashboard
   - Ensure the category is active

3. **Payment Not Processing**
   - Check your internet connection
   - Verify the payment amount is valid
   - Ensure all required fields are filled

4. **Callback Not Received**
   - Check your callback URL is accessible
   - Verify the URL format is correct
   - Check server logs for any errors

### Testing Tips

- Use ToyyibPay's test cards for sandbox testing
- Test both successful and failed payment scenarios
- Verify callback handling works correctly
- Test with different amounts and currencies

## Support

For ToyyibPay-specific issues, contact ToyyibPay support:
- Email: support@toyyibpay.com
- Documentation: https://toyyibpay.com/docs

For app integration issues, check the code comments and error messages for guidance.

## Security Notes

- Never commit your actual API credentials to version control
- Use environment variables or secure storage for production credentials
- Always verify payment signatures in callbacks
- Implement proper error handling and logging
- Test thoroughly before going live

## Files Modified/Created

- `lib/services/toyyibpay_service.dart` - Main ToyyibPay integration service
- `lib/config/toyyibpay_config.dart` - Configuration file
- `lib/screens/toyyibpay_payment_page.dart` - Payment UI page
- `lib/services/payment_service.dart` - Updated with ToyyibPay methods
- `lib/screens/event_registration_page.dart` - Updated to use ToyyibPay
- `pubspec.yaml` - Added required dependencies

## Dependencies Added

- `webview_flutter: ^4.4.2` - For in-app payment processing
- `crypto: ^3.0.3` - For signature verification 