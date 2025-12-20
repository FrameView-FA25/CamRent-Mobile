import 'package:flutter/material.dart';
import 'booking_model.dart';
import '../../services/api_service.dart';
import 'booking_detail_screen.dart';
import '../report/create_report_screen.dart';

class BookingHistoryScreen extends StatefulWidget {
  const BookingHistoryScreen({super.key});

  @override
  State<BookingHistoryScreen> createState() => _BookingHistoryScreenState();
}

class _BookingHistoryScreenState extends State<BookingHistoryScreen> {
  bool _isLoading = true;
  String? _error;
  List<BookingModel> _bookings = [];
  Map<String, bool> _processingBookings = {}; // Track which bookings are being processed
  Map<String, String?> _processingActions = {}; // Track which action is being processed: 'pickup' or 'cancel'

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  /// Tải danh sách lịch sử đặt lịch từ API /api/Bookings/renterbookings
  Future<void> _loadHistory() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      debugPrint('BookingHistoryScreen: Starting to load booking history from /api/Bookings/renterbookings...');
      
      // Gọi API với timeout để tránh load lâu
      final data = await ApiService.getBookings().timeout(
        const Duration(seconds: 35),
        onTimeout: () {
          debugPrint('BookingHistoryScreen: API call timeout');
          throw Exception('Kết nối quá lâu. Vui lòng kiểm tra kết nối mạng và thử lại');
        },
      );
      debugPrint('BookingHistoryScreen: Received ${data.length} items from API');
      debugPrint('BookingHistoryScreen: Data type: ${data.runtimeType}');
      
      // Log all booking IDs and dates for debugging
      if (data.isNotEmpty) {
        debugPrint('BookingHistoryScreen: === DEBUG: All bookings from API ===');
        for (int i = 0; i < data.length; i++) {
          final item = data[i];
          if (item is Map<String, dynamic>) {
            final id = item['id']?.toString() ?? item['_id']?.toString() ?? 'N/A';
            final createdAt = item['createdAt']?.toString() ?? 'N/A';
            final pickupAt = item['pickupAt']?.toString() ?? 'N/A';
            final status = item['status']?.toString() ?? 'N/A';
            debugPrint('BookingHistoryScreen: Booking $i - ID: $id, Status: $status, CreatedAt: $createdAt, PickupAt: $pickupAt');
          }
        }
        debugPrint('BookingHistoryScreen: === END DEBUG ===');
      }
      
      if (data.isEmpty) {
        debugPrint('BookingHistoryScreen: No bookings returned from API');
        if (mounted) {
          setState(() {
            _bookings = [];
            _isLoading = false;
          });
        }
        return;
      }

      final bookings = <BookingModel>[];
      for (int i = 0; i < data.length; i++) {
        final item = data[i];
        debugPrint('BookingHistoryScreen: Processing item $i - type: ${item.runtimeType}');
        
        if (item is Map<String, dynamic>) {
          debugPrint('BookingHistoryScreen: Item $i keys: ${item.keys.toList()}');
          debugPrint('BookingHistoryScreen: Item $i sample values: ${item.entries.take(5).map((e) => '${e.key}: ${e.value}').join(', ')}');
          try {
            // Check if item has id (but allow empty string - will be handled in fromJson)
            final itemId = item['id']?.toString() ?? item['_id']?.toString() ?? '';
            if (itemId.trim().isEmpty) {
              debugPrint('BookingHistoryScreen: Item $i has empty id, will generate temporary id');
              // Continue - fromJson will handle empty id
            }
            
            final booking = BookingModel.fromJson(item);
            debugPrint('BookingHistoryScreen: ✓ Successfully parsed booking $i');
            debugPrint('BookingHistoryScreen: Booking $i - id: ${booking.id}, status: ${booking.status}');
            debugPrint('BookingHistoryScreen: Booking $i - pickupAt: ${booking.pickupAt}, returnAt: ${booking.returnAt}');
            debugPrint('BookingHistoryScreen: Booking $i - totalPrice: ${booking.totalPrice}, items: ${booking.items.length}');
            debugPrint('BookingHistoryScreen: Booking $i - cameraName: ${booking.cameraName}');
            bookings.add(booking);
          } catch (e, stackTrace) {
            debugPrint('BookingHistoryScreen: ✗ Error parsing booking $i: $e');
            debugPrint('BookingHistoryScreen: StackTrace: $stackTrace');
            debugPrint('BookingHistoryScreen: Item data (first 500 chars): ${item.toString().length > 500 ? item.toString().substring(0, 500) : item.toString()}');
            // Continue parsing other items even if one fails
          }
        } else {
          debugPrint('BookingHistoryScreen: Item $i is not a Map: ${item.runtimeType}, value: $item');
        }
      }

