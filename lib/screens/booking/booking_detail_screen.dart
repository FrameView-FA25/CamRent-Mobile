import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/booking_model.dart';
import '../../services/api_service.dart';

class BookingDetailScreen extends StatefulWidget {
  final BookingModel booking;

  const BookingDetailScreen({
    super.key,
    required this.booking,
  });

  @override
  State<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends State<BookingDetailScreen> {
  bool _isProcessingPayment = false;

  BookingModel get booking => widget.booking;

  Future<void> _handlePayment() async {
    if (_isProcessingPayment) return;

    setState(() {
      _isProcessingPayment = true;
    });

    try {
      // Step 1: Create payment authorization
      debugPrint('Creating payment authorization for booking: ${booking.id}');
      final paymentId = await ApiService.createPaymentAuthorization(
        bookingId: booking.id,
      );

      debugPrint('Payment authorization created: $paymentId');

      // Step 2: Initialize PayOS payment
      final amount = booking.snapshotRentalTotal > 0 
          ? booking.snapshotRentalTotal 
          : booking.snapshotDepositAmount;
      
      if (amount <= 0) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Số tiền thanh toán không hợp lệ'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      debugPrint('Initializing PayOS payment: paymentId=$paymentId, amount=$amount');
      
      final returnUrl = 'https://camrent-app.com/payment/success';
      final cancelUrl = 'https://camrent-app.com/payment/cancel';
      final bookingIdShort = booking.id.length >= 8 
          ? booking.id.substring(0, 8) 
          : booking.id;
      final description = 'Thanh toán đơn hàng $bookingIdShort...';

      final paymentUrl = await ApiService.initializePayOSPayment(
        paymentId: paymentId,
        amount: amount,
        description: description,
        returnUrl: returnUrl,
        cancelUrl: cancelUrl,
      );

      debugPrint('PayOS payment URL: $paymentUrl');

      if (!mounted) return;

      // Step 3: Launch payment URL
      final uri = Uri.parse(paymentUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đang mở trang thanh toán...'),
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        throw Exception('Không thể mở liên kết thanh toán');
      }
    } catch (e) {
      debugPrint('Payment error: $e');
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi thanh toán: ${e.toString().replaceFirst('Exception: ', '')}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingPayment = false;
        });
      }
    }
  }

  bool get _canPay => 
      booking.status == 0 || // PendingApproval
      (booking.snapshotRentalTotal > 0 || booking.snapshotDepositAmount > 0);

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(booking.status);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết đặt lịch'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.calendar_today,
                        color: statusColor,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Trạng thái',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            booking.statusString,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Booking Information
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Thông tin đặt lịch',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildInfoRow(
                      context,
                      icon: Icons.confirmation_number,
                      label: 'Mã đặt lịch',
                      value: booking.id,
                    ),
                    const Divider(height: 24),
                    _buildInfoRow(
                      context,
                      icon: Icons.calendar_today,
                      label: 'Ngày nhận',
                      value: _formatDate(booking.pickupAt),
                    ),
                    const Divider(height: 24),
                    _buildInfoRow(
                      context,
                      icon: Icons.event,
                      label: 'Ngày trả',
                      value: _formatDate(booking.returnAt),
                    ),
                    if (booking.pickupAt != null && booking.returnAt != null) ...[
                      const Divider(height: 24),
                      _buildInfoRow(
                        context,
                        icon: Icons.access_time,
                        label: 'Số ngày thuê',
                        value: '${booking.returnAt!.difference(booking.pickupAt!).inDays + 1} ngày',
                      ),
                    ],
                    if (booking.createdAt != null) ...[
                      const Divider(height: 24),
                      _buildInfoRow(
                        context,
                        icon: Icons.schedule,
                        label: 'Ngày tạo',
                        value: _formatDateTime(booking.createdAt!),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Location Information
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Địa điểm',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (booking.raw['location'] != null) ...[
                      ..._buildLocationInfo(context, booking.raw['location']),
                    ] else ...[
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Column(
                            children: [
                              Icon(
                                Icons.location_off_outlined,
                                size: 48,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Chưa có thông tin địa điểm',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Customer Information
            Builder(
              builder: (context) {
                final phone = booking.customerPhone;
                final email = booking.customerEmail;
                final renterId = booking.renterId;
                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Thông tin khách hàng',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildInfoRow(
                          context,
                          icon: Icons.person,
                          label: 'Họ và tên',
                          value: booking.customerName,
                        ),
                        if (renterId != null && renterId.isNotEmpty) ...[
                          const Divider(height: 24),
                          _buildInfoRow(
                            context,
                            icon: Icons.badge,
                            label: 'ID khách hàng',
                            value: renterId,
                          ),
                        ],
                        if (phone.isNotEmpty) ...[
                          const Divider(height: 24),
                          _buildInfoRow(
                            context,
                            icon: Icons.phone,
                            label: 'Số điện thoại',
                            value: phone,
                          ),
                        ],
                        if (email.isNotEmpty) ...[
                          const Divider(height: 24),
                          _buildInfoRow(
                            context,
                            icon: Icons.email,
                            label: 'Email',
                            value: email,
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // Items Information
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking.items.isNotEmpty
                          ? 'Sản phẩm (${booking.items.length})'
                          : 'Sản phẩm',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (booking.items.isEmpty) ...[
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Column(
                            children: [
                              Icon(
                                Icons.inventory_2_outlined,
                                size: 48,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Chưa có sản phẩm',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ] else ...[
                      ...booking.items.asMap().entries.map((entry) {
                        final index = entry.key;
                        final item = entry.value;
                        return Column(
                          children: [
                            if (index > 0) const Divider(height: 24),
                            _buildItemInfo(context, item, index + 1),
                          ],
                        );
                      }),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Pricing Information
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Thông tin thanh toán',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Calculate deposit and platform fee percentages from raw data
                    Builder(
                      builder: (context) {
                        final depositPercentRaw = booking.raw['snapshotDepositPercent'];
                        final depositPercent = depositPercentRaw != null
                            ? (depositPercentRaw is num
                                ? depositPercentRaw.toDouble()
                                : (double.tryParse(depositPercentRaw.toString()) ?? 0.0))
                            : 0.0;
                        
                        final platformFeePercentRaw = booking.raw['snapshotPlatformFeePercent'];
                        final platformFeePercent = platformFeePercentRaw != null
                            ? (platformFeePercentRaw is num
                                ? platformFeePercentRaw.toDouble()
                                : (double.tryParse(platformFeePercentRaw.toString()) ?? 0.0))
                            : 0.0;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (booking.snapshotBaseDailyRate > 0) ...[
                              _buildInfoRow(
                                context,
                                icon: Icons.monetization_on,
                                label: 'Giá thuê/ngày',
                                value: _formatCurrency(booking.snapshotBaseDailyRate),
                              ),
                              Divider(height: 24),
                            ],
                            _buildInfoRow(
                              context,
                              icon: Icons.payments,
                              label: 'Tổng tiền',
                              value: _formatCurrency(booking.snapshotRentalTotal),
                              isHighlight: true,
                            ),
                            if (booking.snapshotDepositAmount > 0) ...[
                              Divider(height: 24),
                              _buildInfoRow(
                                context,
                                icon: Icons.security,
                                label: 'Tiền đặt cọc',
                                value: _formatCurrency(booking.snapshotDepositAmount),
                              ),
                            ],
                            if (depositPercent > 0) ...[
                              Divider(height: 24),
                              _buildInfoRow(
                                context,
                                icon: Icons.percent,
                                label: 'Tỷ lệ đặt cọc',
                                value: '${(depositPercent * 100).toStringAsFixed(0)}%',
                              ),
                            ],
                            if (platformFeePercent > 0) ...[
                              Divider(height: 24),
                              _buildInfoRow(
                                context,
                                icon: Icons.local_atm,
                                label: 'Phí nền tảng',
                                value: '${(platformFeePercent * 100).toStringAsFixed(0)}%',
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Payment Button
            if (_canPay) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isProcessingPayment ? null : _handlePayment,
                    icon: _isProcessingPayment
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.payment),
                    label: Text(
                      _isProcessingPayment
                          ? 'Đang xử lý...'
                          : 'Thanh toán ngay',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    bool isHighlight = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
          color: isHighlight
              ? Theme.of(context).colorScheme.primary
              : Colors.grey[600],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
                  color: isHighlight
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey[800],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildLocationInfo(BuildContext context, dynamic location) {
    if (location is! Map<String, dynamic>) {
      return [];
    }

    final widgets = <Widget>[];
    final country = location['country']?.toString();
    final province = location['province']?.toString();
    final district = location['district']?.toString();
    final ward = location['ward']?.toString();
    final line1 = location['line1']?.toString();
    final line2 = location['line2']?.toString();

    if (country != null && country.isNotEmpty) {
      widgets.add(_buildInfoRow(
        context,
        icon: Icons.public,
        label: 'Quốc gia',
        value: country,
      ));
    }

    if (province != null && province.isNotEmpty) {
      widgets.add(const Divider(height: 24));
      widgets.add(_buildInfoRow(
        context,
        icon: Icons.location_city,
        label: 'Tỉnh/Thành phố',
        value: province,
      ));
    }

    if (district != null && district.isNotEmpty) {
      widgets.add(const Divider(height: 24));
      widgets.add(_buildInfoRow(
        context,
        icon: Icons.location_on,
        label: 'Quận/Huyện',
        value: district,
      ));
    }

    if (ward != null && ward.isNotEmpty) {
      widgets.add(const Divider(height: 24));
      widgets.add(_buildInfoRow(
        context,
        icon: Icons.place,
        label: 'Phường/Xã',
        value: ward,
      ));
    }

    if (line1 != null && line1.isNotEmpty) {
      widgets.add(const Divider(height: 24));
      widgets.add(_buildInfoRow(
        context,
        icon: Icons.home,
        label: 'Địa chỉ',
        value: line1,
      ));
    }

    if (line2 != null && line2.isNotEmpty) {
      widgets.add(const Divider(height: 24));
      widgets.add(_buildInfoRow(
        context,
        icon: Icons.directions,
        label: 'Địa chỉ phụ',
        value: line2,
      ));
    }

    return widgets;
  }

  Widget _buildItemInfo(BuildContext context, BookingItem item, int index) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  '$index',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.itemName ?? item.itemType ?? 'Sản phẩm',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  if (item.itemId != null && item.itemId!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'ID: ${item.itemId}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                  if (item.itemType != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Loại: ${item.itemType}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                  if (item.quantity > 1) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Số lượng: ${item.quantity}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (item.unitPrice > 0) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatCurrency(item.unitPrice),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  if (item.quantity > 1) ...[
                    const SizedBox(height: 2),
                    Text(
                      'x ${item.quantity}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatCurrency(item.unitPrice * item.quantity),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ],
    );
  }

  Color _getStatusColor(int status) {
    switch (status) {
      case 0:
        return Colors.orange; // Chờ xử lý
      case 1:
        return Colors.green; // Đã xác nhận
      case 2:
        return Colors.blue; // Đang thuê
      case 3:
        return Colors.purple; // Đã trả
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

  String _formatDateTime(DateTime date) {
    return '${_formatDate(date)} ${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
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
}
