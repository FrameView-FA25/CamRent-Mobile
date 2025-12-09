import 'package:flutter/material.dart';
import '../models/booking_cart_item.dart';
import '../services/api_service.dart';
import '../screens/contract/contract_signing_screen.dart';
import '../screens/payment/payment_screen.dart';

// Validation result class
class _ValidationResult {
  final bool hasConflict;
  final String message;
  final String? cameraName;
  final DateTime? existingPickupDate;
  final DateTime? existingReturnDate;
  final DateTime? recommendedPickupDate;
  final DateTime? recommendedReturnDate;

  _ValidationResult({
    required this.hasConflict,
    required this.message,
    this.cameraName,
    this.existingPickupDate,
    this.existingReturnDate,
    this.recommendedPickupDate,
    this.recommendedReturnDate,
  });
}

class CheckoutScreen extends StatefulWidget {
  final List<BookingCartItem> cartItems;
  final double totalAmount;
  final double depositAmount;

  const CheckoutScreen({
    super.key,
    required this.cartItems,
    required this.totalAmount,
    required this.depositAmount,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime? _pickupDate;
  DateTime? _returnDate;
  static const List<String> _provinceOptions = [
    'Hà Nội',
    'Hồ Chí Minh',
    'Đà Nẵng',
    'Hải Phòng',
    'Cần Thơ',
    'Đắk Lắk',
    'Bình Dương',
    'Khánh Hòa',
    'Thanh Hóa',
    'Nghệ An',
  ];
  String _selectedProvince = _provinceOptions.first;
  bool _isSubmitting = false;
  bool _isLoadingProfile = true;
  String? _dateConflictMessage;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
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

  String _formatDate(DateTime? date) {
    if (date == null) return 'Chưa chọn';
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  Future<void> _selectDate({required bool isPickup}) async {
    final now = DateTime.now();
    final initial = isPickup
        ? (_pickupDate ?? now)
        : (_returnDate ?? (_pickupDate?.add(const Duration(days: 1)) ?? now.add(const Duration(days: 1))));
    final firstDate = isPickup ? now : (_pickupDate ?? now.add(const Duration(days: 1)));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      if (isPickup) {
        _pickupDate = picked;
        if (_returnDate != null && _returnDate!.isBefore(picked)) {
          _returnDate = null;
        }
      } else {
        _returnDate = picked;
      }
    });
  }

  Widget _buildDateCard({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
    required IconData icon,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[300] ?? Colors.grey),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
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
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(date),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadProfile() async {
    try {
      final profileData = await ApiService.getProfile();
      if (!mounted) return;
      
      setState(() {
        // Điền thông tin từ profile
        _nameController.text = profileData['fullName'] ?? '';
        _emailController.text = profileData['email'] ?? '';
        _phoneController.text = profileData['phone'] ?? '';
        
        // Xử lý địa chỉ (có thể là object hoặc string)
        final address = profileData['address'];
        if (address != null) {
          if (address is String) {
            _addressController.text = address;
          } else if (address is Map<String, dynamic>) {
            final parts = <String>[];
            if (address['street'] != null) parts.add(address['street']);
            if (address['ward'] != null) parts.add(address['ward']);
            if (address['district'] != null) parts.add(address['district']);
            if (address['city'] != null) parts.add(address['city']);
            _addressController.text = parts.join(', ');
          }
        }
        
        _isLoadingProfile = false;
      });
    } catch (e) {
      // Nếu không load được profile, vẫn cho phép nhập thủ công
      if (!mounted) return;
      setState(() {
        _isLoadingProfile = false;
      });
    }
  }

  Future<void> _handleCheckout() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validate dates
    if (_pickupDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn ngày bắt đầu thuê'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_returnDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn ngày kết thúc thuê'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_returnDate!.isBefore(_pickupDate!) || _returnDate!.isAtSameMomentAs(_pickupDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ngày kết thúc phải sau ngày bắt đầu'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Validate booking dates against existing bookings
    setState(() {
      _isSubmitting = true;
      _dateConflictMessage = null;
    });

    try {
      // Check availability for all items in cart
      final conflictResult = await _validateBookingDates(
        pickupDate: _pickupDate!,
        returnDate: _returnDate!,
        cartItems: widget.cartItems,
      );

      if (conflictResult.hasConflict) {
        if (!mounted) return;
        setState(() {
          _isSubmitting = false;
          _dateConflictMessage = conflictResult.message;
        });
        // Show popup with detailed information and recommendations
        _showConflictDialog(conflictResult);
        return;
      }
    } catch (e) {
      debugPrint('CheckoutScreen: Error validating dates: $e');
      // Continue with booking creation if validation fails (backend will also check)
    }

    try {
      // Tạo booking với payment integration
      final bookingData = await ApiService.createBookingFromCart(
        customerName: _nameController.text.trim(),
        customerPhone: _phoneController.text.trim(),
        customerEmail: _emailController.text.trim(),
        province: _selectedProvince,
        district: _addressController.text.trim(),
        pickupAt: _pickupDate!,
        returnAt: _returnDate!,
        customerAddress: _addressController.text.trim().isEmpty 
            ? null 
            : _addressController.text.trim(),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        createPayment: true,
        paymentAmount: widget.depositAmount > 0
            ? widget.depositAmount
            : widget.totalAmount,
        paymentDescription:
            'Thanh toán đặt cọc cho đơn hàng từ giỏ hàng',
      );

      if (!mounted) return;

      // Log booking data before navigation
      debugPrint('CheckoutScreen: Booking created successfully');
      debugPrint('CheckoutScreen: Booking data keys: ${bookingData.keys.toList()}');
      debugPrint('CheckoutScreen: Booking ID: ${bookingData['id'] ?? bookingData['bookingId']}');
      debugPrint('CheckoutScreen: Payment ID: ${bookingData['paymentId']}');
      debugPrint('CheckoutScreen: Payment URL: ${bookingData['paymentUrl']}');

      // Extract contractId from booking data
      String? contractId;
      
      // Try to get contractId from various possible locations
      if (bookingData.containsKey('contractId')) {
        contractId = bookingData['contractId']?.toString();
      } else if (bookingData.containsKey('contract')) {
        final contract = bookingData['contract'];
        if (contract is Map<String, dynamic>) {
          contractId = contract['id']?.toString();
        }
      } else if (bookingData.containsKey('contracts')) {
        final contracts = bookingData['contracts'];
        if (contracts is List && contracts.isNotEmpty) {
          final firstContract = contracts.first;
          if (firstContract is Map<String, dynamic>) {
            contractId = firstContract['id']?.toString();
          }
        }
      }
      
      debugPrint('CheckoutScreen: Contract ID: $contractId');

      // Điều hướng đến màn hình ký hợp đồng nếu có contractId
      if (contractId != null && contractId.isNotEmpty) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ContractSigningScreen(
              contractId: contractId!,
              bookingData: bookingData,
              totalAmount: widget.totalAmount,
              depositAmount: widget.depositAmount,
            ),
          ),
        );
      } else {
        // Nếu không có contractId, đi thẳng đến payment (fallback)
        debugPrint('CheckoutScreen: No contractId found, going directly to payment');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => PaymentScreen(
              bookingData: bookingData,
              totalAmount: widget.totalAmount,
              depositAmount: widget.depositAmount,
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      final errorMsg = e.toString().replaceFirst('Exception: ', '');
      final isConflict = _isDateConflictError(errorMsg);
      setState(() {
        _isSubmitting = false;
        _dateConflictMessage = isConflict
            ? 'Camera đã được đặt vào khoảng thời gian đã chọn. Vui lòng chọn ngày khác.'
            : null;
      });
      
      // If it's a conflict error, try to parse and show popup
      if (isConflict) {
        await _handleBackendConflictError(errorMsg);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Validate booking dates against existing bookings
  // Logic:
  // 1. Return date của booking trước + 2 ngày delay = earliest pickup date của booking mới
  // 2. Pickup date của booking mới + rental period + 2 ngày delay <= pickup date của booking sau (nếu có)
  // 3. Khoảng cách tối thiểu giữa 2 booking là 7 ngày
  Future<_ValidationResult> _validateBookingDates({
    required DateTime pickupDate,
    required DateTime returnDate,
    required List<BookingCartItem> cartItems,
  }) async {
    const int delayDays = 2; // Delay để nhận máy sau khi trả
    const int minGapDays = 7; // Khoảng cách tối thiểu giữa 2 booking

    // Normalize dates to start of day for comparison
    final normalizedPickup = DateTime(pickupDate.year, pickupDate.month, pickupDate.day);
    final normalizedReturn = DateTime(returnDate.year, returnDate.month, returnDate.day);

    // Check each item in cart
    for (final cartItem in cartItems) {
      final itemId = cartItem.cameraId;
      if (itemId.isEmpty) continue;

      try {
        // Get all existing bookings for this item
        final existingBookings = await ApiService.getItemBookings(itemId);

        for (final booking in existingBookings) {
          final existingPickupStr = booking['pickupAt']?.toString();
          final existingReturnStr = booking['returnAt']?.toString();

          if (existingPickupStr == null || existingReturnStr == null) continue;

          DateTime? existingPickup;
          DateTime? existingReturn;

          try {
            existingPickup = DateTime.parse(existingPickupStr);
            existingReturn = DateTime.parse(existingReturnStr);
          } catch (e) {
            debugPrint('CheckoutScreen: Error parsing booking dates: $e');
            continue;
          }

          // Normalize existing dates
          final normalizedExistingPickup = DateTime(
            existingPickup.year,
            existingPickup.month,
            existingPickup.day,
          );
          final normalizedExistingReturn = DateTime(
            existingReturn.year,
            existingReturn.month,
            existingReturn.day,
          );

          // Check if new booking overlaps with existing booking
          // Direct overlap check
          if (normalizedPickup.isBefore(normalizedExistingReturn.add(Duration(days: delayDays))) &&
              normalizedReturn.isAfter(normalizedExistingPickup.subtract(Duration(days: delayDays)))) {
            // Calculate recommended dates
            final rentalDays = normalizedReturn.difference(normalizedPickup).inDays;
            DateTime? recommendedPickup;
            DateTime? recommendedReturn;
            
            // If new booking is before existing, recommend dates before existing
            if (normalizedReturn.isBefore(normalizedExistingPickup)) {
              recommendedReturn = normalizedExistingPickup.subtract(Duration(days: minGapDays));
              recommendedPickup = recommendedReturn.subtract(Duration(days: rentalDays));
            } else {
              // If new booking is after existing, recommend dates after existing
              recommendedPickup = normalizedExistingReturn.add(Duration(days: minGapDays));
              recommendedReturn = recommendedPickup.add(Duration(days: rentalDays));
            }
            
            return _ValidationResult(
              hasConflict: true,
              message: '${cartItem.cameraName} đã được đặt từ ${_formatDate(existingPickup)} đến ${_formatDate(existingReturn)}.',
              cameraName: cartItem.cameraName,
              existingPickupDate: existingPickup,
              existingReturnDate: existingReturn,
              recommendedPickupDate: recommendedPickup,
              recommendedReturnDate: recommendedReturn,
            );
          }

          // Check minimum gap requirement (7 days)
          // Gap = days between existing return and new pickup
          final gapAfterExisting = normalizedPickup.difference(normalizedExistingReturn).inDays;
          // Gap = days between new return and existing pickup
          final gapBeforeExisting = normalizedExistingPickup.difference(normalizedReturn).inDays;

          // If new booking is after existing booking
          if (normalizedPickup.isAfter(normalizedExistingReturn)) {
            // Need at least delayDays to receive the item + minGapDays gap = minGapDays total
            if (gapAfterExisting < minGapDays) {
              final earliestAvailable = normalizedExistingReturn.add(Duration(days: minGapDays));
              final rentalDays = normalizedReturn.difference(normalizedPickup).inDays;
              final recommendedReturn = earliestAvailable.add(Duration(days: rentalDays));
              return _ValidationResult(
                hasConflict: true,
                message: '${cartItem.cameraName} cần khoảng cách tối thiểu ${minGapDays} ngày sau khi trả (${_formatDate(existingReturn)}). '
                    'Ngày bắt đầu sớm nhất có thể: ${_formatDate(earliestAvailable)}.',
                cameraName: cartItem.cameraName,
                existingPickupDate: existingPickup,
                existingReturnDate: existingReturn,
                recommendedPickupDate: earliestAvailable,
                recommendedReturnDate: recommendedReturn,
              );
            }
          }
          // If new booking is before existing booking
          else if (normalizedReturn.isBefore(normalizedExistingPickup)) {
            // Need at least delayDays after new return + minGapDays gap = minGapDays total
            if (gapBeforeExisting < minGapDays) {
              final latestAvailable = normalizedExistingPickup.subtract(Duration(days: minGapDays));
              final rentalDays = normalizedReturn.difference(normalizedPickup).inDays;
              final recommendedPickup = latestAvailable.subtract(Duration(days: rentalDays));
              return _ValidationResult(
                hasConflict: true,
                message: '${cartItem.cameraName} cần khoảng cách tối thiểu ${minGapDays} ngày trước khi bắt đầu đặt tiếp (${_formatDate(existingPickup)}). '
                    'Ngày kết thúc muộn nhất có thể: ${_formatDate(latestAvailable)}.',
                cameraName: cartItem.cameraName,
                existingPickupDate: existingPickup,
                existingReturnDate: existingReturn,
                recommendedPickupDate: recommendedPickup,
                recommendedReturnDate: latestAvailable,
              );
            }
          }

          // Check if new booking return + delay would conflict with next booking
          final newReturnWithDelay = normalizedReturn.add(Duration(days: delayDays));
          if (newReturnWithDelay.isAfter(normalizedExistingPickup) &&
              normalizedPickup.isBefore(normalizedExistingPickup)) {
            final rentalDays = normalizedReturn.difference(normalizedPickup).inDays;
            final recommendedPickup = normalizedExistingReturn.add(Duration(days: minGapDays));
            final recommendedReturn = recommendedPickup.add(Duration(days: rentalDays));
            return _ValidationResult(
              hasConflict: true,
              message: '${cartItem.cameraName} không thể cho thuê từ ${_formatDate(pickupDate)} đến ${_formatDate(returnDate)} '
                  'vì sau khi trả (${_formatDate(returnDate.add(Duration(days: delayDays)))}) sẽ trùng với booking tiếp theo (${_formatDate(existingPickup)}).',
              cameraName: cartItem.cameraName,
              existingPickupDate: existingPickup,
              existingReturnDate: existingReturn,
              recommendedPickupDate: recommendedPickup,
              recommendedReturnDate: recommendedReturn,
            );
          }
        }
      } catch (e) {
        debugPrint('CheckoutScreen: Error checking availability for ${cartItem.cameraName}: $e');
        // Continue checking other items
      }
    }

    return _ValidationResult(hasConflict: false, message: '');
  }

  bool _isDateConflictError(String message) {
    final lower = message.toLowerCase();
    return lower.contains('đã được đặt') ||
        lower.contains('đã bị đặt') ||
        lower.contains('already booked') ||
        lower.contains('conflict') ||
        lower.contains('trùng') ||
        lower.contains('overlap') ||
        lower.contains('is not available between');
  }

  Future<void> _handleBackendConflictError(String errorMsg) async {
    try {
      // Parse error message: "Item (id: 10c28341-cbf6-4596-9a49-348fce3121ba) is not available between 2026-01-01T10:00:00.0000000Z and 2026-01-02T18:00:00.0000000Z"
      // Also handle: "Booking creation failed: Item (id: ...) is not available between ... and ..."
      final itemIdMatch = RegExp(r'Item\s*\(id:\s*([a-f0-9-]+)\)', caseSensitive: false).firstMatch(errorMsg);
      final betweenMatch = RegExp(r'between\s+([0-9TZ.:-]+)\s+and\s+([0-9TZ.:-]+)', caseSensitive: false).firstMatch(errorMsg);
      
      if (itemIdMatch == null || betweenMatch == null) {
        // Cannot parse, show simple error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lịch đặt đã bị trùng. Vui lòng chọn ngày khác.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final itemId = itemIdMatch.group(1);
      final unavailableStartStr = betweenMatch.group(1);
      final unavailableEndStr = betweenMatch.group(2);

      if (itemId == null || unavailableStartStr == null || unavailableEndStr == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lịch đặt đã bị trùng. Vui lòng chọn ngày khác.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Parse dates
      DateTime? unavailableStart;
      DateTime? unavailableEnd;
      try {
        unavailableStart = DateTime.parse(unavailableStartStr);
        unavailableEnd = DateTime.parse(unavailableEndStr);
      } catch (e) {
        debugPrint('CheckoutScreen: Error parsing dates from error message: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lịch đặt đã bị trùng. Vui lòng chọn ngày khác.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Get item bookings to find the conflicting booking
      List<Map<String, dynamic>> existingBookings;
      String? cameraName;
      
      try {
        existingBookings = await ApiService.getItemBookings(itemId);
        
        // Find camera name from cart items
        for (final cartItem in widget.cartItems) {
          if (cartItem.cameraId == itemId) {
            cameraName = cartItem.cameraName;
            break;
          }
        }
        
        // If not found in cart, try to get from first booking
        if (cameraName == null && existingBookings.isNotEmpty) {
          final firstBooking = existingBookings.first;
          final items = firstBooking['items'];
          if (items is List && items.isNotEmpty) {
            final firstItem = items.first;
            if (firstItem is Map<String, dynamic>) {
              final camera = firstItem['camera'];
              if (camera is Map<String, dynamic>) {
                cameraName = camera['name']?.toString() ?? 'Sản phẩm';
              }
            }
          }
        }
        
        cameraName ??= 'Sản phẩm';
      } catch (e) {
        debugPrint('CheckoutScreen: Error getting item bookings: $e');
        // Show popup with available info even if we can't get bookings
        cameraName = 'Sản phẩm';
        existingBookings = [];
      }

      // Find the booking that overlaps with unavailable dates
      DateTime? existingPickup;
      DateTime? existingReturn;
      
      for (final booking in existingBookings) {
        final bookingPickupStr = booking['pickupAt']?.toString();
        final bookingReturnStr = booking['returnAt']?.toString();
        
        if (bookingPickupStr == null || bookingReturnStr == null) continue;
        
        try {
          final bookingPickup = DateTime.parse(bookingPickupStr);
          final bookingReturn = DateTime.parse(bookingReturnStr);
          
          // Check if this booking overlaps with unavailable period
          if (bookingPickup.isBefore(unavailableEnd) && bookingReturn.isAfter(unavailableStart)) {
            existingPickup = bookingPickup;
            existingReturn = bookingReturn;
            break;
          }
        } catch (e) {
          continue;
        }
      }

      // If we found a booking, use its dates, otherwise use unavailable dates
      final conflictPickup = existingPickup ?? unavailableStart;
      final conflictReturn = existingReturn ?? unavailableEnd;

      // Calculate recommended dates
      const int minGapDays = 7;
      final rentalDays = _returnDate != null && _pickupDate != null
          ? _returnDate!.difference(_pickupDate!).inDays
          : 1;
      
      DateTime? recommendedPickup;
      DateTime? recommendedReturn;
      
      // Recommend dates after the conflict
      recommendedPickup = conflictReturn.add(Duration(days: minGapDays));
      recommendedReturn = recommendedPickup.add(Duration(days: rentalDays));

      // Show popup
      final conflictResult = _ValidationResult(
        hasConflict: true,
        message: '$cameraName đã được đặt từ ${_formatDate(conflictPickup)} đến ${_formatDate(conflictReturn)}.',
        cameraName: cameraName,
        existingPickupDate: conflictPickup,
        existingReturnDate: conflictReturn,
        recommendedPickupDate: recommendedPickup,
        recommendedReturnDate: recommendedReturn,
      );
      
      _showConflictDialog(conflictResult);
    } catch (e) {
      debugPrint('CheckoutScreen: Error handling backend conflict: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lịch đặt đã bị trùng. Vui lòng chọn ngày khác.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _showConflictDialog(_ValidationResult conflictResult) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Colors.orange[700],
              size: 28,
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Lịch đặt đã có',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (conflictResult.cameraName != null) ...[
                Text(
                  'Sản phẩm: ${conflictResult.cameraName}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (conflictResult.existingPickupDate != null &&
                  conflictResult.existingReturnDate != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.orange.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 20,
                        color: Colors.orange[700],
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Đã được đặt từ ${_formatDate(conflictResult.existingPickupDate)} đến ${_formatDate(conflictResult.existingReturnDate)}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.orange[900],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (conflictResult.recommendedPickupDate != null &&
                  conflictResult.recommendedReturnDate != null) ...[
                const Text(
                  'Khuyến nghị chọn ngày:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.green.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 20,
                        color: Colors.green[700],
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Từ ${_formatDate(conflictResult.recommendedPickupDate)} đến ${_formatDate(conflictResult.recommendedReturnDate)}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.green[900],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Text(
                  conflictResult.message,
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Đóng'),
          ),
          if (conflictResult.recommendedPickupDate != null &&
              conflictResult.recommendedReturnDate != null)
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  _pickupDate = conflictResult.recommendedPickupDate;
                  _returnDate = conflictResult.recommendedReturnDate;
                  _dateConflictMessage = null;
                });
              },
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Chọn ngày này'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
        ],
      ),
    );
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
                            'Tạo đặt lịch',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Điền thông tin để hoàn tất đặt lịch',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Form và danh sách sản phẩm
              Expanded(
                child: _isLoadingProfile
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Thông tin khách hàng
                              Container(
                          padding: const EdgeInsets.all(16),
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
                                    Icons.person_outline,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Thông tin khách hàng',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _nameController,
                                decoration: const InputDecoration(
                                  labelText: 'Họ và tên *',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.person),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Vui lòng nhập họ và tên';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _phoneController,
                                decoration: const InputDecoration(
                                  labelText: 'Số điện thoại *',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.phone),
                                ),
                                keyboardType: TextInputType.phone,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Vui lòng nhập số điện thoại';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _emailController,
                                decoration: const InputDecoration(
                                  labelText: 'Email *',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.email),
                                ),
                                keyboardType: TextInputType.emailAddress,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Vui lòng nhập email';
                                  }
                                  if (!value.contains('@')) {
                                    return 'Email không hợp lệ';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _addressController,
                                decoration: const InputDecoration(
                                  labelText: 'Địa chỉ (quận/huyện) *',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.location_on),
                                ),
                                maxLines: 2,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Vui lòng nhập địa chỉ';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _notesController,
                                decoration: const InputDecoration(
                                  labelText: 'Ghi chú',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.note),
                                ),
                                maxLines: 3,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Ngày thuê',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildDateCard(
                                label: 'Ngày bắt đầu',
                                date: _pickupDate,
                                onTap: () => _selectDate(isPickup: true),
                                icon: Icons.calendar_today,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildDateCard(
                                label: 'Ngày kết thúc',
                                date: _returnDate,
                                onTap: () => _selectDate(isPickup: false),
                                icon: Icons.event,
                              ),
                            ),
                          ],
                        ),
                        if (_dateConflictMessage != null) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 18,
                                color: Theme.of(context).colorScheme.error,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _dateConflictMessage!,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Theme.of(context).colorScheme.error,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 16),
                        Text(
                          'Tỉnh/Thành *',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _selectedProvince,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          items: _provinceOptions
                              .map(
                                (province) => DropdownMenuItem(
                                  value: province,
                                  child: Text(province),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _selectedProvince = value;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        // Danh sách sản phẩm
                        Container(
                          padding: const EdgeInsets.all(16),
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
                                    Icons.shopping_cart,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Đơn hàng của bạn',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              ...widget.cartItems.map((item) => Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[50],
                                      borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                        color: Colors.grey[200] ?? Colors.grey,
                                      ),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: 60,
                                          height: 60,
                                          decoration: BoxDecoration(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary
                                                .withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Icon(
                                            (item.type ?? BookingItemType.camera) ==
                                                    BookingItemType.accessory
                                                ? Icons.memory
                                                : Icons.camera_alt,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item.cameraName,
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '${_formatDate(item.startDate)} → ${_formatDate(item.endDate)}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                              if (item.quantity > 1) ...[
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Số lượng: ${item.quantity}',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey[600],
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        Text(
                                          _formatCurrency(item.totalPrice),
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )),
                              const Divider(),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Tổng cộng',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    _formatCurrency(widget.totalAmount),
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
                              if (widget.depositAmount > 0) ...[
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Đặt cọc dự kiến',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                    Text(
                                      _formatCurrency(widget.depositAmount),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 100), // Space for button
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
            onPressed: _isSubmitting ? null : _handleCheckout,
            icon: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.calendar_month),
            label: Text(
              _isSubmitting ? 'Đang xử lý...' : 'Tạo đặt lịch',
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
    );
  }
}

