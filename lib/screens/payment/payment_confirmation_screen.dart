import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import 'payment_success_screen.dart';
import 'payment_failure_screen.dart';

class PaymentConfirmationScreen extends StatefulWidget {
  final String? bookingId;
  final String? paymentId;
  final double? totalAmount;
  final double? depositAmount;

  const PaymentConfirmationScreen({
    super.key,
    this.bookingId,
    this.paymentId,
    this.totalAmount,
    this.depositAmount,
  });

  @override
  State<PaymentConfirmationScreen> createState() => _PaymentConfirmationScreenState();
}

class _PaymentConfirmationScreenState extends State<PaymentConfirmationScreen> {
  bool _isChecking = false;
  String? _errorMessage;

  Future<void> _checkPaymentStatus() async {
    if (widget.paymentId == null || widget.paymentId!.isEmpty) {
      setState(() {
        _errorMessage = 'Không tìm thấy mã thanh toán';
      });
      return;
    }

    setState(() {
      _isChecking = true;
      _errorMessage = null;
    });

    try {
      // Call API to get payment status
      final statusData = await ApiService.getPaymentStatus(
        paymentId: widget.paymentId!,
      );

      if (!mounted) return;

      final isPaid = statusData['isPaid'] == true;
      final paymentStatus = statusData['paymentStatus']?.toString().toLowerCase() ?? '';
      final bookingId = statusData['bookingId']?.toString() ?? widget.bookingId;

      debugPrint('PaymentConfirmationScreen: Payment status retrieved');
      debugPrint('PaymentConfirmationScreen: isPaid: $isPaid, paymentStatus: $paymentStatus');

      // Determine success or failure based on payment status
      if (isPaid ||
          paymentStatus == 'paid' ||
          paymentStatus == 'completed' ||
          paymentStatus == 'success') {
        // Navigate to success screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => PaymentSuccessScreen(
              bookingId: bookingId,
              paymentId: widget.paymentId,
              totalAmount: widget.totalAmount,
              depositAmount: widget.depositAmount,
            ),
          ),
        );
      } else if (paymentStatus == 'cancelled' ||
                 paymentStatus == 'failed' ||
                 paymentStatus == 'cancel') {
        // Navigate to failure screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => PaymentFailureScreen(
              bookingId: bookingId,
              paymentId: widget.paymentId,
              errorMessage: 'Thanh toán đã bị hủy hoặc thất bại.',
            ),
          ),
        );
      } else {
        // Status is pending or unknown
        setState(() {
          _isChecking = false;
          _errorMessage = 'Thanh toán đang được xử lý. Vui lòng thử lại sau.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isChecking = false;
        _errorMessage = 'Không thể kiểm tra trạng thái thanh toán: ${e.toString().replaceFirst('Exception: ', '')}';
      });
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
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Xác nhận thanh toán',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Vui lòng hoàn tất thanh toán trên trình duyệt',
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
                      // Icon
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.payment,
                          size: 80,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Đang chờ xác nhận thanh toán',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          'Vui lòng hoàn tất thanh toán trên trình duyệt web. Sau khi thanh toán xong, nhấn nút "Tiếp tục" bên dưới để kiểm tra trạng thái.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Info Card
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
                                  Icons.info_outline,
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
                            ],
                          ],
                        ),
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.red.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: Colors.red,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.red,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // Bottom Button
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
                  child: ElevatedButton.icon(
                    onPressed: _isChecking ? null : _checkPaymentStatus,
                    icon: _isChecking
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_circle),
                    label: Text(
                      _isChecking ? 'Đang kiểm tra...' : 'Tiếp tục',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
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

