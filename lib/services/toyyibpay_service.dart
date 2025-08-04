import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter/material.dart';
import 'package:hikefue5/config/toyyibpay_config.dart';

class ToyyibPayService {
  // Use configuration for credentials and settings
  static String get _baseUrl => ToyyibPayConfig.baseUrl;
  static String get _secretKey => ToyyibPayConfig.secretKey;
  static String get _categoryCode => ToyyibPayConfig.categoryCode;

  // Create a bill for payment
  static Future<Map<String, dynamic>> createBill({
    required String billName,
    required String billDescription,
    required double amount,
    required String customerName,
    required String customerEmail,
    required String customerPhone,
    String? returnUrl,
    String? callbackUrl,
  }) async {
    try {
      final orderId = _generateOrderId();
      
      // Limit bill name to 30 characters as required by ToyyibPay
      final limitedBillName = billName.length > 30 ? billName.substring(0, 30) : billName;
      
      // Minimal required fields for ToyyibPay
      final billData = {
        'userSecretKey': _secretKey,
        'categoryCode': _categoryCode,
        'billName': limitedBillName,
        'billDescription': billDescription,
        'billPriceSetting': '1',
        'billPayorInfo': '1',
        'billAmount': (amount * 100).round().toString(), // Convert to cents
        'billReturnUrl': returnUrl ?? ToyyibPayConfig.returnUrl,
        'billCallbackUrl': callbackUrl ?? ToyyibPayConfig.callbackUrl,
        'billExternalReferenceNo': orderId,
        'billTo': customerName,
        'billEmail': customerEmail,
        'billPhone': customerPhone,
        'billSplitPayment': '0',
        'billPaymentChannel': '0',
        'billDisplayMerchant': '1',
        'billChargeToCustomer': '0',
        'billExpiryDays': '3',
        'billIsFixedAmount': '1',
        'billIsFixedQuantity': '1',
        'billQuantity': '1',
        'billMultiPayment': '0',
        'billPaymentMode': 'fullpayment',
        'billWithMyKad': '0',
        'billLanguage': 'EN',
      };

      // Debug: Print the request data
      print('ToyyibPay Request URL: $_baseUrl/index.php/api/createBill');
      print('ToyyibPay Request Data: $billData');
      
      // Convert Map to form-encoded string
      final formData = billData.entries
          .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value.toString())}')
          .join('&');

      final response = await http.post(
        Uri.parse('$_baseUrl/index.php/api/createBill'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: formData,
      );

      // Debug: Print the response
      print('ToyyibPay Response Status: ${response.statusCode}');
      print('ToyyibPay Response Body: ${response.body}');

      if (response.statusCode == 200) {
        // Handle different response formats
        final responseBody = response.body.trim();
        
        if (responseBody == '[FALSE]') {
          return {
            'success': false,
            'message': 'Failed to create bill - Invalid parameters or credentials',
          };
        }
        
        try {
          final responseData = json.decode(responseBody);
          print('ToyyibPay Parsed Response: $responseData');
          
          // Handle array response format
          if (responseData is List && responseData.isNotEmpty) {
            final billInfo = responseData.first;
            if (billInfo['BillCode'] != null) {
              return {
                'success': true,
                'billCode': billInfo['BillCode'],
                'orderId': orderId,
                'paymentUrl': '$_baseUrl/${billInfo['BillCode']}',
                'message': 'Bill created successfully',
              };
            }
          }
          
          // Handle object response format
          if (responseData['Status'] == 'Success') {
            return {
              'success': true,
              'billCode': responseData['BillCode'],
              'orderId': orderId,
              'paymentUrl': '$_baseUrl/${responseData['BillCode']}',
              'message': 'Bill created successfully',
            };
          } else {
            return {
              'success': false,
              'message': responseData['Message'] ?? 'Failed to create bill',
            };
          }
        } catch (e) {
          return {
            'success': false,
            'message': 'Invalid response format: $responseBody',
          };
        }
      } else {
        return {
          'success': false,
          'message': 'HTTP Error: ${response.statusCode} - ${response.body}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error creating bill: $e',
      };
    }
  }

  // Get bill status
  static Future<Map<String, dynamic>> getBillStatus(String billCode) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/index.php/api/getBillTransactions'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'userSecretKey': _secretKey,
          'billCode': billCode,
        },
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        
        if (responseData['Status'] == 'Success') {
          final transactions = responseData['Data'] as List;
          if (transactions.isNotEmpty) {
            final transaction = transactions.first;
            return {
              'success': true,
              'status': transaction['billpaymentStatus'],
              'amount': transaction['billpaymentAmount'],
              'orderId': transaction['billpaymentInvoiceNo'],
              'paymentDate': transaction['billpaymentDate'],
              'message': 'Payment status retrieved successfully',
            };
          } else {
            return {
              'success': true,
              'status': 'pending',
              'message': 'No payment found for this bill',
            };
          }
        } else {
          return {
            'success': false,
            'message': responseData['Message'] ?? 'Failed to get bill status',
          };
        }
      } else {
        return {
          'success': false,
          'message': 'HTTP Error: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error getting bill status: $e',
      };
    }
  }

  // Launch payment in WebView
  static Future<String?> launchPayment(BuildContext context, String paymentUrl) async {
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            print('Payment WebView navigation: ${request.url}');
            
            // Handle ToyyibPay success/failure URLs
            if (request.url.contains('payment-success') || 
                request.url.contains('status=1') ||
                request.url.contains('success')) {
              Navigator.of(context).pop('success');
              return NavigationDecision.prevent;
            }
            if (request.url.contains('payment-cancel') || 
                request.url.contains('payment-fail') ||
                request.url.contains('status=2') ||
                request.url.contains('cancel') ||
                request.url.contains('fail')) {
              Navigator.of(context).pop('cancelled');
              return NavigationDecision.prevent;
            }
            
            return NavigationDecision.navigate;
          },
          onPageFinished: (String url) {
            print('Payment page finished loading: $url');
            
            // Check if we've reached a success/failure page by URL
            if (url.contains('status=1')) {
              Navigator.of(context).pop('success');
            } else if (url.contains('status=2')) {
              Navigator.of(context).pop('cancelled');
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(paymentUrl));

    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text('Complete Payment'),
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop('cancelled'),
            ),
          ),
          body: WebViewWidget(controller: controller),
        ),
      ),
    );
    
    return result;
  }

  // Launch payment in external browser
  static Future<void> launchPaymentExternal(String paymentUrl) async {
    final uri = Uri.parse(paymentUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      throw Exception('Could not launch payment URL');
    }
  }



  // Generate unique order ID
  static String _generateOrderId() {
    final now = DateTime.now();
    final random = Random();
    return 'ORDER_${now.millisecondsSinceEpoch}_${random.nextInt(9999).toString().padLeft(4, '0')}';
  }

  // Verify payment signature (for callback verification)
  static bool verifyPaymentSignature(Map<String, dynamic> data, String signature) {
    try {
      final secretKey = _secretKey;
      final orderId = data['order_id'] ?? '';
      final status = data['status_id'] ?? '';
      final amount = data['amount'] ?? '';
      
      final stringToSign = '$secretKey$orderId$status$amount';
      final expectedSignature = md5.convert(utf8.encode(stringToSign)).toString();
      
      return signature.toLowerCase() == expectedSignature.toLowerCase();
    } catch (e) {
      return false;
    }
  }
} 