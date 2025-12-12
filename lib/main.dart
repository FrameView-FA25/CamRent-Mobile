import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:app_links/app_links.dart';
import 'screens/login/login_screen.dart';
import 'screens/booking/booking_list_screen.dart';
import 'screens/payment/payment_success_screen.dart';
import 'screens/payment/payment_failure_screen.dart';
import 'services/api_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _appLinks = AppLinks();

  @override
  void initState() {
    super.initState();
    _initAppLinks();
  }

  Future<void> _initAppLinks() async {
    // Get initial link if app was opened from a link
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        debugPrint('MyApp: Initial deep link: $initialUri');
        _handleDeepLink(initialUri);
      }
    } catch (e) {
      debugPrint('Error getting initial link: $e');
    }

    // Listen for incoming links when app is running
    _appLinks.uriLinkStream.listen(
      (Uri uri) {
        debugPrint('MyApp: Received deep link while app running: $uri');
        _handleDeepLink(uri);
      },
      onError: (err) {
        debugPrint('Error listening to app links: $err');
      },
    );
  }

  Future<void> _handleDeepLink(Uri uri) async {
    debugPrint('MyApp: Handling deep link: $uri');
    debugPrint('MyApp: Scheme: ${uri.scheme}, Host: ${uri.host}, Path: ${uri.path}');
    debugPrint('MyApp: Query params: ${uri.queryParameters}');
    debugPrint('MyApp: Full URI string: ${uri.toString()}');
    
    final path = uri.path.toLowerCase();
    final queryParams = uri.queryParameters;
    final bookingId = queryParams['bookingId'] ?? queryParams['bookingid'] ?? queryParams['id'];
    final paymentId = queryParams['paymentId'] ?? queryParams['paymentid'] ?? queryParams['payment_id'];
    final status = (queryParams['status'] ?? queryParams['Status'] ?? '').toLowerCase();
    final code = queryParams['code'] ?? queryParams['Code'] ?? '';
    final desc = (queryParams['desc'] ?? queryParams['Desc'] ?? '').toLowerCase();
    final uriString = uri.toString().toLowerCase();
    
    // Check for payment success/cancel in various formats
    bool isSuccess = false;
    bool isCancel = false;
    
    // Check deeplink format: cameraforrent://payment/success
    if (uri.scheme == 'cameraforrent' && uri.host == 'payment') {
      if (path.contains('/success') || status == 'success' || code == '00') {
        isSuccess = true;
      } else if (path.contains('/cancel') || status == 'cancel' || status == 'cancelled') {
        isCancel = true;
      }
    }
    // Check HTTP redirect format: https://.../return?status=success
    else if (uri.scheme == 'https' || uri.scheme == 'http') {
      // Backend return URL: https://camrent-backend.up.railway.app/api/Payments/return
      if (path.contains('/return') || path.contains('/payment/return') || path.contains('/payments/return')) {
        if (status == 'success' || status == 'completed' || code == '00' || 
            queryParams.containsKey('success') || desc.contains('success') ||
            uriString.contains('status=success')) {
          isSuccess = true;
        } else if (status == 'cancel' || status == 'cancelled' || status == 'failed' || 
                   queryParams.containsKey('cancel') || desc.contains('cancel') ||
                   uriString.contains('status=cancel')) {
          isCancel = true;
        }
        // If no explicit status but has bookingId/paymentId, assume success (backend redirect)
        else if (bookingId != null || paymentId != null) {
          debugPrint('MyApp: Backend return URL detected with bookingId/paymentId, assuming success');
          isSuccess = true;
        }
      } 
      // PayOS return URL: https://pay.payos.vn/web/...
      else if (uri.host.contains('payos.vn') || uri.host.contains('pay.payos')) {
        if (status == 'success' || code == '00' || desc.contains('success') ||
            uriString.contains('success') || uriString.contains('thanh+cong')) {
          isSuccess = true;
        } else if (status == 'cancel' || status == 'cancelled' || status == 'failed' || 
                   desc.contains('cancel') || desc.contains('fail') ||
                   uriString.contains('cancel') || uriString.contains('that+bai')) {
          isCancel = true;
        }
        // PayOS often returns code=00 for success
        else if (code == '00' || code == '0') {
          isSuccess = true;
        }
      }
      // Generic payment success/cancel paths
      else if (path.contains('/payment/success') || path.contains('/success') || 
               uriString.contains('success') || uriString.contains('thanh+cong')) {
        isSuccess = true;
      } else if (path.contains('/payment/cancel') || path.contains('/cancel') || 
                 uriString.contains('cancel') || uriString.contains('that+bai')) {
        isCancel = true;
      }
    }
    
    debugPrint('MyApp: isSuccess: $isSuccess, isCancel: $isCancel');
    debugPrint('MyApp: bookingId: $bookingId, paymentId: $paymentId');
    
    if (isSuccess) {
      debugPrint('MyApp: Payment success detected from redirect');
      debugPrint('MyApp: Booking ID: $bookingId, Payment ID: $paymentId');
      
      // Verify payment status from backend before navigating
      if (paymentId != null && paymentId.isNotEmpty) {
        debugPrint('MyApp: Verifying payment status with backend API...');
        await _verifyPaymentStatus(bookingId, paymentId);
      } else {
        // If no paymentId, just navigate to success screen
        _handlePaymentSuccess(bookingId, paymentId);
      }
    } else if (isCancel) {
      debugPrint('MyApp: Payment cancelled detected from redirect');
      
      // Handle payment cancel - can still verify but likely cancelled
      if (paymentId != null && paymentId.isNotEmpty) {
        await _verifyPaymentStatus(bookingId, paymentId);
      } else {
        _handlePaymentCancel(bookingId, paymentId);
      }
    } else {
      debugPrint('MyApp: Deep link not recognized as payment callback');
      // If we have bookingId or paymentId, try to verify payment status
      if (bookingId != null || paymentId != null) {
        debugPrint('MyApp: Attempting to verify payment status from backend...');
        await _verifyPaymentStatus(bookingId, paymentId);
      }
    }
  }

  Future<void> _verifyPaymentStatus(String? bookingId, String? paymentId) async {
    // Check payment status from backend API using paymentId
    try {
      debugPrint('MyApp: Verifying payment status for bookingId: $bookingId, paymentId: $paymentId');
      
      // Priority: Use paymentId if available, otherwise bookingId
      if (paymentId == null || paymentId.isEmpty) {
        if (bookingId == null || bookingId.isEmpty) {
          debugPrint('MyApp: No paymentId or bookingId provided, cannot verify payment status');
          return;
        }
        // If no paymentId, we can't call getPaymentStatus
        debugPrint('MyApp: No paymentId available, assuming success based on callback URL');
        _handlePaymentSuccess(bookingId, paymentId);
        return;
      }
      
      // Call API to get payment status
      try {
        final statusData = await ApiService.getPaymentStatus(paymentId: paymentId);
        debugPrint('MyApp: Payment status retrieved: $statusData');
        
        final isPaid = statusData['isPaid'] == true;
        final paymentStatus = statusData['paymentStatus']?.toString().toLowerCase() ?? '';
        final actualBookingId = statusData['bookingId']?.toString() ?? bookingId;
        
        debugPrint('MyApp: Payment isPaid: $isPaid, paymentStatus: $paymentStatus');
        
        // Determine success or failure based on payment status
        if (isPaid || 
            paymentStatus == 'paid' || 
            paymentStatus == 'completed' || 
            paymentStatus == 'success') {
          debugPrint('MyApp: Payment confirmed as successful');
          _handlePaymentSuccess(actualBookingId, paymentId);
        } else if (paymentStatus == 'cancelled' || 
                   paymentStatus == 'failed' || 
                   paymentStatus == 'cancel') {
          debugPrint('MyApp: Payment confirmed as cancelled/failed');
          _handlePaymentCancel(actualBookingId, paymentId);
        } else {
          // If status is pending or unknown, treat as pending and show success screen
          // (Backend webhook may still be processing)
          debugPrint('MyApp: Payment status is pending/unknown, assuming success');
          _handlePaymentSuccess(actualBookingId, paymentId);
        }
      } catch (e) {
        debugPrint('MyApp: Error calling getPaymentStatus API: $e');
        // If API call fails, assume success if we have paymentId from callback
        // (Backend callback means payment was processed)
        debugPrint('MyApp: Falling back to assume success based on callback URL');
        _handlePaymentSuccess(bookingId, paymentId);
      }
    } catch (e) {
      debugPrint('MyApp: Error verifying payment status: $e');
      // Fallback: assume success if we have paymentId/bookingId
      if (bookingId != null || paymentId != null) {
        _handlePaymentSuccess(bookingId, paymentId);
      }
    }
  }

  Future<void> _handlePaymentSuccess(String? bookingId, String? paymentId) async {
    debugPrint('MyApp: Handling payment success - Booking: $bookingId, Payment: $paymentId');
    
    // Backend should automatically update payment and booking status via PayOS webhook
    // Navigate to payment success screen
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final context = navigatorKey.currentContext;
      if (context != null) {
        // Navigate to payment success screen
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/payment-success',
          (route) => false,
          arguments: {
            'bookingId': bookingId,
            'paymentId': paymentId,
          },
        );
      }
    });
  }

  Future<void> _handlePaymentCancel(String? bookingId, String? paymentId) async {
    debugPrint('MyApp: Handling payment cancel - Booking: $bookingId, Payment: $paymentId');
    
    // Navigate to payment failure screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = navigatorKey.currentContext;
      if (context != null) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/payment-failure',
          (route) => false,
          arguments: {
            'bookingId': bookingId,
            'paymentId': paymentId,
            'errorMessage': 'Bạn đã hủy thanh toán hoặc thanh toán thất bại.',
          },
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cho Thuê Máy Ảnh',
      navigatorKey: navigatorKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF6B35), // Màu cam sáng, năng động
          brightness: Brightness.light,
          primary: const Color(0xFFFF6B35), // Cam chính
          secondary: const Color(0xFFFFB627), // Vàng cam
          tertiary: const Color(0xFF4ECDC4), // Cyan sáng
          error: const Color(0xFFFF4757),
          surface: Colors.white,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onTertiary: Colors.white,
        ),
        useMaterial3: true,
        // Set Source Sans Pro as default font for the entire app
        textTheme: GoogleFonts.sourceSans3TextTheme(),
        primaryTextTheme: GoogleFonts.sourceSans3TextTheme(),
      ),
      home: const LoginScreen(),
      debugShowCheckedModeBanner: false,
      routes: {
        '/bookings': (context) => const BookingListScreen(),
        '/payment-success': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          return PaymentSuccessScreen(
            bookingId: args?['bookingId']?.toString(),
            paymentId: args?['paymentId']?.toString(),
            totalAmount: args?['totalAmount']?.toDouble(),
            depositAmount: args?['depositAmount']?.toDouble(),
          );
        },
        '/payment-failure': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          return PaymentFailureScreen(
            bookingId: args?['bookingId']?.toString(),
            paymentId: args?['paymentId']?.toString(),
            errorMessage: args?['errorMessage']?.toString(),
          );
        },
      },
    );
  }
}

// Global navigator key for deep link handling
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
