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

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      debugPrint('BookingHistoryScreen: Starting to load booking history...');
      final data = await ApiService.getBookings();
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
        // If we have data but couldn't parse any, show error with details
        if (mounted) {
          setState(() {
            _bookings = [];
            _isLoading = false;
            _error = 'Nhận được ${data.length} đặt lịch từ server nhưng không thể xử lý dữ liệu. Vui lòng kiểm tra console logs để biết thêm chi tiết.';
          });
        }
        return;
      }

      // Sort by created date (newest first)
      bookings.sort((a, b) {
        final aTs = a.createdAt ?? DateTime.now();
        final bTs = b.createdAt ?? DateTime.now();
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
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
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
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primary.withOpacity(0.05),
              Colors.white,
            ],
            stops: const [0.0, 0.3],
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
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
                            : ListView.separated(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.all(16),
                                itemCount: _bookings.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 16),
                                itemBuilder: (context, index) {
                            final booking = _bookings[index];
                            final statusColor = _statusColor(booking.status);
                            return Material(
                              color: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          BookingDetailScreen(booking: booking),
                                    ),
                                  );
                                },
                                child: Ink(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        statusColor.withOpacity(0.18),
                                        Colors.white,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: statusColor.withOpacity(0.3),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.04),
                                        blurRadius: 12,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Container(
                                        width: 5,
                                        margin: const EdgeInsets.symmetric(vertical: 16),
                                        decoration: BoxDecoration(
                                          color: statusColor,
                                          borderRadius: const BorderRadius.only(
                                            topLeft: Radius.circular(20),
                                            bottomLeft: Radius.circular(20),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 16),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  CircleAvatar(
                                                    radius: 20,
                                                    backgroundColor:
                                                        statusColor.withOpacity(0.18),
                                                    child: Icon(
                                                      Icons.camera_alt,
                                                      color: statusColor,
                                                      size: 20,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                          booking.cameraName.isNotEmpty
                                                              ? booking.cameraName
                                                              : 'Máy ảnh đã xóa',
                                                          style: const TextStyle(
                                                            fontSize: 18,
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                        ),
                                                        const SizedBox(height: 6),
                                                        Row(
                                                          children: [
                                                            Icon(
                                                              Icons.person_outline,
                                                              size: 14,
                                                              color: Colors.grey[600],
                                                            ),
                                                            const SizedBox(width: 4),
                                                            Expanded(
                                                              child: Text(
                                                                booking.customerName,
                                                                style: TextStyle(
                                                                  fontSize: 13,
                                                                  color: Colors.grey[700],
                                                                ),
                                                                overflow: TextOverflow.ellipsis,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        if (booking.branchName != null &&
                                                            booking.branchName!.isNotEmpty) ...[
                                                          const SizedBox(height: 4),
                                                          Text(
                                                            booking.branchName!,
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              color: Colors.grey[500],
                                                            ),
                                                          ),
                                                        ],
                                                      ],
                                                    ),
                                                  ),
                                                  Chip(
                                                    label: Text(
                                                      booking.statusString,
                                                      style: TextStyle(
                                                        color: statusColor,
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                    backgroundColor:
                                                        statusColor.withOpacity(0.15),
                                                    padding: const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 0,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 14),
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment.start,
                                                      children: [
                                                        Row(
                                                          children: [
                                                            Icon(
                                                              Icons.date_range,
                                                              size: 14,
                                                              color: Colors.grey[500],
                                                            ),
                                                            const SizedBox(width: 6),
                                                            Text(
                                                              'Khoảng thời gian',
                                                              style: TextStyle(
                                                                fontSize: 11,
                                                                color: Colors.grey[500],
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        const SizedBox(height: 4),
                                                        Text(
                                                          _formatDateRange(booking),
                                                          style: const TextStyle(
                                                            fontSize: 14,
                                                            fontWeight: FontWeight.w600,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment.end,
                                                    children: [
                                                      Text(
                                                        'Tổng cộng',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: Colors.grey[500],
                                                        ),
                                                      ),
                                                      const SizedBox(height: 6),
                                                      Text(
                                                        _formatCurrency(booking.totalPrice),
                                                        style: TextStyle(
                                                          fontSize: 18,
                                                          fontWeight: FontWeight.bold,
                                                          color: Theme.of(context)
                                                              .colorScheme
                                                              .primary,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
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
                          },
                        ),
                      ),
      ),
    );
  }
}
