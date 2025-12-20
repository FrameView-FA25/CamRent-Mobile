import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../booking/booking_list_screen.dart';

class PaymentWebViewScreen extends StatefulWidget {
  final String paymentUrl;
  final String? bookingId;
  final String? paymentId;
  final String? title;

  const PaymentWebViewScreen({
    super.key,
    required this.paymentUrl,
    this.bookingId,
    this.paymentId,
    this.title,
  });

  @override
  State<PaymentWebViewScreen> createState() => _PaymentWebViewScreenState();
}

class _PaymentWebViewScreenState extends State<PaymentWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String _statusMessage = 'Đang tải trang thanh toán...';

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    final cleanedUrl = widget.paymentUrl.replaceAll('"', '').replaceAll("'", '').trim();
    debugPrint('PaymentWebViewScreen: Initializing WebView with URL: $cleanedUrl');

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            debugPrint('PaymentWebViewScreen: Page started loading: $url');
            setState(() {
              _isLoading = true;
              _statusMessage = 'Đang tải trang thanh toán...';
            });
          },
          onPageFinished: (String url) {
            debugPrint('PaymentWebViewScreen: Page finished loading: $url');
            setState(() {
              _isLoading = false;
            });
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('PaymentWebViewScreen: Web resource error: ${error.description}');
            setState(() {
              _statusMessage = 'Lỗi tải trang: ${error.description}';
            });
          },
          onNavigationRequest: (NavigationRequest request) {
            final url = request.url;
            debugPrint('PaymentWebViewScreen: Navigation request to: $url');

            // Check if this is a return URL (success or cancel)
            // PayOS will redirect to returnUrl after successful payment
            final uri = Uri.parse(url);
            final path = uri.path.toLowerCase();
            final queryParams = uri.queryParameters;
            
            // Check for success indicators
            bool isSuccess = false;
            bool isCancel = false;
            
            // Check URL path and query parameters
            if (path.contains('/payments/success') || 
                path.contains('payment/success') ||
                path.contains('success') ||
                queryParams.containsKey('status') && queryParams['status']?.toLowerCase() == 'success' ||
                queryParams.containsKey('code') && queryParams['code'] == '00' ||
                url.contains('success=true') ||
                url.contains('status=success')) {
              isSuccess = true;
            }
            
            // Check for cancel indicators
            if (path.contains('/payments/cancel') || 
                path.contains('payment/cancel') ||
                path.contains('cancel') ||
                queryParams.containsKey('status') && queryParams['status']?.toLowerCase() == 'cancel' ||
                queryParams.containsKey('code') && (queryParams['code'] == '01' || queryParams['code'] == 'cancel') ||
                url.contains('cancel=true') ||
                url.contains('status=cancel')) {
              isCancel = true;
            }
            
            if (isSuccess) {
              debugPrint('PaymentWebViewScreen: Payment success detected from URL: $url');
              _handlePaymentSuccess(url);
              return NavigationDecision.prevent; // Prevent navigation, we'll handle it
            }

            if (isCancel) {
              debugPrint('PaymentWebViewScreen: Payment cancelled detected from URL: $url');
              _handlePaymentCancel(url);
              return NavigationDecision.prevent; // Prevent navigation, we'll handle it
            }

            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(cleanedUrl));
  }

  void _handlePaymentSuccess(String url) async {
    debugPrint('PaymentWebViewScreen: Handling payment success for URL: $url');
    
    // Stop loading indicator
    setState(() {
      _isLoading = false;
      _statusMessage = 'Thanh toán thành công!';
    });
    
    // Wait a moment for user to see the success page
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Show success message
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
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
                Navigator.of(context).pop(); // Close dialog
                // Navigate to booking list and remove all previous routes
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (context) => const BookingListScreen(),
                  ),
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
  }

  void _handlePaymentCancel(String url) {
    debugPrint('PaymentWebViewScreen: Handling payment cancel for URL: $url');
    
    // Show cancel message
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
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
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(); // Go back to payment screen
              },
              child: const Text('Đóng'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thanh toán PayOS'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // Show confirmation dialog before going back
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Hủy thanh toán?'),
                content: const Text(
                  'Bạn có chắc chắn muốn hủy thanh toán? Bạn có thể thử lại sau.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Tiếp tục thanh toán'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop(); // Close dialog
                      Navigator.of(context).pop(); // Go back
                    },
                    child: const Text('Hủy'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            Container(
              color: Colors.white,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      _statusMessage,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