      debugPrint('BookingHistoryScreen: Successfully parsed ${bookings.length} out of ${data.length} bookings');

      if (bookings.isEmpty && data.isNotEmpty) {
        debugPrint('BookingHistoryScreen: WARNING - All bookings failed to parse!');
        debugPrint('BookingHistoryScreen: First item sample: ${data.first}');
        debugPrint('BookingHistoryScreen: First item type: ${data.first.runtimeType}');
        if (data.first is Map) {
          debugPrint('BookingHistoryScreen: First item keys: ${(data.first as Map).keys.toList()}');
        }
        // If we have data but couldn't parse any, show error with details
        if (mounted) {
          setState(() {
            _bookings = [];
            _isLoading = false;
            _error = 'Nhận được ${data.length} đặt lịch từ server nhưng không thể xử lý dữ liệu.\n\nVui lòng kiểm tra console logs để biết thêm chi tiết hoặc thử lại sau.';
          });
        }
        return;
      }
      
      if (bookings.isEmpty) {
        debugPrint('BookingHistoryScreen: No bookings to display');
      }

      // Sort by date (newest first)
      // Priority: createdAt > pickupAt > returnAt
      bookings.sort((a, b) {
        // Try createdAt first
        DateTime? aDate = a.createdAt;
        DateTime? bDate = b.createdAt;
        
        // If createdAt is null, use pickupAt
        aDate ??= a.pickupAt;
        bDate ??= b.pickupAt;
        
        // If still null, use returnAt
        aDate ??= a.returnAt;
        bDate ??= b.returnAt;
        
        // Default to now if still null
        final aTs = aDate ?? DateTime.now();
        final bTs = bDate ?? DateTime.now();
        
        // Sort descending (newest first)
        return bTs.compareTo(aTs);
      });

