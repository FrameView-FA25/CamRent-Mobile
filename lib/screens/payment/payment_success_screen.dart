import 'package:flutter/material.dart';
import '../booking/booking_list_screen.dart';
import '../../services/api_service.dart';

class PaymentSuccessScreen extends StatefulWidget {
  final String? bookingId;
  final String? paymentId;
  final double? totalAmount;
  final double? depositAmount;

  const PaymentSuccessScreen({
    super.key,
    this.bookingId,
    this.paymentId,
    this.totalAmount,
    this.depositAmount,
  });

  @override
  State<PaymentSuccessScreen> createState() => _PaymentSuccessScreenState();
}

class _PaymentSuccessScreenState extends State<PaymentSuccessScreen> {
  double? _baseTotal;
  double _platformFeePercent = 10.0; // default
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _initBookingTotals();
  }

  Future<void> _initBookingTotals() async {
    if (widget.bookingId == null || widget.bookingId!.isEmpty) {
      setState(() {
        _baseTotal = widget.totalAmount;
      });
      return;
    }
    setState(() {
      _loading = true;
    });
    try {
      final booking = await ApiService.getBookingById(widget.bookingId!);
      final snapshotRentalTotalRaw = booking['snapshotRentalTotal'];
      final snapshotPlatformFeePercentRaw = booking['snapshotPlatformFeePercent'];
      final rentalTotal = snapshotRentalTotalRaw is num
          ? snapshotRentalTotalRaw.toDouble()
          : (double.tryParse(snapshotRentalTotalRaw?.toString() ?? '') ?? 0.0);
      final feePercent = snapshotPlatformFeePercentRaw is num
          ? snapshotPlatformFeePercentRaw.toDouble()
          : (double.tryParse(snapshotPlatformFeePercentRaw?.toString() ?? '') ?? _platformFeePercent);

      setState(() {
        _baseTotal = rentalTotal > 0 ? rentalTotal : (widget.totalAmount ?? 0.0);
        _platformFeePercent = feePercent > 0 ? feePercent : 10.0;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _baseTotal = widget.totalAmount;
        _loading = false;
      });
    }
  }

  String _formatCurrency(double? value) {
    if (value == null || value <= 0) return '0 VNĐ';
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
    final baseTotal = _baseTotal ?? widget.totalAmount ?? 0.0;
    final platformFee = baseTotal * (_platformFeePercent / 100);
    final remainingAmount = baseTotal - platformFee;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFFFF6600).withOpacity(0.25),
              const Color(0xFFFF6600).withOpacity(0.2),
              const Color(0xFF00A651).withOpacity(0.15),
              const Color(0xFF0066CC).withOpacity(0.1),
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
                        Navigator.popUntil(context, (route) => route.isFirst);
                      },
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Thanh toán thành công',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Cảm ơn bạn đã sử dụng dịch vụ',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Success Icon
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
                        'Thanh toán thành công!',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Đơn hàng của bạn đã được xác nhận và đang được xử lý',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      // Payment Info Card
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
                                  'Thông tin thanh toán',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            if (widget.bookingId != null) ...[
                              _buildInfoRow(
                                'Mã đơn hàng',
                                widget.bookingId!,
                                Icons.tag,
                              ),
                              const Divider(),
                            ],
                            if (widget.paymentId != null) ...[
                              _buildInfoRow(
                                'Mã thanh toán',
                                widget.paymentId!,
                                Icons.payment,
                              ),
                              const Divider(),
                            ],
                            if (_loading)
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(12),
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            else
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Tổng giá thuê',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                      ),
                                      Flexible(
                                        child: Text(
                                          _formatCurrency(baseTotal),
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          textAlign: TextAlign.end,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Phí nền tảng (${_platformFeePercent.toStringAsFixed(0)}%)',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      Flexible(
                                        child: Text(
                                          _formatCurrency(platformFee),
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Theme.of(context).colorScheme.primary,
                                          ),
                                          textAlign: TextAlign.end,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Phần thanh toán nhận thiết bị',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                      ),
                                      Flexible(
                                        child: Text(
                                          _formatCurrency(remainingAmount),
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          textAlign: TextAlign.end,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            if (widget.depositAmount != null && widget.depositAmount! > 0) ...[
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Đặt cọc',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  ),
                                  Flexible(
                                    child: Text(
                                      _formatCurrency(widget.depositAmount),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      textAlign: TextAlign.end,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Info Box
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
              // Bottom Buttons
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
                            backgroundColor: Theme.of(context).colorScheme.primary,
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

