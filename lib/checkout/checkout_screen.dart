import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/booking_cart_item.dart';
import '../services/api_service.dart';
import '../screens/contract/contract_signing_screen.dart';
import '../screens/payment/payment_screen.dart';
import '../utils/vietnam_provinces.dart';

// Validation result class
class _ValidationResult {
  final bool hasConflict;
  final String message;
  final String? cameraName;
  final DateTime? existingPickupDate;
  final DateTime? existingReturnDate;

  _ValidationResult({
    required this.hasConflict,
    required this.message,
    this.cameraName,
    this.existingPickupDate,
    this.existingReturnDate,
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
  String? _selectedProvince;
  bool _isSubmitting = false;
  bool _isLoadingProfile = true;
  String? _dateConflictMessage;
  // Map: itemId -> List of date ranges (pickupAt, returnAt)
  Map<String, List<Map<String, DateTime>>> _bookedDateRanges = {};

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadAllBookings();
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

  // Tính toán số tiền thanh toán dựa trên công thức mới
  Map<String, double> _getCalculationDetails() {
    try {
      // Kiểm tra có đủ thông tin không
      if (widget.cartItems.isEmpty || _pickupDate == null || _returnDate == null) {
        return {
          'baseTotal': widget.totalAmount,
          'platformFee': 0.0,
          'platformFeePercent': 0.0,
          'paymentAmount': widget.depositAmount > 0 ? widget.depositAmount : widget.totalAmount,
          'remainingAmount': 0.0,
        };
      }

      // Tính số ngày thuê
      final rentalDays = _returnDate!.difference(_pickupDate!).inDays;
      if (rentalDays <= 0) {
        return {
          'baseTotal': widget.totalAmount,
          'platformFee': 0.0,
          'platformFeePercent': 0.0,
          'paymentAmount': widget.depositAmount > 0 ? widget.depositAmount : widget.totalAmount,
          'remainingAmount': 0.0,
        };
      }

      // Tính tổng giá thuê cơ bản từ tất cả items
      double baseTotal = 0.0;
      double platformFeePercent = 0.0;

      for (final item in widget.cartItems) {
        // Lấy platformFeePercent từ raw data hoặc mặc định 10%
        double itemPlatformFeePercent = 10.0; // Mặc định 10%
        
        // Thử lấy từ raw data
        if (item.raw['camera'] is Map<String, dynamic>) {
          final camera = item.raw['camera'] as Map<String, dynamic>;
          final feePercent = camera['platformFeePercent'] ?? 
                            camera['platform_fee_percent'] ?? 
                            camera['feePercent'] ?? 
                            camera['fee_percent'];
          if (feePercent != null) {
            itemPlatformFeePercent = (feePercent is num ? feePercent.toDouble() : double.tryParse(feePercent.toString()) ?? 10.0);
          }
        } else if (item.raw['platformFeePercent'] != null) {
          final feePercent = item.raw['platformFeePercent'];
          itemPlatformFeePercent = (feePercent is num ? feePercent.toDouble() : double.tryParse(feePercent.toString()) ?? 20.0);
        }

        // Tính baseTotal cho item này
        final itemBaseTotal = rentalDays * item.pricePerDay * item.quantity;
        baseTotal += itemBaseTotal;

        // Lấy platformFeePercent từ item đầu tiên (giả sử tất cả items có cùng %)
        if (platformFeePercent == 0.0) {
          platformFeePercent = itemPlatformFeePercent;
        }
      }

      // Tính phí nền tảng và số tiền thanh toán
      final platformFee = baseTotal * (platformFeePercent / 100);
      final remainingAmount = baseTotal - platformFee;
      final paymentAmount = platformFee; // Số tiền thanh toán = phí nền tảng

      return {
        'baseTotal': baseTotal,
        'platformFee': platformFee,
        'platformFeePercent': platformFeePercent,
        'paymentAmount': paymentAmount,
        'remainingAmount': remainingAmount,
      };
    } catch (e) {
      debugPrint('CheckoutScreen: Error calculating payment details: $e');
      return {
        'baseTotal': widget.totalAmount,
        'platformFee': 0.0,
        'platformFeePercent': 0.0,
        'paymentAmount': widget.depositAmount > 0 ? widget.depositAmount : widget.totalAmount,
        'remainingAmount': 0.0,
      };
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Chưa chọn';
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  Future<void> _selectDate({required bool isPickup}) async {
    try {
      // Normalize dates to start of day for consistent comparison
      normalizeDate(DateTime date) => DateTime(date.year, date.month, date.day);
      
      final now = normalizeDate(DateTime.now());
      final lastDate = normalizeDate(DateTime.now().add(const Duration(days: 365)));
      
      // Calculate initial date and first date
      DateTime initial;
      DateTime firstDate;
      
      if (isPickup) {
        // For pickup date: can select from today onwards
        initial = _pickupDate != null ? normalizeDate(_pickupDate!) : now;
        firstDate = now;
      } else {
        // For return date: must be after pickup date (or tomorrow if no pickup date)
        if (_pickupDate != null) {
          final pickupNormalized = normalizeDate(_pickupDate!);
          firstDate = normalizeDate(pickupNormalized.add(const Duration(days: 1)));
          initial = _returnDate != null 
              ? normalizeDate(_returnDate!) 
              : firstDate;
        } else {
          // No pickup date selected yet, default to tomorrow
          firstDate = normalizeDate(now.add(const Duration(days: 1)));
          initial = _returnDate != null 
              ? normalizeDate(_returnDate!) 
              : firstDate;
        }
      }
      
      // Ensure firstDate <= lastDate
      if (firstDate.isAfter(lastDate)) {
        debugPrint('CheckoutScreen: firstDate ($firstDate) is after lastDate ($lastDate), adjusting...');
        firstDate = lastDate;
      }
      
      // Ensure initialDate is within valid range
      if (initial.isBefore(firstDate)) {
        debugPrint('CheckoutScreen: initial ($initial) is before firstDate ($firstDate), adjusting...');
        initial = firstDate;
      } else if (initial.isAfter(lastDate)) {
        debugPrint('CheckoutScreen: initial ($initial) is after lastDate ($lastDate), adjusting...');
        initial = lastDate;
      }
      
      // CRITICAL: Ensure initialDate satisfies selectableDayPredicate
      // If the initial date is booked, find the next available date
      if (_isDateBooked(initial)) {
        debugPrint('CheckoutScreen: initial date ($initial) is booked, finding next available date...');
        DateTime? nextAvailable;
        for (var i = 0; i <= 365; i++) {
          final candidate = normalizeDate(firstDate.add(Duration(days: i)));
          if (candidate.isAfter(lastDate)) break;
          if (!_isDateBooked(candidate)) {
            nextAvailable = candidate;
            break;
          }
        }
        if (nextAvailable != null) {
          initial = nextAvailable;
          debugPrint('CheckoutScreen: Found next available date: $initial');
        } else {
          // If no available date found, use firstDate (even if it's booked, we'll handle it in the predicate)
          initial = firstDate;
          debugPrint('CheckoutScreen: No available date found, using firstDate: $initial');
        }
      }
      
      debugPrint('CheckoutScreen: Opening date picker - isPickup: $isPickup, firstDate: $firstDate, initial: $initial, lastDate: $lastDate');
      
      // Final validation: ensure initial date is selectable
      final isInitialSelectable = !_isDateBooked(initial);
      if (!isInitialSelectable) {
        debugPrint('CheckoutScreen: WARNING - initial date ($initial) is still not selectable!');
        // Try to find any selectable date in the range
        for (var i = 0; i <= 365; i++) {
          final candidate = normalizeDate(firstDate.add(Duration(days: i)));
          if (candidate.isAfter(lastDate)) break;
          if (!_isDateBooked(candidate)) {
            initial = candidate;
            debugPrint('CheckoutScreen: Found selectable date: $initial');
            break;
          }
        }
      }
      
      final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: lastDate,
      selectableDayPredicate: (DateTime date) {
        // Hide/disable dates that are already booked
        // Wrap in try-catch to prevent crashes
        try {
          return !_isDateBooked(date);
        } catch (e) {
          debugPrint('CheckoutScreen: Error in selectableDayPredicate: $e');
          // If there's an error, allow the date to be selected (fail-safe)
          return true;
        }
      },
      helpText: isPickup ? 'Chọn ngày bắt đầu thuê' : 'Chọn ngày kết thúc thuê',
      cancelText: 'Hủy',
      confirmText: 'Chọn',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).colorScheme.primary,
              onPrimary: Colors.white,
              onSurface: Colors.black87,
              // Disable booked dates with a different color
              onSurfaceVariant: Colors.grey[400]!,
            ),
            textTheme: Theme.of(context).textTheme.copyWith(
              bodyLarge: TextStyle(color: Colors.black87),
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked == null) return;
    
    // Normalize picked date to start of day for consistency
    final pickedNormalized = DateTime(picked.year, picked.month, picked.day);
    
    // Double check if the selected date is booked (in case of race condition)
    if (_isDateBooked(pickedNormalized)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ngày này đã được đặt. Vui lòng chọn ngày khác.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    setState(() {
      if (isPickup) {
        _pickupDate = pickedNormalized;
        if (_returnDate != null && _returnDate!.isBefore(pickedNormalized)) {
          _returnDate = null;
        }
      } else {
        _returnDate = pickedNormalized;
      }
      _dateConflictMessage = null;
    });
    } catch (e, stackTrace) {
      debugPrint('CheckoutScreen: Error in _selectDate: $e');
      debugPrint('CheckoutScreen: Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi chọn ngày: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Widget _buildDateCard({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
    required IconData icon,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        debugPrint('CheckoutScreen: Date card tapped - label: $label');
        onTap();
      },
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey[300] ?? Colors.grey),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
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
        
        // Xử lý tỉnh/thành từ profile
        final province = profileData['province'] ?? 
                        profileData['city'] ?? 
                        profileData['provinceName'] ??
                        profileData['cityName'];
        if (province != null && province is String) {
          // Tìm trong danh sách 34 tỉnh thành
          final foundProvince = VietnamProvinces.provinces.firstWhere(
            (p) => p.toLowerCase().contains(province.toLowerCase()) ||
                   province.toLowerCase().contains(p.toLowerCase()),
            orElse: () => province,
          );
          if (VietnamProvinces.provinces.contains(foundProvince)) {
            _selectedProvince = foundProvince;
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

  Future<void> _loadAllBookings() async {
    try {
      final bookings = await ApiService.getBookings();
      if (!mounted) return;

      // Process bookings to extract date ranges for each item
      final bookedRanges = <String, List<Map<String, DateTime>>>{};

      for (final booking in bookings) {
        if (booking is! Map<String, dynamic>) continue;
        
        final items = booking['items'];
        if (items is! List) continue;
        
        final pickupAtStr = booking['pickupAt']?.toString();
        final returnAtStr = booking['returnAt']?.toString();

        if (pickupAtStr == null || returnAtStr == null) continue;

        DateTime? pickupAt;
        DateTime? returnAt;

        try {
          pickupAt = DateTime.parse(pickupAtStr);
          returnAt = DateTime.parse(returnAtStr);
        } catch (e) {
          debugPrint('CheckoutScreen: Error parsing booking dates: $e');
          continue;
        }

        // Normalize to start of day
        final normalizedPickup = DateTime(pickupAt.year, pickupAt.month, pickupAt.day);
        final normalizedReturn = DateTime(returnAt.year, returnAt.month, returnAt.day);

        // Add date range for each item in this booking
        for (final item in items) {
          if (item is! Map<String, dynamic>) continue;
          
          final itemId = item['itemId']?.toString() ?? 
                        item['cameraId']?.toString() ?? 
                        item['id']?.toString();
          
          if (itemId == null || itemId.isEmpty) continue;

          if (!bookedRanges.containsKey(itemId)) {
            bookedRanges[itemId] = [];
          }

          bookedRanges[itemId]!.add({
            'pickupAt': normalizedPickup,
            'returnAt': normalizedReturn,
          });
        }
      }

      setState(() {
        _bookedDateRanges = bookedRanges;
      });

      debugPrint('CheckoutScreen: Loaded ${bookings.length} bookings');
      debugPrint('CheckoutScreen: Booked date ranges for ${bookedRanges.length} items');
    } catch (e) {
      debugPrint('CheckoutScreen: Error loading bookings: $e');
    }
  }

  /// Check if a date is within any booked date range for the items in cart
  bool _isDateBooked(DateTime date, {String? specificItemId}) {
    try {
      final normalizedDate = DateTime(date.year, date.month, date.day);
      
      // If no booked ranges loaded yet, allow all dates
      if (_bookedDateRanges.isEmpty) {
        return false;
      }
      
      // If specific item ID is provided, only check that item
      final itemsToCheck = specificItemId != null 
          ? [specificItemId]
          : widget.cartItems
              .map((item) => item.cameraId)
              .where((id) => id.isNotEmpty)
              .toList();

      // If no items to check, allow the date
      if (itemsToCheck.isEmpty) {
        return false;
      }

      for (final itemId in itemsToCheck) {
        final ranges = _bookedDateRanges[itemId];
        if (ranges == null || ranges.isEmpty) {
          continue;
        }
        
        for (final range in ranges) {
          final pickupAt = range['pickupAt'];
          final returnAt = range['returnAt'];
          
          // Skip if range data is invalid
          if (pickupAt == null || returnAt == null) {
            continue;
          }
          
          // Check if date is within the booked range (inclusive)
          if (normalizedDate.isAtSameMomentAs(pickupAt) || 
              normalizedDate.isAtSameMomentAs(returnAt) ||
              (normalizedDate.isAfter(pickupAt) && normalizedDate.isBefore(returnAt))) {
            return true;
          }
        }
      }
      
      return false;
    } catch (e) {
      debugPrint('CheckoutScreen: Error in _isDateBooked: $e');
      // If there's an error, allow the date to be selected (fail-safe)
      return false;
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

    if (_selectedProvince == null || _selectedProvince!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn tỉnh/thành phố'),
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
        province: _selectedProvince ?? VietnamProvinces.provinces.first,
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
      debugPrint('CheckoutScreen: Full booking data: $bookingData');
      
      final bookingId = bookingData['id']?.toString() ?? 
                       bookingData['bookingId']?.toString();
      debugPrint('CheckoutScreen: Booking ID: $bookingId');
      debugPrint('CheckoutScreen: Payment ID: ${bookingData['paymentId']}');
      debugPrint('CheckoutScreen: Payment URL: ${bookingData['paymentUrl']}');
      
      // Check booking status
      final status = bookingData['status']?.toString() ?? '';
      final statusText = bookingData['statusText']?.toString() ?? '';
      debugPrint('CheckoutScreen: Booking status: $status');
      debugPrint('CheckoutScreen: Booking statusText: $statusText');

      // Extract contractId from booking data
      String? contractId;
      
      // Try to get contractId from various possible locations
      if (bookingData.containsKey('contractId')) {
        contractId = bookingData['contractId']?.toString();
        debugPrint('CheckoutScreen: Found contractId in bookingData: $contractId');
      } else if (bookingData.containsKey('contract')) {
        final contract = bookingData['contract'];
        if (contract is Map<String, dynamic>) {
          contractId = contract['id']?.toString();
          debugPrint('CheckoutScreen: Found contractId in contract object: $contractId');
        }
      } else if (bookingData.containsKey('contracts')) {
        final contracts = bookingData['contracts'];
        debugPrint('CheckoutScreen: Contracts field type: ${contracts.runtimeType}');
        if (contracts is List) {
          debugPrint('CheckoutScreen: Contracts array length: ${contracts.length}');
          if (contracts.isNotEmpty) {
            final firstContract = contracts.first;
            if (firstContract is Map<String, dynamic>) {
              contractId = firstContract['id']?.toString();
              debugPrint('CheckoutScreen: Found contractId in contracts array: $contractId');
            }
          } else {
            debugPrint('CheckoutScreen: Contracts array is empty');
          }
        }
      }
      
      debugPrint('CheckoutScreen: Final contractId: $contractId');

      // Điều hướng dựa trên contract và status
      // Nếu có contractId, đi đến màn hình ký hợp đồng
      if (contractId != null && contractId.isNotEmpty) {
        debugPrint('CheckoutScreen: Navigating to ContractSigningScreen with contractId: $contractId');
        
        // Ensure bookingId is explicitly set in bookingData (not contractId)
        // This prevents PaymentScreen from accidentally using contractId
        if (bookingId != null && bookingId.isNotEmpty) {
          bookingData['id'] = bookingId;
          bookingData['bookingId'] = bookingId;
          debugPrint('CheckoutScreen: Set bookingId in bookingData: $bookingId');
        }
        
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
        // Nếu không có contractId, đi đến payment
        // Điều này xảy ra khi booking ở trạng thái "PendingApproval" và cần thanh toán trước
        debugPrint('CheckoutScreen: No contractId found, navigating to PaymentScreen');
        debugPrint('CheckoutScreen: Booking status indicates payment is needed first');
        
        // Ensure bookingId is in bookingData for PaymentScreen
        if (bookingId != null && bookingId.isNotEmpty) {
          bookingData['id'] = bookingId;
          bookingData['bookingId'] = bookingId;
        }
        
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

  // Validate booking dates against existing bookings using loaded bookings data
  Future<_ValidationResult> _validateBookingDates({
    required DateTime pickupDate,
    required DateTime returnDate,
    required List<BookingCartItem> cartItems,
  }) async {
    // Normalize dates to start of day for comparison
    final normalizedPickup = DateTime(pickupDate.year, pickupDate.month, pickupDate.day);
    final normalizedReturn = DateTime(returnDate.year, returnDate.month, returnDate.day);

    // Check each item in cart
    for (final cartItem in cartItems) {
      final itemId = cartItem.cameraId;
      if (itemId.isEmpty) continue;

      // Get booked date ranges for this item
      final ranges = _bookedDateRanges[itemId] ?? [];

      for (final range in ranges) {
        final bookedPickup = range['pickupAt']!;
        final bookedReturn = range['returnAt']!;

        // Check if new booking overlaps with existing booking
        // Overlap occurs if:
        // - new pickup is before or equal to booked return AND
        // - new return is after or equal to booked pickup
        if (normalizedPickup.isBefore(bookedReturn.add(const Duration(days: 1))) &&
            normalizedReturn.isAfter(bookedPickup.subtract(const Duration(days: 1)))) {
          return _ValidationResult(
            hasConflict: true,
            message: '${cartItem.cameraName} đã được đặt từ ${_formatDate(bookedPickup)} đến ${_formatDate(bookedReturn)}. Vui lòng chọn ngày khác.',
            cameraName: cartItem.cameraName,
            existingPickupDate: bookedPickup,
            existingReturnDate: bookedReturn,
          );
        }
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

      // Show popup
      final conflictResult = _ValidationResult(
        hasConflict: true,
        message: '$cameraName đã được đặt từ ${_formatDate(conflictPickup)} đến ${_formatDate(conflictReturn)}. Vui lòng chọn ngày khác.',
        cameraName: cameraName,
        existingPickupDate: conflictPickup,
        existingReturnDate: conflictReturn,
      );
      
      if (!mounted) return;
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
              Text(
                conflictResult.message,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.blue.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 20,
                      color: Colors.blue[700],
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Vui lòng chọn ngày khác để tiếp tục đặt lịch.',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Đã hiểu'),
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
                              // Thông tin khách hàng - Modern UI
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.08),
                                      blurRadius: 20,
                                      offset: const Offset(0, 8),
                                      spreadRadius: 0,
                                    ),
                                  ],
                                  border: Border.all(
                                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                    width: 1,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Header với icon và gradient
                                    Container(
                                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                            Theme.of(context).colorScheme.primary.withOpacity(0.05),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Icon(
                                              Icons.person_outline_rounded,
                                              color: Theme.of(context).colorScheme.primary,
                                              size: 24,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            'Renter Information',
                                            style: GoogleFonts.inter(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    // Name field
                                    TextFormField(
                                      controller: _nameController,
                                      style: GoogleFonts.inter(),
                                      decoration: InputDecoration(
                                        labelText: 'Họ và tên *',
                                        labelStyle: GoogleFonts.inter(
                                          color: Colors.grey[600],
                                        ),
                                        prefixIcon: Icon(
                                          Icons.person_outline_rounded,
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide(
                                            color: Colors.grey[300]!,
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide(
                                            color: Colors.grey[300]!,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide(
                                            color: Theme.of(context).colorScheme.primary,
                                            width: 2,
                                          ),
                                        ),
                                        filled: true,
                                        fillColor: Colors.grey[50],
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                      ),
                                      validator: (value) {
                                        if (value == null || value.trim().isEmpty) {
                                          return 'Vui lòng nhập họ và tên';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 16),
                                    // Phone field
                                    TextFormField(
                                      controller: _phoneController,
                                      style: GoogleFonts.inter(),
                                      decoration: InputDecoration(
                                        labelText: 'Số điện thoại *',
                                        labelStyle: GoogleFonts.inter(
                                          color: Colors.grey[600],
                                        ),
                                        prefixIcon: Icon(
                                          Icons.phone_outlined,
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                        hintText: '0901234567',
                                        hintStyle: GoogleFonts.inter(
                                          color: Colors.grey[400],
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide(
                                            color: Colors.grey[300]!,
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide(
                                            color: Colors.grey[300]!,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide(
                                            color: Theme.of(context).colorScheme.primary,
                                            width: 2,
                                          ),
                                        ),
                                        filled: true,
                                        fillColor: Colors.grey[50],
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                      ),
                                      keyboardType: TextInputType.phone,
                                      validator: (value) {
                                        if (value == null || value.trim().isEmpty) {
                                          return 'Vui lòng nhập số điện thoại';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 16),
                                    // Email field
                                    TextFormField(
                                      controller: _emailController,
                                      style: GoogleFonts.inter(),
                                      decoration: InputDecoration(
                                        labelText: 'Email *',
                                        labelStyle: GoogleFonts.inter(
                                          color: Colors.grey[600],
                                        ),
                                        prefixIcon: Icon(
                                          Icons.email_outlined,
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                        hintText: 'example@email.com',
                                        hintStyle: GoogleFonts.inter(
                                          color: Colors.grey[400],
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide(
                                            color: Colors.grey[300]!,
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide(
                                            color: Colors.grey[300]!,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide(
                                            color: Theme.of(context).colorScheme.primary,
                                            width: 2,
                                          ),
                                        ),
                                        filled: true,
                                        fillColor: Colors.grey[50],
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                                    const SizedBox(height: 16),
                                    // Address field
                                    TextFormField(
                                      controller: _addressController,
                                      style: GoogleFonts.inter(),
                                      decoration: InputDecoration(
                                        labelText: 'Địa chỉ (quận/huyện) *',
                                        labelStyle: GoogleFonts.inter(
                                          color: Colors.grey[600],
                                        ),
                                        prefixIcon: Icon(
                                          Icons.location_on_outlined,
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide(
                                            color: Colors.grey[300]!,
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide(
                                            color: Colors.grey[300]!,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide(
                                            color: Theme.of(context).colorScheme.primary,
                                            width: 2,
                                          ),
                                        ),
                                        filled: true,
                                        fillColor: Colors.grey[50],
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                      ),
                                      maxLines: 2,
                                      validator: (value) {
                                        if (value == null || value.trim().isEmpty) {
                                          return 'Vui lòng nhập địa chỉ';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 16),
                                    // Province dropdown - Optimized for large list
                                    DropdownButtonFormField<String>(
                                      value: _selectedProvince,
                                      style: GoogleFonts.inter(
                                        fontSize: 15,
                                        color: Colors.black87,
                                      ),
                                      decoration: InputDecoration(
                                        labelText: 'Tỉnh/Thành phố *',
                                        hintText: 'Chọn tỉnh/thành phố',
                                        hintStyle: GoogleFonts.inter(
                                          color: Colors.grey[400],
                                          fontSize: 15,
                                        ),
                                        labelStyle: GoogleFonts.inter(
                                          color: Colors.grey[600],
                                          fontSize: 14,
                                        ),
                                        prefixIcon: Icon(
                                          Icons.location_city_outlined,
                                          color: Theme.of(context).colorScheme.primary,
                                          size: 22,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide(
                                            color: Colors.grey[300]!,
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide(
                                            color: Colors.grey[300]!,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide(
                                            color: Theme.of(context).colorScheme.primary,
                                            width: 2,
                                          ),
                                        ),
                                        filled: true,
                                        fillColor: Colors.grey[50],
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                      ),
                                      menuMaxHeight: 350, // Limit dropdown height
                                      isExpanded: true, // Allow text to expand
                                      isDense: false,
                                      iconSize: 24,
                                      selectedItemBuilder: (BuildContext context) {
                                        return VietnamProvinces.provinces.map<Widget>((String province) {
                                          return Text(
                                            province,
                                            style: GoogleFonts.inter(
                                              fontSize: 15,
                                              color: Colors.black87,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          );
                                        }).toList();
                                      },
                                      items: VietnamProvinces.provinces.map((province) {
                                        return DropdownMenuItem<String>(
                                          value: province,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(vertical: 4),
                                            child: Text(
                                              province,
                                              style: GoogleFonts.inter(
                                                fontSize: 14,
                                                color: Colors.black87,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (value) {
                                        if (value != null) {
                                          setState(() {
                                            _selectedProvince = value;
                                          });
                                        }
                                      },
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Vui lòng chọn tỉnh/thành phố';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 16),
                                    // Notes field
                                    TextFormField(
                                      controller: _notesController,
                                      style: GoogleFonts.inter(),
                                      decoration: InputDecoration(
                                        labelText: 'Ghi chú',
                                        labelStyle: GoogleFonts.inter(
                                          color: Colors.grey[600],
                                        ),
                                        prefixIcon: Icon(
                                          Icons.note_outlined,
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide(
                                            color: Colors.grey[300]!,
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide(
                                            color: Colors.grey[300]!,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide(
                                            color: Theme.of(context).colorScheme.primary,
                                            width: 2,
                                          ),
                                        ),
                                        filled: true,
                                        fillColor: Colors.grey[50],
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                                onTap: () {
                                  debugPrint('CheckoutScreen: Pickup date card tapped');
                                  _selectDate(isPickup: true);
                                },
                                icon: Icons.calendar_today,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildDateCard(
                                label: 'Ngày kết thúc',
                                date: _returnDate,
                                onTap: () {
                                  debugPrint('CheckoutScreen: Return date card tapped');
                                  _selectDate(isPickup: false);
                                },
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
                              // Hiển thị chi tiết số tiền thanh toán
                              Builder(
                                builder: (context) {
                                  final details = _getCalculationDetails();
                                  final baseTotal = details['baseTotal'] ?? 0.0;
                                  final platformFeePercent = details['platformFeePercent'] ?? 0.0;
                                  final paymentAmount = details['paymentAmount'] ?? 0.0;
                                  final remainingAmount = details['remainingAmount'] ?? 0.0;

                                  // Nếu có đủ thông tin (có dates), hiển thị chi tiết
                                  if (_pickupDate != null && _returnDate != null && baseTotal > 0) {
                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Tổng giá thuê
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'Tổng giá thuê',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey[700],
                                              ),
                                            ),
                                            Text(
                                              _formatCurrency(baseTotal),
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        // Phí nền tảng (số tiền thanh toán)
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              platformFeePercent > 0
                                                  ? 'Phí cọc đặt lịch (${platformFeePercent.toStringAsFixed(0)}%)'
                                                  : 'Phí nền tảng (số tiền thanh toán)',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey[700],
                                              ),
                                            ),
                                            Text(
                                              _formatCurrency(paymentAmount),
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Theme.of(context).colorScheme.primary,
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (remainingAmount > 0) ...[
                                          const SizedBox(height: 8),
                                          // Phần còn lại (
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                'Phần thanh toán còn lại',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.grey[700],
                                                ),
                                              ),
                                              Text(
                                                _formatCurrency(remainingAmount),
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    );
                                  } else {
                                    // Fallback: hiển thị như cũ nếu chưa có dates
                                    return Column(
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                                color: Theme.of(context).colorScheme.primary,
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (widget.depositAmount > 0) ...[
                                          const SizedBox(height: 8),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                    );
                                  }
                                },
                              ),
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