      if (mounted) {
        debugPrint('BookingHistoryScreen: === FINAL RESULT ===');
        debugPrint('BookingHistoryScreen: Total bookings from API: ${data.length}');
        debugPrint('BookingHistoryScreen: Successfully parsed: ${bookings.length}');
        debugPrint('BookingHistoryScreen: Failed to parse: ${data.length - bookings.length}');
        if (bookings.isNotEmpty) {
          debugPrint('BookingHistoryScreen: Oldest booking date: ${bookings.map((b) => b.createdAt ?? b.pickupAt ?? b.returnAt).whereType<DateTime>().fold<DateTime?>(null, (oldest, date) => oldest == null || date.isBefore(oldest) ? date : oldest)}');
          debugPrint('BookingHistoryScreen: Newest booking date: ${bookings.map((b) => b.createdAt ?? b.pickupAt ?? b.returnAt).whereType<DateTime>().fold<DateTime?>(null, (newest, date) => newest == null || date.isAfter(newest) ? date : newest)}');
        }
        debugPrint('BookingHistoryScreen: === END FINAL RESULT ===');
        
        setState(() {
          _bookings = bookings;
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('BookingHistoryScreen: Exception - ${e.toString()}');
      debugPrint('BookingHistoryScreen: StackTrace - $stackTrace');
      
      if (!mounted) return;
      
      // Provide user-friendly error messages
      String errorMessage;
      if (e.toString().contains('timeout') || e.toString().contains('TimeoutException')) {
        errorMessage = 'Kết nối quá lâu. Vui lòng kiểm tra kết nối mạng và thử lại';
      } else if (e.toString().contains('SocketException') || e.toString().contains('Failed host lookup')) {
        errorMessage = 'Không thể kết nối đến server. Vui lòng kiểm tra kết nối mạng';
      } else if (e.toString().contains('401') || e.toString().contains('Unauthorized')) {
        errorMessage = 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại';
      } else {
        errorMessage = e.toString().replaceFirst('Exception: ', '');
        if (errorMessage.isEmpty) {
          errorMessage = 'Đã xảy ra lỗi không xác định. Vui lòng thử lại';
        }
      }
      
      setState(() {
        _error = errorMessage;
        _isLoading = false;
      });
    }
  }

  Color _statusColor(int status) {
    switch (status) {
      case 0:
        return Colors.orange; // Giỏ hàng (Draft)
      case 1:
        return Colors.blue; // Đã xác nhận (Confirmed)
      case 2:
        return Colors.green; // Đã nhận máy (PickedUp)
      case 3:
        return Colors.grey; // Đã trả (Returned)
      case 4:
        return Colors.purple; // Hoàn tất (Completed)
      case 5:
        return Colors.red; // Đã hủy (Cancelled)
      case 6:
        return Colors.deepOrange; // Quá hạn (Overdue)
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Chưa có';
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  String _formatDateRange(BookingModel booking) {
    final start = _formatDate(booking.pickupAt);
    final end = _formatDate(booking.returnAt);
    return '$start → $end';
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
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

  // Check if booking can be cancelled (before 9h of the day before pickup date)
  bool _canCancelBooking(BookingModel booking) {
    if (booking.pickupAt == null) return false;
    
    final now = DateTime.now();
    final pickupDate = booking.pickupAt!;
    
    // Calculate the deadline: 9h of the day before pickup date
    final deadlineDate = DateTime(
      pickupDate.year,
      pickupDate.month,
      pickupDate.day - 1,
      9, // 9h
      0,
    );
    
    return now.isBefore(deadlineDate);
  }

  // Get cancel deadline message
  String _getCancelDeadlineMessage(BookingModel booking) {
    if (booking.pickupAt == null) return '';
    
    final pickupDate = booking.pickupAt!;
    final deadlineDate = DateTime(
      pickupDate.year,
      pickupDate.month,
      pickupDate.day - 1,
      9, // 9h
      0,
    );
    
    final day = deadlineDate.day.toString().padLeft(2, '0');
    final month = deadlineDate.month.toString().padLeft(2, '0');
    final year = deadlineDate.year;
    
    return 'trước 9h ngày $day/$month/$year';
  }

  // Handle create report
  Future<void> _handleCreateReport(BookingModel booking) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateReportScreen(
          bookingId: booking.id,
        ),
      ),
    );

    // Reload bookings if report was created successfully
    if (mounted && result == true) {
      _loadHistory();
    }
  }

  // Handle pickup booking
  Future<void> _handlePickupBooking(BookingModel booking) async {
    if (_processingBookings[booking.id] == true) return;
    
    setState(() {
      _processingBookings[booking.id] = true;
      _processingActions[booking.id] = 'pickup';
    });

    try {
      await ApiService.updateBookingStatus(
        bookingId: booking.id,
        status: 'pickedUp',
      );

      if (mounted) {
        // Show success dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            elevation: 0,
            backgroundColor: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white,
                    Colors.green[50]!,
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Success icon with gradient background
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.green[400]!,
                            Colors.green[600]!,
                          ],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withOpacity(0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.check_circle,
                        color: Colors.white,
                        size: 48,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Title
                    Text(
                      'Đã nhận máy thành công',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[900],
                        letterSpacing: 0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    // Content
                    Text(
                      'Bạn đã xác nhận nhận máy thành công. Trạng thái đơn hàng đã được cập nhật.',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey[700],
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    // Close button
                    SizedBox(
                      width: double.infinity,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.green[400]!,
                              Colors.green[600]!,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withOpacity(0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            // Reload history to update status
                            _loadHistory();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            foregroundColor: Colors.white,
                          ),
                          child: const Text(
                            'Đóng',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: ${e.toString().replaceFirst('Exception: ', '')}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _processingBookings[booking.id] = false;
          _processingActions[booking.id] = null;
        });
      }
    }
  }

  // Handle cancel booking
  Future<void> _handleCancelBooking(BookingModel booking) async {
    // Check if can cancel
    if (!_canCancelBooking(booking)) {
      final deadlineMsg = _getCancelDeadlineMessage(booking);
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Không thể hủy đơn đặt lịch'),
            content: Text('Chỉ được hủy đơn hàng $deadlineMsg'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Đóng'),
              ),
            ],
          ),
        );
      }
      return;
    }

