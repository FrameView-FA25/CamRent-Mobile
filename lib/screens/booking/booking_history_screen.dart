import 'package:flutter/material.dart';
import '../../models/booking_model.dart';
import '../../services/api_service.dart';
import 'booking_detail_screen.dart';

class BookingHistoryScreen extends StatefulWidget {
  const BookingHistoryScreen({super.key});

  @override
  State<BookingHistoryScreen> createState() => _BookingHistoryScreenState();
}

class _BookingHistoryScreenState extends State<BookingHistoryScreen> {
  bool _isLoading = true;
  String? _error;
  List<BookingModel> _bookings = [];

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
        if (aDate == null) {
          aDate = a.pickupAt;
        }
        if (bDate == null) {
          bDate = b.pickupAt;
        }
        
        // If still null, use returnAt
        if (aDate == null) {
          aDate = a.returnAt;
        }
        if (bDate == null) {
          bDate = b.returnAt;
        }
        
        // Default to now if still null
        final aTs = aDate ?? DateTime.now();
        final bTs = bDate ?? DateTime.now();
        
        // Sort descending (newest first)
        return bTs.compareTo(aTs);
      });

      if (mounted) {
        debugPrint('BookingHistoryScreen: Updated UI with ${bookings.length} bookings');
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
        return Colors.orange; // Chờ xử lý
      case 1:
        return Colors.blue; // Đã xác nhận
      case 2:
        return Colors.green; // Đang thuê
      case 3:
        return Colors.grey; // Đã trả
      case 4:
        return Colors.red; // Đã hủy
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
                                              // Status chip and arrow
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
