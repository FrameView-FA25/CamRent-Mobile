import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uni_links/uni_links.dart';
import 'dart:async';

import '../../services/api_service.dart';
import '../booking/booking_list_screen.dart';

class PaymentScreen extends StatefulWidget {
  final Map<String, dynamic> bookingData;
  final double totalAmount;
  final double depositAmount;

  const PaymentScreen({
    super.key,
    required this.bookingData,
    required this.totalAmount,
    required this.depositAmount,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  StreamSubscription? _linkSubscription;
  bool _isListeningForDeeplinks = false;

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  void _startListeningForDeeplinks() {
    if (_isListeningForDeeplinks) return;
    
    _isListeningForDeeplinks = true;
    debugPrint('PaymentScreen: Starting to listen for deeplinks using uni_links...');
    
    // Listen for deeplinks using uni_links
    _linkSubscription = linkStream.listen(
      (String? link) {
        if (link != null && mounted) {
          debugPrint('PaymentScreen: Received deeplink via uni_links: $link');
          _handlePaymentDeeplink(link);
        }
      },
      onError: (err) {
        debugPrint('PaymentScreen: Error listening to uni_links: $err');
      },
    );
    
    // Also check for initial link
    getInitialLink().then((String? initialLink) {
      if (initialLink != null && mounted) {
        debugPrint('PaymentScreen: Received initial deeplink via uni_links: $initialLink');
        _handlePaymentDeeplink(initialLink);
      }
    }).catchError((err) {
      debugPrint('PaymentScreen: Error getting initial link via uni_links: $err');
    });
  }

  void _handlePaymentDeeplink(String link) {
    try {
      final uri = Uri.parse(link);
      debugPrint('PaymentScreen: Parsed deeplink URI: $uri');
      
      // Check if it's a payment callback
      if (uri.scheme == 'cameraforrent' && uri.host == 'payment') {
        final status = uri.queryParameters['status'] ?? 
                      (uri.path.contains('success') ? 'success' : 
                       uri.path.contains('cancel') ? 'cancel' : null);
        
        if (status == 'success') {
          debugPrint('PaymentScreen: Payment success detected via uni_links');
          _showPaymentSuccessDialog();
        } else if (status == 'cancel') {
          debugPrint('PaymentScreen: Payment cancelled detected via uni_links');
          _showPaymentCancelDialog();
        }
      } else if (uri.scheme == 'https' || uri.scheme == 'http') {
        // Check for HTTP redirect URLs
        if (uri.path.contains('/return') || uri.path.contains('/payment/return')) {
          final status = uri.queryParameters['status'];
          if (status == 'success') {
            debugPrint('PaymentScreen: Payment success detected via HTTP redirect');
            _showPaymentSuccessDialog();
          } else if (status == 'cancel') {
            debugPrint('PaymentScreen: Payment cancelled detected via HTTP redirect');
            _showPaymentCancelDialog();
          }
        }
      }
    } catch (e) {
      debugPrint('PaymentScreen: Error handling deeplink: $e');
    }
  }

  void _showPaymentSuccessDialog() {
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 8),
            Text('Thanh toán thành công'),
          ],
        ),
        content: const Text(
          'Bạn đã thanh toán thành công. Đơn hàng của bạn đang được xử lý.',
        ),
        actions: [
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushNamedAndRemoveUntil(
                '/bookings',
                (route) => false,
              );
            },
            icon: const Icon(Icons.list, size: 18),
            label: const Text('Xem đơn hàng'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _showPaymentCancelDialog() {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Row(
          children: [
            Icon(Icons.cancel, color: Colors.orange, size: 28),
            SizedBox(width: 8),
            Text('Thanh toán đã hủy'),
          ],
        ),
        content: const Text(
          'Bạn đã hủy thanh toán. Bạn có thể thử lại sau.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  String _formatCurrency(double value) {
    if (value <= 0) return '0 VNĐ';
    final raw = value.toStringAsFixed(0);
    final buffer = StringBuffer();
    for (int i = 0; i < raw.length; i++) {
      buffer.write(raw[i]);
      final position = raw.length - i - 1;
      if (position % 3 == 0 && position != 0) {
        buffer.write(',');
      }
    }
    return '${buffer.toString()} VNĐ';
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Chưa có';
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  String? _getBookingId() {
    return _searchForBookingId(widget.bookingData);
  }

  String? _searchForBookingId(dynamic source) {
    if (source is Map<String, dynamic>) {
      final direct = _tryExtractBookingIdFromMap(source);
      if (direct != null && direct.isNotEmpty) {
        return direct;
      }

      for (final key in ['data', 'booking', 'result', 'payload', 'items']) {
        final nested = source[key];
        final found = _searchForBookingId(nested);
        if (found != null && found.isNotEmpty) {
          return found;
        }
      }
    } else if (source is List) {
      for (final item in source) {
        final found = _searchForBookingId(item);
        if (found != null && found.isNotEmpty) {
          return found;
        }
      }
    }
    return null;
  }

  String? _tryExtractBookingIdFromMap(Map<String, dynamic> map) {
    const keyVariations = [
      'bookingId',
      'id',
      '_id',
      'cartId',
      'bookingCartId',
      'bookingIdentifier',
    ];
    for (final key in keyVariations) {
      final value = map[key];
      final asString = value?.toString().trim();
      if (asString != null && asString.isNotEmpty) {
        return asString;
      }
    }
    return null;
  }

  String? _getPaymentId() {
    return widget.bookingData['paymentId']?.toString();
  }

  String? _getCustomerName() {
    return widget.bookingData['customerName']?.toString() ??
        widget.bookingData['customer_name']?.toString();
  }

  String? _getCustomerPhone() {
    return widget.bookingData['customerPhone']?.toString() ??
        widget.bookingData['customer_phone']?.toString();
  }

  String? _getCustomerEmail() {
    return widget.bookingData['customerEmail']?.toString() ??
        widget.bookingData['customer_email']?.toString();
  }

  DateTime? _getCreatedAt() {
    final createdAt = widget.bookingData['createdAt'] ??
        widget.bookingData['created_at'] ??
        widget.bookingData['createdDate'];
    if (createdAt == null) return null;
    if (createdAt is DateTime) return createdAt;
    return DateTime.tryParse(createdAt.toString());
  }

  bool _isProcessing = false;
  String _statusMessage = 'Chưa có giao dịch thanh toán';

  @override
  void initState() {
    super.initState();
    // Auto-open payment URL if available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndOpenPaymentUrl();
    });
  }

  Future<void> _checkAndOpenPaymentUrl() async {
    final paymentUrl = _getPaymentUrl();
    debugPrint('PaymentScreen: Checking for payment URL...');
    debugPrint('PaymentScreen: bookingData keys: ${widget.bookingData.keys.toList()}');
    debugPrint('PaymentScreen: paymentUrl value: $paymentUrl');
    
    if (paymentUrl != null && paymentUrl.isNotEmpty) {
      debugPrint('PaymentScreen: Found payment URL, opening: $paymentUrl');
      await _openPaymentUrl(paymentUrl);
    } else {
      debugPrint('PaymentScreen: No payment URL found in bookingData');
    }
  }

  String? _getPaymentUrl() {
    return widget.bookingData['paymentUrl']?.toString() ??
           widget.bookingData['payment_url']?.toString() ??
           widget.bookingData['url']?.toString() ??
           widget.bookingData['payosUrl']?.toString();
  }

  Future<void> _openPaymentUrl(String url) async {
    try {
      setState(() {
        _isProcessing = true;
        _statusMessage = 'Đang mở trang thanh toán PayOS...';
      });

      // Clean URL: remove surrounding quotes if any
      final cleanedUrl = url.replaceAll('"', '').replaceAll("'", '').trim();
      debugPrint('PaymentScreen: Original URL: $url');
      debugPrint('PaymentScreen: Cleaned URL: $cleanedUrl');
      
      // Validate URL
      if (!cleanedUrl.startsWith('http://') && !cleanedUrl.startsWith('https://')) {
        throw Exception('URL không hợp lệ: $cleanedUrl');
      }
      
      final bookingId = _getBookingId();
      final paymentId = widget.bookingData['paymentId']?.toString();
      
      if (bookingId == null || bookingId.isEmpty) {
        throw Exception('Không tìm thấy mã đặt lịch');
      }
      
      debugPrint('PaymentScreen: Opening external browser with URL: $cleanedUrl');
      debugPrint('PaymentScreen: Booking ID: $bookingId');
      debugPrint('PaymentScreen: Payment ID: $paymentId');
      
      // Start listening for deeplinks using uni_links
      _startListeningForDeeplinks();
      
      // Parse and validate URI
      final uri = Uri.parse(cleanedUrl);
      debugPrint('PaymentScreen: Parsed URI: $uri');
      debugPrint('PaymentScreen: URI scheme: ${uri.scheme}');
      debugPrint('PaymentScreen: URI host: ${uri.host}');
      
      // Try multiple launch modes if externalApplication fails
      bool launched = false;
      
      // First try: externalApplication (opens in default browser)
      try {
        debugPrint('PaymentScreen: Attempting to launch with externalApplication mode...');
        launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        debugPrint('PaymentScreen: externalApplication result: $launched');
      } catch (e) {
        debugPrint('PaymentScreen: externalApplication failed: $e');
      }
      
      // Second try: platformDefault (system decides)
      if (!launched) {
        try {
          debugPrint('PaymentScreen: Attempting to launch with platformDefault mode...');
          launched = await launchUrl(
            uri,
            mode: LaunchMode.platformDefault,
          );
          debugPrint('PaymentScreen: platformDefault result: $launched');
        } catch (e) {
          debugPrint('PaymentScreen: platformDefault failed: $e');
        }
      }
      
      // Third try: inAppWebView (opens in WebView)
      if (!launched) {
        try {
          debugPrint('PaymentScreen: Attempting to launch with inAppWebView mode...');
          launched = await launchUrl(
            uri,
            mode: LaunchMode.inAppWebView,
          );
          debugPrint('PaymentScreen: inAppWebView result: $launched');
        } catch (e) {
          debugPrint('PaymentScreen: inAppWebView failed: $e');
        }
      }
      
      // Fourth try: inAppBrowserView (opens in browser view)
      if (!launched) {
        try {
          debugPrint('PaymentScreen: Attempting to launch with inAppBrowserView mode...');
          launched = await launchUrl(
            uri,
            mode: LaunchMode.inAppBrowserView,
          );
          debugPrint('PaymentScreen: inAppBrowserView result: $launched');
        } catch (e) {
          debugPrint('PaymentScreen: inAppBrowserView failed: $e');
        }
      }
      
      if (launched) {
        setState(() {
          _isProcessing = false;
          _statusMessage = 'Đã mở trang thanh toán PayOS. Vui lòng hoàn tất thanh toán trên trình duyệt.';
        });
      } else {
        // If all methods fail, show URL in a dialog for manual copy
        debugPrint('PaymentScreen: All launch methods failed, showing URL dialog');
        _showUrlCopyDialog(cleanedUrl);
      }
    } catch (e, stackTrace) {
      debugPrint('PaymentScreen: Exception in _openPaymentUrl: $e');
      debugPrint('PaymentScreen: StackTrace: $stackTrace');
      setState(() {
        _statusMessage = 'Lỗi khi mở trang thanh toán: ${e.toString()}';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _showUrlCopyDialog(String url) {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Row(
          children: [
            Icon(Icons.link, color: Colors.blue, size: 28),
            SizedBox(width: 8),
            Expanded(child: Text('Không thể mở trình duyệt tự động')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Vui lòng sao chép liên kết sau và mở trong trình duyệt:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: SelectableText(
                url,
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Đóng'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: url));
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Đã sao chép liên kết vào clipboard'),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 2),
                ),
              );
            },
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('Sao chép'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startPayOsFlow() async {
    // First, check if we already have a payment URL
    final existingUrl = _getPaymentUrl();
    if (existingUrl != null && existingUrl.isNotEmpty) {
      debugPrint('PaymentScreen: Using existing payment URL');
      await _openPaymentUrl(existingUrl);
      return;
    }

    // Get booking ID
    final bookingId = _getBookingId();
    if (bookingId == null || bookingId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không tìm thấy mã đặt lịch để tạo thanh toán.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Đang lấy liên kết thanh toán...';
    });

    try {
      debugPrint('PaymentScreen: Getting payment URL for bookingId: $bookingId');
      
      // Get payment URL directly from booking ID (simplified flow)
      final amount = widget.depositAmount > 0 ? widget.depositAmount : widget.totalAmount;
      final paymentUrl = await ApiService.getPaymentUrlFromBookingId(
        bookingId: bookingId,
        mode: 'Deposit',
        amount: amount,
        description: 'Thanh toán đặt cọc cho đơn hàng $bookingId',
      );

      debugPrint('PaymentScreen: Payment URL received: ${paymentUrl.isNotEmpty ? "yes" : "no"}');
      if (paymentUrl.isNotEmpty) {
        debugPrint('PaymentScreen: Payment URL: $paymentUrl');
      } else {
        debugPrint('PaymentScreen: ERROR - Payment URL is empty!');
        throw Exception('Không nhận được URL thanh toán từ server');
      }

      // Save URL to bookingData for future use
      widget.bookingData['paymentUrl'] = paymentUrl;
      
      // Open the payment URL
      await _openPaymentUrl(paymentUrl);
    } catch (e) {
      debugPrint('PaymentScreen: Error in _startPayOsFlow: $e');
      setState(() {
        _statusMessage =
            'Quý khách hiện chưa thực hiện thanh toán (${e.toString().replaceFirst('Exception: ', '')})';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Không thể lấy liên kết thanh toán: ${e.toString().replaceFirst('Exception: ', '')}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _createAndOpenPayOSUrl(String paymentId) async {
    try {
      setState(() {
        _isProcessing = true;
        _statusMessage = 'Đang tạo liên kết thanh toán PayOS...';
      });

      final amount =
          widget.depositAmount > 0 ? widget.depositAmount : widget.totalAmount;
      
      debugPrint('PaymentScreen: Initializing PayOS payment with paymentId: $paymentId, amount: $amount');
      try {
        final bookingId = _getBookingId() ?? '';
        final payOsUrl = await ApiService.initializePayOSPayment(
          paymentId: paymentId,
          amount: amount,
          description: 'Thanh toán đặt cọc cho đơn hàng $bookingId',
          returnUrl: 'https://camrent-backend.up.railway.app/api/Payments/return?bookingId=$bookingId&paymentId=$paymentId&status=success',
          cancelUrl: 'https://camrent-backend.up.railway.app/api/Payments/return?bookingId=$bookingId&paymentId=$paymentId&status=cancel',
        );

        debugPrint('PaymentScreen: PayOS URL received: ${payOsUrl.isNotEmpty ? "yes" : "no"}');
        if (payOsUrl.isEmpty) {
          throw Exception('Không nhận được URL PayOS');
        }

        // Save URL to bookingData for future use
        widget.bookingData['paymentUrl'] = payOsUrl;
        
        // Open the URL
        await _openPaymentUrl(payOsUrl);
      } catch (e) {
        final errorMsg = e.toString();
        // Check if payment already exists
        if (errorMsg.contains('Đơn thanh toán đã tồn tại') || 
            errorMsg.contains('đã tồn tại')) {
          debugPrint('PaymentScreen: Payment already exists, attempting to get existing URL...');
          
          // Try to get existing payment URL from booking info or retry initialize
          try {
            final paymentId = _getPaymentId();
            final bookingId = _getBookingId();
            
            if (paymentId != null && paymentId.isNotEmpty) {
              debugPrint('PaymentScreen: Payment already exists, attempting to retrieve URL...');
              
              // Strategy 1: Try to get payment info from booking
              if (bookingId != null && bookingId.isNotEmpty) {
                try {
                  debugPrint('PaymentScreen: Trying to get payment info from booking: $bookingId');
                  final bookingInfo = await ApiService.getBookingById(bookingId);
                  
                  // Check for payment info in booking
                  final paymentInfo = bookingInfo['payment'] ?? 
                                    bookingInfo['paymentInfo'] ??
                                    bookingInfo['payments'];
                  
                  if (paymentInfo is Map) {
                    final existingUrl = paymentInfo['url']?.toString() ?? 
                                       paymentInfo['paymentUrl']?.toString() ?? 
                                       paymentInfo['payosUrl']?.toString() ??
                                       paymentInfo['checkoutUrl']?.toString() ??
                                       paymentInfo['payosCheckoutUrl']?.toString() ??
                                       paymentInfo['link']?.toString() ??
                                       paymentInfo['paymentLink']?.toString();
                    
                    if (existingUrl != null && existingUrl.isNotEmpty) {
                      final cleanedUrl = existingUrl.replaceAll('"', '').replaceAll("'", '').trim();
                      debugPrint('PaymentScreen: Found payment URL from booking: $cleanedUrl');
                      widget.bookingData['paymentUrl'] = cleanedUrl;
                      await _openPaymentUrl(cleanedUrl);
                      return;
                    }
                  }
                  
                  // Also check direct fields in booking
                  final directUrl = bookingInfo['paymentUrl']?.toString() ?? 
                                   bookingInfo['payosUrl']?.toString() ??
                                   bookingInfo['checkoutUrl']?.toString();
                  
                  if (directUrl != null && directUrl.isNotEmpty) {
                    final cleanedUrl = directUrl.replaceAll('"', '').replaceAll("'", '').trim();
                    debugPrint('PaymentScreen: Found payment URL in booking: $cleanedUrl');
                    widget.bookingData['paymentUrl'] = cleanedUrl;
                    await _openPaymentUrl(cleanedUrl);
                    return;
                  }
                } catch (bookingError) {
                  debugPrint('PaymentScreen: Error getting payment from booking: $bookingError');
                }
              }
              
              // Strategy 2: Retry initialize PayOS with a small delay (backend might return URL if payment exists)
              debugPrint('PaymentScreen: Retrying PayOS initialization after delay...');
              await Future.delayed(const Duration(seconds: 1));
              
              try {
                final amount = widget.depositAmount > 0 ? widget.depositAmount : widget.totalAmount;
                final retryUrl = await ApiService.initializePayOSPayment(
                  paymentId: paymentId,
                  amount: amount,
                  description: 'Thanh toán đặt cọc cho đơn hàng ${bookingId ?? ""}',
                  returnUrl: 'https://camrent-backend.up.railway.app/api/Payments/return?bookingId=${bookingId ?? ""}&paymentId=$paymentId&status=success',
                  cancelUrl: 'https://camrent-backend.up.railway.app/api/Payments/return?bookingId=${bookingId ?? ""}&paymentId=$paymentId&status=cancel',
                );
                
                if (retryUrl.isNotEmpty) {
                  debugPrint('PaymentScreen: Successfully retrieved URL on retry: $retryUrl');
                  widget.bookingData['paymentUrl'] = retryUrl;
                  await _openPaymentUrl(retryUrl);
                  return;
                }
              } catch (retryError) {
                debugPrint('PaymentScreen: Retry also failed: $retryError');
              }
            }
          } catch (getUrlError) {
            debugPrint('PaymentScreen: Error getting existing payment URL: $getUrlError');
          }
          
          // If we can't get URL, show message to user
          debugPrint('PaymentScreen: Payment already exists, showing message to user');
          setState(() {
            _statusMessage = 'Đơn thanh toán đã được tạo trước đó. Vui lòng kiểm tra email hoặc liên hệ hỗ trợ để lấy liên kết thanh toán.';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đơn thanh toán đã tồn tại. Vui lòng kiểm tra email hoặc liên hệ hỗ trợ để lấy liên kết thanh toán.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 8),
            ),
          );
        } else {
          rethrow;
        }
      }
    } catch (e) {
      debugPrint('PaymentScreen: Error creating PayOS URL: $e');
      setState(() {
        _statusMessage =
            'Không thể tạo liên kết thanh toán: ${e.toString().replaceFirst('Exception: ', '')}';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Không thể tạo liên kết thanh toán: ${e.toString().replaceFirst('Exception: ', '')}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bookingId = _getBookingId();
    final customerName = _getCustomerName();
    final customerPhone = _getCustomerPhone();
    final customerEmail = _getCustomerEmail();
    final createdAt = _getCreatedAt();

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primary.withOpacity(0.05),
              Colors.white,
            ],
            stops: const [0.0, 0.3],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // App Bar
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () {
                        // Pop về màn hình chính
                        Navigator.popUntil(context, (route) => route.isFirst);
                      },
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Đặt lịch thành công',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Đơn hàng của bạn đã được xác nhận',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Nội dung
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Icon thành công
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_circle,
                          size: 80,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Đặt lịch thành công!',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Cảm ơn bạn đã sử dụng dịch vụ của chúng tôi',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      // Thông tin đơn hàng
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.receipt_long,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Thông tin đơn hàng',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            if (bookingId != null) ...[
                              _buildInfoRow(
                                'Mã đơn hàng',
                                bookingId,
                                Icons.tag,
                              ),
                              const Divider(),
                            ],
                            if (customerName != null) ...[
                              _buildInfoRow(
                                'Họ và tên',
                                customerName,
                                Icons.person,
                              ),
                              const Divider(),
                            ],
                            if (customerPhone != null) ...[
                              _buildInfoRow(
                                'Số điện thoại',
                                customerPhone,
                                Icons.phone,
                              ),
                              const Divider(),
                            ],
                            if (customerEmail != null) ...[
                              _buildInfoRow(
                                'Email',
                                customerEmail,
                                Icons.email,
                              ),
                              const Divider(),
                            ],
                            if (createdAt != null) ...[
                              _buildInfoRow(
                                'Ngày đặt',
                                _formatDate(createdAt),
                                Icons.calendar_today,
                              ),
                              const Divider(),
                            ],
                            if (_getPaymentId() != null) ...[
                              _buildInfoRow(
                                'Mã thanh toán',
                                _getPaymentId()!,
                                Icons.payment,
                              ),
                              const Divider(),
                            ],
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Tổng tiền',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  _formatCurrency(widget.totalAmount),
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                            if (widget.depositAmount > 0) ...[
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Đặt cọc',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                  Text(
                                    _formatCurrency(widget.depositAmount),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _isProcessing ? null : _startPayOsFlow,
                        icon: const Icon(Icons.payment),
                        label: Text(
                          _isProcessing
                              ? 'Đang chuẩn bị thanh toán...'
                              : 'Thanh toán qua PayOS',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _statusMessage,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      // Thông báo
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.blue.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.blue[700],
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Lưu ý',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue[900],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Đơn hàng của bạn đang được xử lý. Chúng tôi sẽ liên hệ với bạn trong thời gian sớm nhất để xác nhận đơn hàng.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.blue[800],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Nút hành động
              SafeArea(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            // Pop về màn hình chính
                            Navigator.popUntil(context, (route) => route.isFirst);
                          },
                          icon: const Icon(Icons.home),
                          label: const Text('Về trang chủ'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            // Pop về màn hình chính và điều hướng đến booking list
                            Navigator.popUntil(context, (route) => route.isFirst);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const BookingListScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.history),
                          label: const Text('Xem đơn hàng'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Theme.of(context).colorScheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: Colors.grey[600],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

