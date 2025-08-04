class ToyyibPayConfig {
  // Sandbox Environment
  static const String sandboxUrl = 'https://dev.toyyibpay.com';
  
  // Production Environment (uncomment when ready for production)
  // static const String productionUrl = 'https://toyyibpay.com';
  
  // Your ToyyibPay credentials
  static const String secretKey = '7qjovzxb-iq9z-0669-5fyz-js35ivv5n5xw';
  static const String categoryCode = '5m171lt2';
  
  // Payment settings
  static const int billExpiryDays = 3;
  static const String billLanguage = 'EN'; // EN, BM, CN
  static const String currency = 'MYR';
  
  // Return URLs (update these with your actual URLs)
  static const String returnUrl = 'https://example.com/success';
  static const String callbackUrl = 'https://example.com/callback';
  
  // Payment channels (0 = all channels, 1 = credit card only, etc.)
  static const String paymentChannel = '0';
  
  // Bill settings
  static const int billPriceSetting = 1; // 0 = customer can set price, 1 = fixed price
  static const int billPayorInfo = 1; // 0 = no customer info, 1 = collect customer info
  static const int billSplitPayment = 0; // 0 = no split payment, 1 = split payment
  static const int billDisplayMerchant = 1; // 0 = hide merchant, 1 = show merchant
  static const int billChargeToCustomer = 0; // 0 = no charge, 1 = charge customer
  static const int billIsFixedAmount = 1; // 0 = variable amount, 1 = fixed amount
  static const int billIsFixedQuantity = 1; // 0 = variable quantity, 1 = fixed quantity
  static const int billQuantity = 1;
  static const int billMultiPayment = 0; // 0 = single payment, 1 = multiple payments
  static const String billPaymentMode = 'fullpayment'; // fullpayment, partialpayment
  static const int billWithMyKad = 0; // 0 = no MyKad, 1 = with MyKad
  
  // Content settings
  static const String billContentEmail = 'Thank you for your payment!';
  static const String billContentSMS = 'Thank you for your payment!';
  
  // Get the current environment URL
  static String get baseUrl => sandboxUrl;
  
  // Check if we're in sandbox mode
  static bool get isSandbox => baseUrl == sandboxUrl;
  
  // Get environment name for display
  static String get environmentName => isSandbox ? 'Sandbox' : 'Production';
} 