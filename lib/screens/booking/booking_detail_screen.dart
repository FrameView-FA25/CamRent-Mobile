import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
  bool _isLoadingQr = false;
  Uint8List? _qrImageBytes;
  String? _qrPayload;
  String? _qrError;
  bool _isSigning = false;
  final GlobalKey _signatureKey = GlobalKey();

  BookingModel get booking => widget.booking;
  
  // Get contract info
  Map<String, dynamic>? get _contract {
    final contracts = booking.raw['contracts'];
    if (contracts is List && contracts.isNotEmpty) {
      return contracts.first as Map<String, dynamic>?;
    }
    return null;
  }
  
  // Get renter signature
  Map<String, dynamic>? get _renterSignature {
    final contract = _contract;
    if (contract == null) return null;
    
    final signatures = contract['signatures'];
    if (signatures is List) {
      for (final sig in signatures) {
        if (sig is Map<String, dynamic> && sig['role'] == 'Renter') {
          return sig;
        }
      }
    }
    return null;
  }
  
  bool get _isSigned => _renterSignature?['isSigned'] == true;
  String? get _contractId => _contract?['id']?.toString();
  
  @override
  void initState() {
    super.initState();
    _loadQrCode();
  }
  
  Future<void> _loadQrCode() async {
    if (!mounted) return;
    
    setState(() {
      _isLoadingQr = true;
      _qrError = null;
    });

    try {
      final qrData = await ApiService.getBookingQrCode(booking.id).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Kết nối quá lâu. Vui lòng thử lại');
        },
      );

      if (!mounted) return;

      final pngImageBase64 = qrData['pngImage'] as String?;
      final payload = qrData['payload'] as String?;

      if (pngImageBase64 != null && pngImageBase64.isNotEmpty) {
        // Decode base64 to bytes
        final imageBytes = base64Decode(pngImageBase64);
        setState(() {
          _qrImageBytes = imageBytes;
          _qrPayload = payload;
          _isLoadingQr = false;
        });
      } else {
        setState(() {
          _qrError = 'Không nhận được hình ảnh QR code';
          _isLoadingQr = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading QR code: $e');
      if (!mounted) return;
      setState(() {
        _qrError = e.toString().replaceFirst('Exception: ', '');
        _isLoadingQr = false;
      });
    }
  }

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

      final paymentResult = await ApiService.initializePayOSPayment(
        paymentId: paymentId,
        amount: amount,
        description: description,
        returnUrl: returnUrl,
        cancelUrl: cancelUrl,
      );

      // Extract redirectUrl from Map response
      final paymentUrl = paymentResult['redirectUrl']?.toString() ?? '';
      final returnedPaymentId = paymentResult['paymentId']?.toString();

      debugPrint('PayOS payment URL: $paymentUrl');
      debugPrint('PayOS payment ID: $returnedPaymentId');

      if (!mounted) return;

      if (paymentUrl.isEmpty) {
        throw Exception('Không nhận được URL thanh toán từ server');
      }

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

  Future<void> _handleSignContract() async {
    if (_contractId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không tìm thấy hợp đồng'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Get signature from pad
    final signaturePad = _signatureKey.currentState as SignaturePadState?;
    if (signaturePad == null || signaturePad.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng ký chữ ký trước'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSigning = true;
    });

    try {
      // Convert signature to base64
      final signatureBytes = await signaturePad.toImageBytes();
      final signatureBase64 = base64Encode(signatureBytes);

      // Call API to sign
      await ApiService.signContract(
        contractId: _contractId!,
        signatureBase64: signatureBase64,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ký hợp đồng thành công'),
          backgroundColor: Colors.green,
        ),
      );

      // Reload booking to get updated signature status
      setState(() {
        _isSigning = false;
      });

      // Optionally reload the booking detail
      Navigator.pop(context, true);
    } catch (e) {
      debugPrint('Error signing contract: $e');
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi ký hợp đồng: ${e.toString().replaceFirst('Exception: ', '')}'),
          backgroundColor: Colors.red,
        ),
      );

      setState(() {
        _isSigning = false;
      });
    }
  }

  String _formatDateTime(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  bool get _canPay => 
      booking.status == 0 || // PendingApproval
      (booking.snapshotRentalTotal > 0 || booking.snapshotDepositAmount > 0);

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(booking.status);

    return Scaffold(
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        title: const Text(
          'Chi tiết đặt lịch',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFFFF6600).withOpacity(0.95), // Cam - chủ đạo
                const Color(0xFFFF6600).withOpacity(0.85), // Cam - tiếp tục
                const Color(0xFF00A651).withOpacity(0.7), // Xanh lá - nhẹ
                const Color(0xFF0066CC).withOpacity(0.6), // Xanh dương - rất nhẹ
              ],
              stops: const [0.0, 0.5, 0.75, 1.0],
            ),
          ),
        ),
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.25),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              // Màu cam chủ đạo nhiều hơn
              const Color(0xFFFF6600).withOpacity(0.25), // Cam - chủ đạo
              const Color(0xFFFF6600).withOpacity(0.2), // Cam - tiếp tục
              const Color(0xFF00A651).withOpacity(0.15), // Xanh lá - nhẹ
              const Color(0xFF0066CC).withOpacity(0.1), // Xanh dương - rất nhẹ
            ],
            stops: const [0.0, 0.4, 0.7, 1.0],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Elegant Header Card với màu nhẹ nhàng
                Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.98),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 25,
                        offset: const Offset(0, 8),
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white,
                            Colors.white.withOpacity(0.95),
                          ],
                        ),
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF6600).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFFF6600).withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: Icon(
                              Icons.receipt_long_rounded,
                              color: const Color(0xFFFF6600),
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Chi tiết đặt lịch',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[900],
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.tag,
                                      size: 14,
                                      color: Colors.grey[500],
                                    ),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        booking.id.length >= 12 
                                            ? '${booking.id.substring(0, 12)}...' 
                                            : booking.id,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                          fontFamily: 'monospace',
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  statusColor.withOpacity(0.12),
                                  statusColor.withOpacity(0.08),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: statusColor.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              booking.statusString,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: statusColor,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
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
                        value: booking.pickupAt != null && booking.returnAt != null
                            ? '${booking.returnAt!.difference(booking.pickupAt!).inDays + 1} ngày'
                            : 'Chưa xác định',
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
                                // platformFeePercent từ API đã là phần trăm (ví dụ: 20), không cần nhân 100
                                value: '${platformFeePercent.toStringAsFixed(0)}%',
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

            // QR Code Card
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
                    Row(
                      children: [
                        Icon(
                          Icons.qr_code,
                          color: Theme.of(context).colorScheme.primary,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Mã QR đặt lịch',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_isLoadingQr)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Column(
                            children: [
                              const CircularProgressIndicator(),
                              const SizedBox(height: 16),
                              Text(
                                'Đang tải mã QR...',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else if (_qrError != null)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Column(
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 48,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _qrError!,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              TextButton.icon(
                                onPressed: _loadQrCode,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Thử lại'),
                              ),
                            ],
                          ),
                        ),
                      )
                    else if (_qrImageBytes != null)
                      Center(
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.grey[300]!,
                                  width: 1,
                                ),
                              ),
                              child: Image.memory(
                                _qrImageBytes!,
                                width: 200,
                                height: 200,
                                fit: BoxFit.contain,
                              ),
                            ),
                            if (_qrPayload != null) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _qrPayload!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontFamily: 'monospace',
                                    color: Colors.grey[700],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                            Text(
                              'Cho staff quét để xác nhận đặt lịch',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Text(
                            'Không có mã QR',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Contract Signature Card
            if (_contract != null) ...[
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
                      Row(
                        children: [
                          Icon(
                            Icons.edit_note,
                            color: Theme.of(context).colorScheme.primary,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Chữ ký hợp đồng',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (_isSigned)
                        // Đã ký
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.green[200]!,
                              width: 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    color: Colors.green[700],
                                    size: 24,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Đã ký',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green[700],
                                    ),
                                  ),
                                ],
                              ),
                              if (_renterSignature?['signedAt'] != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Ngày ký: ${_formatDateTime(DateTime.parse(_renterSignature!['signedAt'].toString()))}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        )
                      else
                        // Chưa ký - hiển thị signature pad
                        Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.orange[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.orange[200]!,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.warning_amber_rounded,
                                    color: Colors.orange[700],
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Chưa ký hợp đồng',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.orange[700],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Signature pad
                            Container(
                              height: 200,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.grey[300]!,
                                  width: 1,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: SignaturePad(
                                  key: _signatureKey,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      // Clear signature
                                      (_signatureKey.currentState as SignaturePadState?)?.clear();
                                    },
                                    icon: const Icon(Icons.clear),
                                    label: const Text('Xóa'),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 2,
                                  child: ElevatedButton.icon(
                                    onPressed: _isSigning ? null : _handleSignContract,
                                    icon: _isSigning
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                            ),
                                          )
                                        : const Icon(Icons.edit),
                                    label: Text(_isSigning ? 'Đang ký...' : 'Ký hợp đồng'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Theme.of(context).colorScheme.primary,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
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
              const SizedBox(height: 16),
            ],

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

// Signature Pad Widget
class SignaturePad extends StatefulWidget {
  const SignaturePad({super.key});

  @override
  State<SignaturePad> createState() => SignaturePadState();
}

class SignaturePadState extends State<SignaturePad> {
  final List<Offset> _points = [];

  bool get isEmpty => _points.isEmpty;

  void clear() {
    setState(() {
      _points.clear();
    });
  }

  Future<Uint8List> toImageBytes() async {
    if (_points.isEmpty) {
      throw Exception('Signature is empty');
    }

    // Find bounds
    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;

    for (final point in _points) {
      if (point == Offset.zero) continue;
      minX = point.dx < minX ? point.dx : minX;
      minY = point.dy < minY ? point.dy : minY;
      maxX = point.dx > maxX ? point.dx : maxX;
      maxY = point.dy > maxY ? point.dy : maxY;
    }

    // Add padding
    const padding = 20.0;
    final width = (maxX - minX + padding * 2).ceil();
    final height = (maxY - minY + padding * 2).ceil();

    if (width <= 0 || height <= 0) {
      throw Exception('Invalid signature bounds');
    }

    // Create picture recorder
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Draw signature
    canvas.translate(-minX + padding, -minY + padding);
    for (int i = 0; i < _points.length - 1; i++) {
      if (_points[i] != Offset.zero && _points[i + 1] != Offset.zero) {
        canvas.drawLine(_points[i], _points[i + 1], paint);
      }
    }

    // Convert to image
    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    
    if (byteData == null) {
      throw Exception('Failed to convert signature to image');
    }

    return byteData.buffer.asUint8List();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (event) {
        setState(() {
          _points.add(event.localPosition);
        });
      },
      onPointerMove: (event) {
        setState(() {
          _points.add(event.localPosition);
        });
      },
      onPointerUp: (event) {
        setState(() {
          _points.add(Offset.zero); // Mark end of stroke
        });
      },
      child: CustomPaint(
        painter: SignaturePainter(_points),
        size: Size.infinite,
      ),
    );
  }
}

class SignaturePainter extends CustomPainter {
  final List<Offset> points;

  SignaturePainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != Offset.zero && points[i + 1] != Offset.zero) {
        canvas.drawLine(points[i], points[i + 1], paint);
      }
    }
  }

  @override
  bool shouldRepaint(SignaturePainter oldDelegate) {
    return oldDelegate.points != points;
  }
}
