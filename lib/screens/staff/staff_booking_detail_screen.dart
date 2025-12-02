import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../models/booking_model.dart';
import '../../services/api_service.dart';
import '../../models/booking_status_model.dart';

class StaffBookingDetailScreen extends StatefulWidget {
  final Map<String, dynamic> bookingData;
  final String bookingId;

  const StaffBookingDetailScreen({
    super.key,
    required this.bookingData,
    required this.bookingId,
  });

  @override
  State<StaffBookingDetailScreen> createState() => _StaffBookingDetailScreenState();
}

class _StaffBookingDetailScreenState extends State<StaffBookingDetailScreen> {
  bool _isLoading = false;
  bool? _isConfirm;
  String? _selectedStatus;
  List<BookingStatusModel> _statuses = [];
  BookingModel? _booking;

  @override
  void initState() {
    super.initState();
    _loadBookingData();
    _loadStatuses();
  }

  Future<void> _loadBookingData() async {
    try {
      final booking = BookingModel.fromJson(widget.bookingData);
      setState(() {
        _booking = booking;
        // Get isConfirm from booking data
        _isConfirm = widget.bookingData['isConfirm'] as bool?;
      });
    } catch (e) {
      debugPrint('Error parsing booking data: $e');
    }
  }

  Future<void> _loadStatuses() async {
    try {
      final statusesData = await ApiService.getBookingStatuses();
      setState(() {
        _statuses = statusesData.map((s) => BookingStatusModel.fromJson(s)).toList();
        // Set current status if available
        if (_booking != null && _booking!.statusText != null) {
          _selectedStatus = _statuses.firstWhere(
            (s) => s.status == _booking!.statusText || s.statusText == _booking!.statusText,
            orElse: () => _statuses.first,
          ).status;
        }
      });
    } catch (e) {
      debugPrint('Error loading booking statuses: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi tải danh sách trạng thái: ${e.toString().replaceFirst('Exception: ', '')}'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _updateStatus() async {
    if (_isLoading) return;
    if (_isConfirm == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn trạng thái xác nhận sản phẩm'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await ApiService.updateBookingStatus(
        bookingId: widget.bookingId,
        isConfirm: _isConfirm!,
        status: _selectedStatus,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cập nhật trạng thái thành công'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Reload booking data
        final updatedBooking = await ApiService.getBookingByQr(widget.bookingId);
        setState(() {
          _booking = BookingModel.fromJson(updatedBooking);
          _isConfirm = updatedBooking['isConfirm'] as bool?;
        });
      }
    } catch (e) {
      debugPrint('Error updating booking status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi cập nhật: ${e.toString().replaceFirst('Exception: ', '')}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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

  @override
  Widget build(BuildContext context) {
    if (_booking == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Chi tiết đặt lịch'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final booking = _booking!;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 18),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: const Text(
          'Booking Details',
          style: TextStyle(
            fontSize: 22,
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
              onPressed: () async {
                setState(() {
                  _isLoading = true;
                });
                try {
                  final updatedBooking = await ApiService.getBookingByQr(widget.bookingId);
                  setState(() {
                    _booking = BookingModel.fromJson(updatedBooking);
                    _isConfirm = updatedBooking['isConfirm'] as bool?;
                  });
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Lỗi tải lại: ${e.toString().replaceFirst('Exception: ', '')}'),
                        backgroundColor: Colors.red,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    );
                  }
                } finally {
                  if (mounted) {
                    setState(() {
                      _isLoading = false;
                    });
                  }
                }
              },
            ),
          ),
        ],
      ),
      body: _isLoading && _booking == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Booking ID Card with modern design
                  _buildModernCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Theme.of(context).colorScheme.primary,
                                    Theme.of(context).colorScheme.primary.withOpacity(0.7),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.receipt_long_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Booking ID',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black54,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          booking.id,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Status Card
                  _buildModernCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.info_outline_rounded,
                                color: Colors.blue,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Status',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (_statuses.isNotEmpty)
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey[200]!),
                            ),
                            child: DropdownButtonFormField<String>(
                              value: _selectedStatus ?? _statuses.first.status,
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                              ),
                              dropdownColor: Colors.white,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                              items: _statuses.map((status) {
                                return DropdownMenuItem<String>(
                                  value: status.status,
                                  child: Text(status.displayText),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedStatus = value;
                                });
                              },
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              booking.statusString,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Customer Info
                  _buildModernCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader(
                          icon: Icons.person_outline_rounded,
                          title: 'Customer Information',
                          iconColor: Colors.purple,
                        ),
                        const SizedBox(height: 20),
                        _buildModernInfoRow(
                          icon: Icons.person,
                          label: 'Name',
                          value: booking.customerName,
                        ),
                        const SizedBox(height: 16),
                        _buildModernInfoRow(
                          icon: Icons.phone_outlined,
                          label: 'Phone',
                          value: booking.customerPhone,
                        ),
                        const SizedBox(height: 16),
                        _buildModernInfoRow(
                          icon: Icons.email_outlined,
                          label: 'Email',
                          value: booking.customerEmail,
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Booking Dates
                  _buildModernCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader(
                          icon: Icons.calendar_today_outlined,
                          title: 'Rental Period',
                          iconColor: Colors.orange,
                        ),
                        const SizedBox(height: 20),
                        _buildModernInfoRow(
                          icon: Icons.arrow_downward_rounded,
                          label: 'Pickup Date',
                          value: _formatDate(booking.pickupAt),
                        ),
                        const SizedBox(height: 16),
                        _buildModernInfoRow(
                          icon: Icons.arrow_upward_rounded,
                          label: 'Return Date',
                          value: _formatDate(booking.returnAt),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Items
                  _buildModernCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader(
                          icon: Icons.inventory_2_outlined,
                          title: 'Items',
                          iconColor: Colors.blue,
                        ),
                        const SizedBox(height: 20),
                        if (booking.items.isEmpty)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.inbox_outlined,
                                    size: 48,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No items',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          ...booking.items.asMap().entries.map((entry) {
                            final index = entry.key;
                            final item = entry.value;
                            return Container(
                              margin: EdgeInsets.only(bottom: index < booking.items.length - 1 ? 12 : 0),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.grey[200]!),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt_outlined,
                                      color: Colors.blue,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.itemName ?? 'Product',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          item.itemType ?? '',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '${item.quantity}x',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      Text(
                                        _formatCurrency(item.unitPrice),
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Pricing
                  _buildModernCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader(
                          icon: Icons.payments_outlined,
                          title: 'Payment Information',
                          iconColor: Colors.green,
                        ),
                        const SizedBox(height: 20),
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
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              Text(
                                _formatCurrency(booking.snapshotRentalTotal),
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildModernInfoRow(
                          icon: Icons.security_outlined,
                          label: 'Deposit',
                          value: _formatCurrency(booking.snapshotDepositAmount),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Product Confirmation
                  _buildModernCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader(
                          icon: Icons.verified_outlined,
                          title: 'Product Inspection',
                          iconColor: Colors.teal,
                        ),
                        const SizedBox(height: 20),
                        _buildModernRadioOption(
                          value: true,
                          groupValue: _isConfirm,
                          title: 'Approved',
                          subtitle: 'Product is in good condition',
                          icon: Icons.check_circle_outline,
                          color: Colors.green,
                          onChanged: (value) {
                            setState(() {
                              _isConfirm = value;
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        _buildModernRadioOption(
                          value: false,
                          groupValue: _isConfirm,
                          title: 'Rejected',
                          subtitle: 'Product needs attention',
                          icon: Icons.cancel_outlined,
                          color: Colors.red,
                          onChanged: (value) {
                            setState(() {
                              _isConfirm = value;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Update Button with modern design
                  Container(
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.primary,
                          Theme.of(context).colorScheme.primary.withOpacity(0.8),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _updateStatus,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.check_circle_outline, size: 24),
                      label: Text(
                        _isLoading ? 'Updating...' : 'Update Status',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }

  Widget _buildModernCard({required Widget child}) {
    return Container(
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
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: child,
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required Color iconColor,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: iconColor,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildModernInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 18,
            color: Colors.grey[700],
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
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[600],
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value.isEmpty ? 'N/A' : value,
                style: const TextStyle(
                  fontSize: 16,
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

  Widget _buildModernRadioOption({
    required bool? value,
    required bool? groupValue,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required ValueChanged<bool?> onChanged,
  }) {
    final isSelected = value == groupValue;
    return InkWell(
      onTap: () => onChanged(value),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.grey[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected ? color.withOpacity(0.2) : Colors.grey[200],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: isSelected ? color : Colors.grey[600],
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? color : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Radio<bool?>(
              value: value,
              groupValue: groupValue,
              onChanged: onChanged,
              activeColor: color,
            ),
          ],
        ),
      ),
    );
  }

}