    // Show confirmation dialog with modern UI
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                Colors.grey[50]!,
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon with gradient background
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.orange[300]!,
                        Colors.orange[600]!,
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.sentiment_dissatisfied,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 24),
                // Title
                Text(
                  'Xác nhận hủy đơn',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[900],
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                // Content
                Text(
                  'Bạn có chắc chắn muốn hủy lịch thuê máy ảnh?',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey[700],
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                // Buttons
                Row(
                  children: [
                    // Cancel button
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: Colors.grey[300]!,
                              width: 1.5,
                            ),
                          ),
                          foregroundColor: Colors.grey[700],
                        ),
                        child: const Text(
                          'Hủy',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Confirm button
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.red[400]!,
                              Colors.red[600]!,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withOpacity(0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            foregroundColor: Colors.white,
                          ),
                          child: const Text(
                            'Xác nhận',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (confirmed != true) return;

    if (_processingBookings[booking.id] == true) return;
    
    setState(() {
      _processingBookings[booking.id] = true;
      _processingActions[booking.id] = 'cancel';
    });

    try {
      await ApiService.updateBookingStatus(
        bookingId: booking.id,
        status: 'cancel',
      );

      if (mounted) {
        // Show success dialog with deposit refund info
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green[700], size: 28),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Đã hủy lịch thành công'),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Đơn hàng đã được hủy thành công.'),
                const SizedBox(height: 12),
                if (booking.snapshotDepositAmount > 0)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.account_balance_wallet, color: Colors.green[700], size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Số tiền đặt cọc ${_formatCurrency(booking.snapshotDepositAmount)} sẽ được trả về ví của bạn.',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.green[900],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _loadHistory();
                },
                child: const Text('Đóng'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: ${e.toString().replaceFirst('Exception: ', '')}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _processingBookings[booking.id] = false;
          _processingActions[booking.id] = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch sử đặt lịch'),
        elevation: 0,
      ),
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
        child: _isLoading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      'Đang tải lịch sử đặt lịch...',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              )
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 64,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Không thể tải lịch sử đặt lịch',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _error!,
                            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: _loadHistory,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Thử lại'),
                          ),
                        ],
                      ),
                    ),
                  )
                : RefreshIndicator(
                        onRefresh: _loadHistory,
                        child: _bookings.isEmpty
                            ? SingleChildScrollView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                child: SizedBox(
                                  height: MediaQuery.of(context).size.height * 0.7,
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          width: 150,
                                          height: 150,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                Theme.of(context)
                                                    .colorScheme
                                                    .primary
                                                    .withOpacity(0.2),
                                                Theme.of(context)
                                                    .colorScheme
                                                    .primary
                                                    .withOpacity(0.1),
                                              ],
                                            ),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.history,
                                            size: 80,
                                            color: Theme.of(context).colorScheme.primary,
                                          ),
                                        ),
                                        const SizedBox(height: 32),
                                        Text(
                                          'Chưa có đặt lịch nào',
                                          style: TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.grey[800],
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 48),
                                          child: Text(
                                            'Khi bạn hoàn tất đặt lịch, chúng sẽ xuất hiện tại đây.',
                                            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              )
                            : ListView.builder(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                                itemCount: _bookings.length,
                                itemBuilder: (context, index) {
                                  final booking = _bookings[index];
                                  final statusColor = _statusColor(booking.status);
                                  
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    child: Material(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      elevation: 1,
                                      shadowColor: Colors.black.withOpacity(0.05),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(12),
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  BookingDetailScreen(booking: booking),
                                            ),
                                          );
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Row(
                                            children: [
                                              // Status indicator
                                              Container(
                                                width: 4,
                                                height: 60,
                                                decoration: BoxDecoration(
                                                  color: statusColor,
                                                  borderRadius: BorderRadius.circular(2),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              // Content
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    // Date range
                                                    Row(
                                                      children: [
                                                        Icon(
                                                          Icons.calendar_today,
                                                          size: 16,
                                                          color: Colors.grey[600],
                                                        ),
                                                        const SizedBox(width: 6),
                                                        Expanded(
                                                          child: Text(
                                                            _formatDateRange(booking),
                                                            style: const TextStyle(
                                                              fontSize: 15,
                                                              fontWeight: FontWeight.w600,
                                                              color: Colors.black87,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 8),
                                                    // Time range (if available)
                                                    if (booking.pickupAt != null && booking.returnAt != null)
                                                      Row(
                                                        children: [
                                                          Icon(
                                                            Icons.access_time,
                                                            size: 14,
                                                            color: Colors.grey[500],
                                                          ),
                                                          const SizedBox(width: 6),
                                                          Text(
                                                            '${_formatTime(booking.pickupAt!)} - ${_formatTime(booking.returnAt!)}',
                                                            style: TextStyle(
                                                              fontSize: 13,
                                                              color: Colors.grey[600],
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    const SizedBox(height: 8),
                                                    // Price
                                                    Text(
                                                      _formatCurrency(booking.totalPrice),
                                                      style: TextStyle(
                                                        fontSize: 18,
                                                        fontWeight: FontWeight.bold,
                                                        color: Theme.of(context).colorScheme.primary,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              // Status chip, buttons, and arrow
                                              Column(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: statusColor.withOpacity(0.15),
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: Text(
                                                      booking.statusString,
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.w600,
                                                        color: statusColor,
                                                      ),
                                                    ),
                                                  ),
                                                  // Show "Nhận hàng" button when status is "Đã xác nhận" (status = 1)
                                                  if (booking.status == 1) ...[
                                                    const SizedBox(height: 8),
                                                    SizedBox(
                                                      width: 100,
                                                      child: ElevatedButton(
                                                        onPressed: _processingActions[booking.id] != null
                                                            ? null
                                                            : () => _handlePickupBooking(booking),
                                                        style: ElevatedButton.styleFrom(
                                                          backgroundColor: Colors.green,
                                                          foregroundColor: Colors.white,
                                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                                          minimumSize: const Size(0, 32),
                                                        ),
                                                        child: _processingActions[booking.id] == 'pickup'
                                                            ? const SizedBox(
                                                                width: 16,
                                                                height: 16,
                                                                child: CircularProgressIndicator(
                                                                  strokeWidth: 2,
                                                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                                                ),
                                                              )
                                                            : const Text(
                                                                'Nhận hàng',
                                                                style: TextStyle(fontSize: 12),
                                                              ),
                                                      ),
                                                    ),
                                                  ],
                                                  // Show "Tạo report" button when status is "Đã nhận máy" (status = 2)
                                                  if (booking.status == 2) ...[
                                                    const SizedBox(height: 8),
                                                    SizedBox(
                                                      width: 100,
                                                      child: ElevatedButton(
                                                        onPressed: () => _handleCreateReport(booking),
                                                        style: ElevatedButton.styleFrom(
                                                          backgroundColor: Colors.orange,
                                                          foregroundColor: Colors.white,
                                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                                          minimumSize: const Size(0, 32),
                                                        ),
                                                        child: const Text(
                                                          'Tạo report',
                                                          style: TextStyle(fontSize: 12),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                  // Show "Hủy đơn" button only for Draft (0) and Confirmed (1) bookings
                                                  // Hide for: PickedUp (2), Returned (3), Completed (4), Cancelled (5), Overdue (6)
                                                  if (booking.status == 0 || booking.status == 1) ...[
                                                    const SizedBox(height: 6),
                                                    SizedBox(
                                                      width: 100,
                                                      child: OutlinedButton(
                                                        onPressed: _processingActions[booking.id] != null
                                                            ? null
                                                            : () => _handleCancelBooking(booking),
                                                        style: OutlinedButton.styleFrom(
                                                          foregroundColor: Colors.red,
                                                          side: const BorderSide(color: Colors.red),
                                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                                          minimumSize: const Size(0, 32),
                                                        ),
                                                        child: _processingActions[booking.id] == 'cancel'
                                                            ? const SizedBox(
                                                                width: 16,
                                                                height: 16,
                                                                child: CircularProgressIndicator(
                                                                  strokeWidth: 2,
                                                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                                                                ),
                                                              )
                                                            : const Text(
                                                                'Hủy đơn',
                                                                style: TextStyle(fontSize: 12),
                                                              ),
                                                      ),
                                                    ),
                                                  ],
                                                  const SizedBox(height: 8),
                                                  Icon(
                                                    Icons.chevron_right,
                                                    color: Colors.grey[400],
                                                    size: 20,
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
      ),
    );
  }
}
