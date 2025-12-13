import 'package:flutter/material.dart';
import '../../models/booking_model.dart';
import '../../services/api_service.dart';
import 'staff_booking_detail_screen.dart';

class StaffBookingsScreen extends StatefulWidget {
  const StaffBookingsScreen({super.key});

  @override
  State<StaffBookingsScreen> createState() => _StaffBookingsScreenState();
}

class _StaffBookingsScreenState extends State<StaffBookingsScreen> {
  bool _isLoading = false;
  String? _error;
  List<BookingModel> _bookings = [];

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final bookingsData = await ApiService.getStaffBookings();
      final bookings = bookingsData.map((b) => BookingModel.fromJson(b as Map<String, dynamic>)).toList();
      
      setState(() {
        _bookings = bookings;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading staff bookings: $e');
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  String _formatCurrency(double value) {
    if (value <= 0) return '0 VNĐ';
    final raw = value.toStringAsFixed(0);
    final buffer = StringBuffer();
    for (int i = 0; i < raw.length; i++) {
      if (i > 0 && (raw.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(raw[i]);
    }
    return '${buffer.toString()} VNĐ';
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Chưa có';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pendingapproval':
      case 'chờ duyệt':
        return Colors.orange;
      case 'confirmed':
      case 'đã xác nhận':
        return Colors.blue;
      case 'pickedup':
      case 'đã nhận':
        return Colors.green;
      case 'returned':
      case 'đã trả':
        return Colors.teal;
      case 'completed':
      case 'hoàn thành':
        return Colors.green.shade700;
      case 'cancelled':
      case 'đã hủy':
        return Colors.red;
      case 'overdue':
      case 'quá hạn':
        return Colors.red.shade700;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
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
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            elevation: 0,
            backgroundColor: Colors.white,
            title: const Text(
              'Bookings',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
                letterSpacing: 0.5,
              ),
            ),
            actions: [
              Container(
                margin: const EdgeInsets.only(right: 8),
                child: IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.refresh_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  onPressed: _loadBookings,
                ),
              ),
            ],
          ),
          body: RefreshIndicator(
        onRefresh: _loadBookings,
        child: _isLoading && _bookings.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : _error != null && _bookings.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _error!,
                          style: TextStyle(color: Colors.grey[600]),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _loadBookings,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  )
                : _bookings.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inbox_outlined,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Chưa có đơn đặt lịch nào',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.only(
                          left: 20,
                          right: 20,
                          top: 20,
                          bottom: MediaQuery.of(context).padding.bottom + 90,
                        ),
                        itemCount: _bookings.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 16),
                        itemBuilder: (context, index) {
                          final booking = _bookings[index];
                          return _buildModernBookingCard(booking, index);
                        },
                      ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernBookingCard(BookingModel booking, int index) {
    final statusColor = _getStatusColor(booking.statusString);
    
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 300 + (index * 50)),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () async {
              try {
                final bookingData = await ApiService.getBookingByQr(booking.id);
                if (mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => StaffBookingDetailScreen(
                        bookingData: bookingData,
                        bookingId: booking.id,
                      ),
                    ),
                  ).then((_) {
                    _loadBookings();
                  });
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Lỗi: ${e.toString().replaceFirst('Exception: ', '')}'),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  );
                }
              }
            },
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with ID and Status
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Booking ID',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[600],
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              booking.id.length > 12 
                                  ? '${booking.id.substring(0, 12)}...' 
                                  : booking.id,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              statusColor,
                              statusColor.withOpacity(0.8),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: statusColor.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Text(
                          booking.statusString,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Divider
                  Container(
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.grey[200]!,
                          Colors.grey[100]!,
                          Colors.grey[200]!,
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Customer Info
                  _buildInfoRow(
                    icon: Icons.person_outline_rounded,
                    label: 'Customer',
                    value: booking.customerName,
                    iconColor: Theme.of(context).colorScheme.primary,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Products
                  _buildInfoRow(
                    icon: Icons.camera_alt_outlined,
                    label: 'Items',
                    value: booking.cameraName,
                    iconColor: Colors.blue,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Dates
                  _buildInfoRow(
                    icon: Icons.calendar_today_outlined,
                    label: 'Rental Period',
                    value: '${_formatDate(booking.pickupAt)} - ${_formatDate(booking.returnAt)}',
                    iconColor: Colors.orange,
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Total Price with modern design
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.primary.withOpacity(0.1),
                          Theme.of(context).colorScheme.primary.withOpacity(0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Amount',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.black54,
                          ),
                        ),
                        Text(
                          _formatCurrency(booking.snapshotRentalTotal),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 18,
            color: iconColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[600],
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

