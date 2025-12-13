import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/api_service.dart';
import '../booking/booking_list_screen.dart';
import 'payment_confirmation_screen.dart';

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
  // Deep link handling is done globally in main.dart using app_links

  Future<void> _processWalletPayment() async {
    final bookingId = _getBookingId();
    if (bookingId == null || bookingId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không tìm thấy mã đặt lịch. Vui lòng thử lại.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Đang xử lý thanh toán bằng ví...';
    });

    try {
      final calculatedTotal = _calculatePaymentAmount();
      final amount = widget.depositAmount > 0 ? widget.depositAmount : calculatedTotal;
      
      // Create payment authorization with Wallet method (2)
      final paymentId = await ApiService.createPaymentAuthorization(
        bookingId: bookingId,
        mode: 1, // Deposit
        method: 2, // Wallet
      );

      debugPrint('PaymentScreen: Wallet payment authorized, paymentId: $paymentId');

      // Show success dialog with amount
      if (mounted) {
        _showWalletPaymentSuccessDialog(amount);
      }
    } catch (e) {
      debugPrint('PaymentScreen: Wallet payment error: $e');
      if (mounted) {
        final errorMsg = e.toString().toLowerCase();
        // Check if it's an insufficient balance error
        if (errorMsg.contains('không đủ') || 
            errorMsg.contains('insufficient') || 
            errorMsg.contains('balance') ||
            errorMsg.contains('thiếu') ||
            errorMsg.contains('số dư')) {
          // Show insufficient balance dialog
          _showInsufficientBalanceDialog();
        } else {
          // Show generic error
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Thanh toán bằng ví thất bại: ${e.toString().replaceFirst('Exception: ', '')}'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() {
            _statusMessage = 'Thanh toán bằng ví thất bại';
          });
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _showWalletPaymentSuccessDialog(double amount) {
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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Đã trừ ví thành công!'),
            const SizedBox(height: 8),
            Text(
              'Số tiền: ${_formatCurrency(amount)}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Đơn hàng của bạn đang được xử lý.',
              style: TextStyle(fontSize: 14),
            ),
          ],
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

  void _showInsufficientBalanceDialog() {
    if (!mounted) return;
    
    final calculatedTotal = _calculatePaymentAmount();
    final amount = widget.depositAmount > 0 ? widget.depositAmount : calculatedTotal;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 8),
            Text('Ví không đủ tiền'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Số dư trong ví của bạn không đủ để thanh toán.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Số tiền cần thanh toán:',
                  style: TextStyle(fontSize: 14),
                ),
                Text(
                  _formatCurrency(amount),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Vui lòng nạp thêm tiền vào ví hoặc chọn phương thức thanh toán khác.',
              style: TextStyle(fontSize: 14),
            ),
          ],
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

  // Tính số tiền thanh toán từ booking data
  // Ưu tiên sử dụng snapshot data từ backend (chính xác nhất)
  Map<String, double> _getCalculationDetails() {
    try {
      debugPrint('PaymentScreen: Calculating payment details from booking data');
      debugPrint('PaymentScreen: bookingData keys: ${widget.bookingData.keys.toList()}');
      
      // ƯU TIÊN 1: Sử dụng snapshot data từ backend (chính xác nhất)
      var snapshotRentalTotalRaw = widget.bookingData['snapshotRentalTotal'];
      var snapshotPlatformFeePercentRaw = widget.bookingData['snapshotPlatformFeePercent'];
      
      final snapshotRentalTotal = (snapshotRentalTotalRaw is num 
          ? snapshotRentalTotalRaw.toDouble() 
          : (snapshotRentalTotalRaw?.toDouble() ?? 0.0));
      
      final snapshotPlatformFeePercent = (snapshotPlatformFeePercentRaw is num 
          ? snapshotPlatformFeePercentRaw.toDouble() 
          : (snapshotPlatformFeePercentRaw?.toDouble() ?? 0.0));
      
      // Nếu có snapshotRentalTotal từ backend, sử dụng nó (chính xác nhất)
      if (snapshotRentalTotal > 0) {
        final baseTotal = snapshotRentalTotal;
        final platformFeePercent = snapshotPlatformFeePercent > 0 ? snapshotPlatformFeePercent : 10.0;
        final platformFee = baseTotal * (platformFeePercent / 100);
        final remainingAmount = baseTotal - platformFee;
        
        debugPrint('PaymentScreen: Using snapshot data from backend:');
        debugPrint('  - snapshotRentalTotal: $baseTotal');
        debugPrint('  - snapshotPlatformFeePercent: $platformFeePercent');
        debugPrint('  - platformFee (paymentAmount): $platformFee');
        debugPrint('  - remainingAmount: $remainingAmount');
        
        return {
          'baseTotal': baseTotal,
          'platformFee': platformFee,
          'platformFeePercent': platformFeePercent,
          'paymentAmount': platformFee, // Số tiền thanh toán = phí đặt cọc thuêthuê
          'remainingAmount': remainingAmount,
        };
      }
      
      debugPrint('PaymentScreen: snapshotRentalTotal not available, calculating from dates and items');
      
      // FALLBACK: Tính toán từ dates và items
      final pickupAtStr = widget.bookingData['pickupAt']?.toString();
      final returnAtStr = widget.bookingData['returnAt']?.toString();
      
      if (pickupAtStr == null || returnAtStr == null) {
        debugPrint('PaymentScreen: No dates available, using fallback');
        // Nếu không có dates, sử dụng totalAmount và depositAmount
        final platformFeePercent = snapshotPlatformFeePercent > 0 ? snapshotPlatformFeePercent : 10.0;
        if (widget.totalAmount > 0 && platformFeePercent > 0) {
          // Giả sử totalAmount là baseTotal (tổng giá thuê)
          final baseTotal = widget.totalAmount;
          final platformFee = baseTotal * (platformFeePercent / 100);
          return {
            'baseTotal': baseTotal.toDouble(),
            'platformFee': platformFee.toDouble(),
            'platformFeePercent': platformFeePercent.toDouble(),
            'paymentAmount': platformFee.toDouble(),
            'remainingAmount': (baseTotal - platformFee).toDouble(),
          };
        }
        return {
          'baseTotal': widget.totalAmount.toDouble(),
          'platformFee': 0.0,
          'platformFeePercent': platformFeePercent.toDouble(),
          'paymentAmount': (widget.depositAmount > 0 ? widget.depositAmount : widget.totalAmount).toDouble(),
          'remainingAmount': 0.0,
        };
      }

      final pickupAt = DateTime.parse(pickupAtStr);
      final returnAt = DateTime.parse(returnAtStr);
      final rentalDays = returnAt.difference(pickupAt).inDays;
      
      if (rentalDays <= 0) {
        debugPrint('PaymentScreen: Invalid rental days: $rentalDays');
        final platformFeePercent = snapshotPlatformFeePercent > 0 ? snapshotPlatformFeePercent : 10.0;
        if (widget.totalAmount > 0 && platformFeePercent > 0) {
          final baseTotal = widget.totalAmount;
          final platformFee = baseTotal * (platformFeePercent / 100);
          return {
            'baseTotal': baseTotal.toDouble(),
            'platformFee': platformFee.toDouble(),
            'platformFeePercent': platformFeePercent.toDouble(),
            'paymentAmount': platformFee.toDouble(),
            'remainingAmount': (baseTotal - platformFee).toDouble(),
          };
        }
        return {
          'baseTotal': widget.totalAmount.toDouble(),
          'platformFee': 0.0,
          'platformFeePercent': platformFeePercent.toDouble(),
          'paymentAmount': (widget.depositAmount > 0 ? widget.depositAmount : widget.totalAmount).toDouble(),
          'remainingAmount': 0.0,
        };
      }

      // Tính từ items
      final items = widget.bookingData['items'];
      if (items is List && items.isNotEmpty) {
        double baseTotal = 0.0;
        double platformFeePercent = snapshotPlatformFeePercent > 0 ? snapshotPlatformFeePercent : 10.0;
        
        for (final item in items) {
          if (item is Map<String, dynamic>) {
            // Lấy giá thuê theo ngày
            var pricePerDayRaw = item['pricePerDay'] ?? 
                                item['price_per_day'] ?? 
                                item['dailyRate'] ?? 
                                item['daily_rate'] ??
                                item['snapshotPricePerDay'];
            
            // Lấy từ camera object nếu có
            final camera = item['camera'];
            if (camera is Map<String, dynamic>) {
              pricePerDayRaw ??= camera['pricePerDay'] ?? 
                                 camera['price_per_day'] ?? 
                                 camera['dailyRate'] ?? 
                                 camera['daily_rate'] ??
                                 camera['baseDailyRate'];
            }
            
            final pricePerDay = (pricePerDayRaw is num 
                ? pricePerDayRaw.toDouble() 
                : (pricePerDayRaw?.toDouble() ?? 0.0));
            
            // Lấy quantity
            final quantity = (item['quantity'] is num 
                ? (item['quantity'] as num).toInt() 
                : (int.tryParse(item['quantity']?.toString() ?? '1') ?? 1));
            
            // Lấy platformFeePercent từ item nếu chưa có
            if (platformFeePercent == 10.0) {
              var itemFeePercent = item['platformFeePercent'] ?? 
                                   item['platform_fee_percent'] ?? 
                                   item['feePercent'] ?? 
                                   item['fee_percent'];
              
              if (camera is Map<String, dynamic>) {
                itemFeePercent ??= camera['platformFeePercent'] ?? 
                                  camera['platform_fee_percent'] ?? 
                                  camera['feePercent'] ?? 
                                  camera['fee_percent'];
              }
              
              if (itemFeePercent != null) {
                platformFeePercent = (itemFeePercent is num 
                    ? itemFeePercent.toDouble() 
                    : (itemFeePercent.toDouble() ?? 10.0));
              }
            }
            
            // Tính baseTotal cho item này
            if (pricePerDay > 0) {
              baseTotal += rentalDays * pricePerDay * quantity;
            }
          }
        }
        
        if (baseTotal > 0) {
          final platformFee = baseTotal * (platformFeePercent / 100);
          final remainingAmount = baseTotal - platformFee;
          
          debugPrint('PaymentScreen: Calculated from items:');
          debugPrint('  - baseTotal: $baseTotal');
          debugPrint('  - platformFeePercent: $platformFeePercent');
          debugPrint('  - platformFee (paymentAmount): $platformFee');
          debugPrint('  - remainingAmount: $remainingAmount');
          
          return {
            'baseTotal': baseTotal.toDouble(),
            'platformFee': platformFee.toDouble(),
            'platformFeePercent': platformFeePercent.toDouble(),
            'paymentAmount': platformFee.toDouble(),
            'remainingAmount': remainingAmount.toDouble(),
          };
        }
      }
      
      // Fallback cuối cùng: sử dụng snapshotBaseDailyRate
      var snapshotBaseDailyRateRaw = widget.bookingData['snapshotBaseDailyRate'];
      final snapshotBaseDailyRate = (snapshotBaseDailyRateRaw is num 
          ? snapshotBaseDailyRateRaw.toDouble() 
          : (snapshotBaseDailyRateRaw?.toDouble() ?? 0.0));
      
      if (snapshotBaseDailyRate > 0 && rentalDays > 0) {
        final baseTotal = rentalDays * snapshotBaseDailyRate;
        final platformFeePercent = snapshotPlatformFeePercent > 0 ? snapshotPlatformFeePercent : 10.0;
        final platformFee = baseTotal * (platformFeePercent / 100);
        final remainingAmount = baseTotal - platformFee;
        
        debugPrint('PaymentScreen: Calculated from snapshotBaseDailyRate:');
        debugPrint('  - baseTotal: $baseTotal');
        debugPrint('  - platformFee: $platformFee');
        
        return {
          'baseTotal': baseTotal.toDouble(),
          'platformFee': platformFee.toDouble(),
          'platformFeePercent': platformFeePercent.toDouble(),
          'paymentAmount': platformFee.toDouble(),
          'remainingAmount': remainingAmount.toDouble(),
        };
      }
      
      // Fallback cuối cùng: sử dụng totalAmount
      debugPrint('PaymentScreen: Using totalAmount as fallback');
      final platformFeePercent = snapshotPlatformFeePercent > 0 ? snapshotPlatformFeePercent : 10.0;
      if (widget.totalAmount > 0 && platformFeePercent > 0) {
        final baseTotal = widget.totalAmount;
        final platformFee = baseTotal * (platformFeePercent / 100);
        return {
          'baseTotal': baseTotal,
          'platformFee': platformFee,
          'platformFeePercent': platformFeePercent,
          'paymentAmount': platformFee,
          'remainingAmount': baseTotal - platformFee,
        };
      }
      
      return {
        'baseTotal': widget.totalAmount,
        'platformFee': 0.0,
        'platformFeePercent': platformFeePercent,
        'paymentAmount': widget.depositAmount > 0 ? widget.depositAmount : widget.totalAmount,
        'remainingAmount': 0.0,
      };
    } catch (e, stackTrace) {
      debugPrint('PaymentScreen: Error calculating payment details: $e');
      debugPrint('PaymentScreen: StackTrace: $stackTrace');
      // Fallback an toàn
      final platformFeePercent = 10.0;
      if (widget.totalAmount > 0) {
        final baseTotal = widget.totalAmount;
        final platformFee = baseTotal * (platformFeePercent / 100);
        return {
          'baseTotal': baseTotal,
          'platformFee': platformFee,
          'platformFeePercent': platformFeePercent,
          'paymentAmount': platformFee,
          'remainingAmount': baseTotal - platformFee,
        };
      }
      return {
        'baseTotal': 0.0,
        'platformFee': 0.0,
        'platformFeePercent': platformFeePercent,
        'paymentAmount': widget.depositAmount > 0 ? widget.depositAmount : widget.totalAmount,
        'remainingAmount': 0.0,
      };
    }
  }

  double _calculatePaymentAmount() {
    final details = _getCalculationDetails();
    return details['paymentAmount'] ?? widget.totalAmount;
  }


  String? _getBookingId() {
    debugPrint('PaymentScreen: _getBookingId() called');
    debugPrint('PaymentScreen: bookingData keys: ${widget.bookingData.keys.toList()}');
    
    // First, try direct extraction from bookingData
    final direct = _tryExtractBookingIdFromMap(widget.bookingData);
    if (direct != null && direct.isNotEmpty) {
      debugPrint('PaymentScreen: Found bookingId directly: $direct');
      return direct;
    }
    
    // If not found, search in nested structures
    debugPrint('PaymentScreen: Not found directly, searching nested structures...');
    final nested = _searchForBookingId(widget.bookingData);
    if (nested != null && nested.isNotEmpty) {
      debugPrint('PaymentScreen: Found bookingId in nested: $nested');
      return nested;
    }
    
    debugPrint('PaymentScreen: WARNING - No bookingId found anywhere');
    return null;
  }

  String? _searchForBookingId(dynamic source) {
    if (source is Map<String, dynamic>) {
      // Skip if already checked at root level
      if (source == widget.bookingData) {
        return null; // Already checked in _getBookingId
      }
      
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
    // Priority order: id (root level) first, then bookingId (but verify not contractId)
    // Make sure we don't accidentally get contractId
    
    debugPrint('PaymentScreen: Extracting bookingId from map');
    debugPrint('PaymentScreen: Map keys: ${map.keys.toList()}');
    
    // Get all contractIds first to exclude them
    final contractIds = <String>{};
    
    // Check contractId field if it exists
    final contractIdField = map['contractId']?.toString().trim();
    if (contractIdField != null && contractIdField.isNotEmpty) {
      contractIds.add(contractIdField);
      debugPrint('PaymentScreen: Found contractId in contractId field: $contractIdField');
    }
    
    // Get contractIds from contracts array
    final contracts = map['contracts'];
    if (contracts is List) {
      for (final contract in contracts) {
        if (contract is Map<String, dynamic>) {
          final contractId = contract['id']?.toString().trim();
          if (contractId != null && contractId.isNotEmpty) {
            contractIds.add(contractId);
            debugPrint('PaymentScreen: Found contractId in contracts array: $contractId');
          }
        }
      }
    }
    
    debugPrint('PaymentScreen: All contractIds collected: $contractIds');
    
    // Priority 1: Try 'id' field first (root level bookingId)
    // This is the most reliable source for bookingId
    final id = map['id']?.toString().trim();
    if (id != null && id.isNotEmpty) {
      if (contractIds.contains(id)) {
        debugPrint('PaymentScreen: WARNING - id field contains contractId: $id');
        debugPrint('PaymentScreen: Skipping id field, it is a contractId');
      } else {
        debugPrint('PaymentScreen: ✓ Found bookingId from id key: $id');
        return id;
      }
    } else {
      debugPrint('PaymentScreen: No id field found in map');
    }
    
    // Priority 2: Try bookingId field, but verify it's not a contractId
    final bookingIdField = map['bookingId']?.toString().trim();
    if (bookingIdField != null && bookingIdField.isNotEmpty) {
      if (contractIds.contains(bookingIdField)) {
        debugPrint('PaymentScreen: WARNING - bookingId field contains contractId: $bookingIdField');
        debugPrint('PaymentScreen: Skipping bookingId field, it is a contractId');
      } else {
        debugPrint('PaymentScreen: ✓ Found bookingId from bookingId key: $bookingIdField');
        return bookingIdField;
      }
    } else {
      debugPrint('PaymentScreen: No bookingId field found in map');
    }
    
    // Try other variations
    const otherKeys = ['_id', 'cartId', 'bookingCartId', 'bookingIdentifier'];
    for (final key in otherKeys) {
      final value = map[key]?.toString().trim();
      if (value != null && value.isNotEmpty && !contractIds.contains(value)) {
        debugPrint('PaymentScreen: ✓ Found bookingId from $key: $value');
        return value;
      }
    }
    
    debugPrint('PaymentScreen: ✗ WARNING - No bookingId found in map');
    debugPrint('PaymentScreen: Map values: ${map.entries.map((e) => '${e.key}: ${e.value}').join(', ')}');
    debugPrint('PaymentScreen: Available contractIds: $contractIds');
    return null;
  }

  bool _isProcessing = false;
  String _statusMessage = 'Chưa có giao dịch thanh toán';
  int _selectedPaymentMethod = 1; // 1 = PayOS, 2 = Wallet

  @override
  void initState() {
    super.initState();
    // Removed auto-open payment URL - user should choose payment method first
    // Payment URL will be opened only when user selects PayOS and clicks "Thanh toán"
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
      
      // Try to get bookingId for logging, but don't fail if not found
      // (paymentUrl is already available, so bookingId is not critical)
      String? bookingId;
      try {
        bookingId = _getBookingId();
      } catch (e) {
        debugPrint('PaymentScreen: Could not get bookingId for logging: $e');
      }
      
      final paymentId = widget.bookingData['paymentId']?.toString();
      
      debugPrint('PaymentScreen: Opening external browser with URL: $cleanedUrl');
      debugPrint('PaymentScreen: Booking ID: $bookingId');
      debugPrint('PaymentScreen: Payment ID: $paymentId');
      
      // Deep link handling is done globally in main.dart using app_links
      // No need to listen here as main.dart will handle payment callbacks
      
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
        });
        
        // Navigate to payment confirmation screen
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => PaymentConfirmationScreen(
                bookingId: bookingId,
                paymentId: paymentId,
                totalAmount: widget.totalAmount,
                depositAmount: widget.depositAmount,
              ),
            ),
          );
        }
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

    // CRITICAL: Collect all contractIds first
    final contractIds = <String>{};
    
    // Get contractId from contractId field if exists
    final contractIdField = widget.bookingData['contractId']?.toString().trim();
    if (contractIdField != null && contractIdField.isNotEmpty) {
      contractIds.add(contractIdField);
      debugPrint('PaymentScreen: Found contractId in contractId field: $contractIdField');
    }
    
    // Get contractIds from contracts array
    final contracts = widget.bookingData['contracts'];
    if (contracts is List) {
      for (final contract in contracts) {
        if (contract is Map<String, dynamic>) {
          final contractId = contract['id']?.toString().trim();
          if (contractId != null && contractId.isNotEmpty) {
            contractIds.add(contractId);
            debugPrint('PaymentScreen: Found contractId in contracts array: $contractId');
          }
        }
      }
    }
    
    debugPrint('PaymentScreen: All contractIds found: $contractIds');
    debugPrint('PaymentScreen: Full bookingData keys: ${widget.bookingData.keys.toList()}');
    
    // Get booking ID - prioritize root level 'id' field
    var bookingId = widget.bookingData['id']?.toString().trim();
    
    // Verify root level 'id' is not a contractId
    if (bookingId != null && bookingId.isNotEmpty) {
      if (contractIds.contains(bookingId)) {
        debugPrint('PaymentScreen: WARNING - root id field contains contractId: $bookingId');
        bookingId = null; // Reset to find real bookingId
      } else {
        debugPrint('PaymentScreen: ✓ Found bookingId from root id field: $bookingId');
      }
    }
    
    // If root level 'id' is not available or is contractId, try other methods
    if (bookingId == null || bookingId.isEmpty) {
      debugPrint('PaymentScreen: Root id not available, trying _getBookingId()...');
      bookingId = _getBookingId();
      
      if (bookingId != null && bookingId.isNotEmpty) {
        debugPrint('PaymentScreen: Found bookingId from _getBookingId(): $bookingId');
        
        // Verify it's not a contractId
        if (contractIds.contains(bookingId)) {
          debugPrint('PaymentScreen: ERROR - bookingId from _getBookingId() is contractId: $bookingId');
          bookingId = null; // Reset
        }
      }
    }
    
    // If still no valid bookingId, call API immediately
    if (bookingId == null || bookingId.isEmpty || contractIds.contains(bookingId)) {
      debugPrint('PaymentScreen: No valid bookingId found, calling API immediately...');
      
      // If we have a contractId, use it to find booking
      String? contractIdToSearch;
      if (contractIds.isNotEmpty) {
        contractIdToSearch = contractIds.first;
        debugPrint('PaymentScreen: Using contractId to search: $contractIdToSearch');
      } else {
        // If all fields are contractId, use the contractId field
        contractIdToSearch = contractIdField;
        debugPrint('PaymentScreen: Using contractId field to search: $contractIdToSearch');
      }
      
      if (contractIdToSearch != null && contractIdToSearch.isNotEmpty) {
        try {
          setState(() {
            _isProcessing = true;
            _statusMessage = 'Đang tìm mã đặt lịch...';
          });
          
          final bookings = await ApiService.getBookings();
          debugPrint('PaymentScreen: Retrieved ${bookings.length} bookings from API');
          
          // Find booking that contains this contractId
          bool found = false;
          for (final booking in bookings) {
            if (booking is Map<String, dynamic>) {
              final bookingIdFromApi = booking['id']?.toString().trim();
              final bookingContracts = booking['contracts'];
              if (bookingContracts is List) {
                for (final bc in bookingContracts) {
                  if (bc is Map<String, dynamic>) {
                    final bcId = bc['id']?.toString().trim();
                    if (bcId == contractIdToSearch) {
                      // Found the booking containing this contract
                      if (bookingIdFromApi != null && bookingIdFromApi.isNotEmpty && !contractIds.contains(bookingIdFromApi)) {
                        debugPrint('PaymentScreen: ✓ Found real bookingId from API: $bookingIdFromApi');
                        bookingId = bookingIdFromApi;
                        // Update bookingData with correct bookingId
                        widget.bookingData['id'] = bookingId;
                        widget.bookingData['bookingId'] = bookingId;
                        found = true;
                        break;
                      }
                    }
                  }
                }
                if (found) break; // Found, exit outer loop
              }
            }
          }
          
          if (!found) {
            debugPrint('PaymentScreen: ERROR - Cannot find booking containing contractId: $contractIdToSearch');
            // Try to get the most recent booking as fallback
            if (bookings.isNotEmpty) {
              final latestBooking = bookings.first;
              if (latestBooking is Map<String, dynamic>) {
                final latestBookingId = latestBooking['id']?.toString().trim();
                if (latestBookingId != null && latestBookingId.isNotEmpty && !contractIds.contains(latestBookingId)) {
                  debugPrint('PaymentScreen: Using latest booking as fallback: $latestBookingId');
                  bookingId = latestBookingId;
                  widget.bookingData['id'] = bookingId;
                  widget.bookingData['bookingId'] = bookingId;
                }
              }
            }
          }
        } catch (e) {
          debugPrint('PaymentScreen: Error calling API to find booking: $e');
          // Don't throw, continue with payment flow if we have paymentUrl
        }
      }
    }
    
    // Final check
    if (bookingId == null || bookingId.isEmpty) {
      debugPrint('PaymentScreen: ERROR - No bookingId found after all attempts');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không tìm thấy mã đặt lịch để tạo thanh toán. Vui lòng thử lại.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    // Final verification
    if (contractIds.contains(bookingId)) {
      debugPrint('PaymentScreen: ERROR - Final bookingId is still a contractId: $bookingId');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lỗi: Không tìm thấy mã đặt lịch hợp lệ. Vui lòng thử lại.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    debugPrint('PaymentScreen: Final verified bookingId: $bookingId');

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Đang lấy liên kết thanh toán...';
    });

    try {
      debugPrint('PaymentScreen: Getting payment URL for bookingId: $bookingId');
      
      // Note: Delay is now handled inside getPaymentUrlFromBookingId with retry logic
      // Get payment URL directly from booking ID (simplified flow)
      final calculatedTotal = _calculatePaymentAmount();
      final amount = widget.depositAmount > 0 ? widget.depositAmount : calculatedTotal;
      final paymentResult = await ApiService.getPaymentUrlFromBookingId(
        bookingId: bookingId,
        mode: 'Deposit',
        amount: amount,
        description: 'Thanh toán đặt cọc cho đơn hàng $bookingId',
      );

      // Extract paymentId and paymentUrl from Map response
      final paymentId = paymentResult['paymentId']?.toString();
      final paymentUrl = paymentResult['paymentUrl']?.toString() ?? '';

      debugPrint('PaymentScreen: Payment URL received: ${paymentUrl.isNotEmpty ? "yes" : "no"}');
      debugPrint('PaymentScreen: Payment ID: $paymentId');
      if (paymentUrl.isNotEmpty) {
        debugPrint('PaymentScreen: Payment URL: $paymentUrl');
      } else {
        debugPrint('PaymentScreen: ERROR - Payment URL is empty!');
        throw Exception('Không nhận được URL thanh toán từ server');
      }

      // Save URL and paymentId to bookingData for future use
      widget.bookingData['paymentUrl'] = paymentUrl;
      if (paymentId != null && paymentId.isNotEmpty) {
        widget.bookingData['paymentId'] = paymentId;
        debugPrint('PaymentScreen: Saved paymentId to bookingData: $paymentId');
      }
      
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


  @override
  Widget build(BuildContext context) {
    final bookingId = _getBookingId();

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFFFF6600).withOpacity(0.25), // Cam - chủ đạo
              const Color(0xFFFF6600).withOpacity(0.2), // Cam - tiếp tục
              const Color(0xFF00A651).withOpacity(0.15), // Xanh lá - nhẹ
              const Color(0xFF0066CC).withOpacity(0.1), // Xanh dương - rất nhẹ
            ],
            stops: const [0.0, 0.4, 0.7, 1.0],
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
                            'Thông tin thanh toán',
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
                      // Thông tin thanh toán
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
                                  Icons.payment,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Thông tin thanh toán',
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
                            const SizedBox(height: 8),
                            Builder(
                              builder: (context) {
                                final details = _getCalculationDetails();
                                final baseTotal = details['baseTotal'] ?? 0.0;
                                final platformFee = details['platformFee'] ?? 0.0;
                                final platformFeePercent = details['platformFeePercent'] ?? 0.0;
                                final remainingAmount = details['remainingAmount'] ?? 0.0;
                                
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    // Tổng giá thuê cơ bản
                                    if (baseTotal > 0) ...[
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Tổng giá thuê',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey[700],
                                            ),
                                          ),
                                          Text(
                                            _formatCurrency(baseTotal),
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                    ],
                                    // Phí nền tảng (số tiền thanh toán)
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            platformFeePercent > 0
                                                ? 'Phí đặt cọc thuê (${platformFeePercent.toStringAsFixed(0)}%)'
                                                : 'Phí nền tảng (số tiền thanh toán)',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          _formatCurrency(platformFee),
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Theme.of(context).colorScheme.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    // Phần còn lại
                                    if (remainingAmount > 0) ...[
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Phần thanh toán nhận thiết bị',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey[700],
                                            ),
                                          ),
                                          Text(
                                            _formatCurrency(remainingAmount),
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey[700],
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Chọn phương thức thanh toán
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
                            const Text(
                              'Chọn phương thức thanh toán',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            RadioListTile<int>(
                              title: const Row(
                                children: [
                                  Icon(Icons.account_balance_wallet, color: Colors.blue),
                                  SizedBox(width: 8),
                                  Text('Thanh toán bằng ví'),
                                ],
                              ),
                              value: 2,
                              groupValue: _selectedPaymentMethod,
                              onChanged: _isProcessing ? null : (value) {
                                setState(() {
                                  _selectedPaymentMethod = value!;
                                });
                              },
                              activeColor: Colors.blue,
                            ),
                            RadioListTile<int>(
                              title: const Row(
                                children: [
                                  Icon(Icons.payment, color: Colors.green),
                                  SizedBox(width: 8),
                                  Text('Thanh toán PayOS'),
                                ],
                              ),
                              value: 1,
                              groupValue: _selectedPaymentMethod,
                              onChanged: _isProcessing ? null : (value) {
                                setState(() {
                                  _selectedPaymentMethod = value!;
                                });
                              },
                              activeColor: Colors.green,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _isProcessing ? null : () {
                          if (_selectedPaymentMethod == 2) {
                            // Wallet payment
                            _processWalletPayment();
                          } else {
                            // PayOS payment
                            _startPayOsFlow();
                          }
                        },
                        icon: Icon(_selectedPaymentMethod == 2 ? Icons.account_balance_wallet : Icons.payment),
                        label: Text(
                          _isProcessing
                              ? 'Đang xử lý...'
                              : (_selectedPaymentMethod == 2 ? 'Thanh toán bằng ví' : 'Thanh toán qua PayOS'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _selectedPaymentMethod == 2 ? Colors.blue : Colors.green,
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

