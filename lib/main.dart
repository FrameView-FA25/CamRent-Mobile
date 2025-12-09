import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:app_links/app_links.dart';
import 'screens/login/login_screen.dart';
import 'screens/booking/booking_list_screen.dart';
import 'screens/payment/payment_success_screen.dart';

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

  void _handleDeepLink(Uri uri) {
    debugPrint('MyApp: Handling deep link: $uri');
    
    final path = uri.path;
    final queryParams = uri.queryParameters;
    final bookingId = queryParams['bookingId'];
    final paymentId = queryParams['paymentId'];
    final status = queryParams['status'];
    
    // Check for payment success/cancel in various formats
    bool isSuccess = false;
    bool isCancel = false;
    
    // Check deeplink format: cameraforrent://payment/success
    if (uri.scheme == 'cameraforrent' && uri.host == 'payment') {
      if (path.contains('/success') || status == 'success') {
        isSuccess = true;
      } else if (path.contains('/cancel') || status == 'cancel') {
        isCancel = true;
      }
    }
    // Check HTTP redirect format: https://.../return?status=success
    else if (uri.scheme == 'https' || uri.scheme == 'http') {
      if (path.contains('/return') || path.contains('/payment/return')) {
        if (status == 'success' || queryParams.containsKey('success')) {
          isSuccess = true;
        } else if (status == 'cancel' || queryParams.containsKey('cancel')) {
          isCancel = true;
        }
      } else if (path.contains('/payment/success') || uri.toString().contains('success')) {
        isSuccess = true;
      } else if (path.contains('/payment/cancel') || uri.toString().contains('cancel')) {
        isCancel = true;
      }
    }
    
    if (isSuccess) {
      debugPrint('MyApp: Payment success detected from redirect');
      debugPrint('MyApp: Booking ID: $bookingId, Payment ID: $paymentId');
      
      // Handle payment success
      _handlePaymentSuccess(bookingId, paymentId);
    } else if (isCancel) {
      debugPrint('MyApp: Payment cancelled detected from redirect');
      
      // Handle payment cancel
      _handlePaymentCancel(bookingId, paymentId);
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
    
    // Show cancel message
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = navigatorKey.currentContext;
      if (context != null) {
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
              'Bạn đã hủy thanh toán. Đơn hàng vẫn được giữ lại. Bạn có thể thử thanh toán lại sau.',
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
      },
    );
  }
}

// Global navigator key for deep link handling
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
