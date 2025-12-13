import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../services/api_service.dart';
import 'staff_booking_detail_screen.dart';

class StaffQrScannerScreen extends StatefulWidget {
  const StaffQrScannerScreen({super.key});

  @override
  State<StaffQrScannerScreen> createState() => _StaffQrScannerScreenState();
}

class _StaffQrScannerScreenState extends State<StaffQrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _isProcessing = false;
  String? _lastScannedCode;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleBarcode(BarcodeCapture barcodeCapture) async {
    if (_isProcessing) return;

    final barcodes = barcodeCapture.barcodes;
    if (barcodes.isEmpty) return;

    final barcode = barcodes.first;
    final code = barcode.rawValue;

    if (code == null || code.isEmpty) return;
    if (code == _lastScannedCode) return; // Prevent duplicate scans

    setState(() {
      _isProcessing = true;
      _lastScannedCode = code;
    });

    debugPrint('StaffQrScannerScreen: Scanned QR code: $code');

    try {
      // Extract booking ID from QR code format: "booking:xxx" or just "xxx"
      String bookingId = code;
      if (code.startsWith('booking:')) {
        bookingId = code.substring('booking:'.length);
        debugPrint('StaffQrScannerScreen: Extracted booking ID: $bookingId');
      }
      
      // Get booking by ID from QR code
      final bookingData = await ApiService.getBookingByQr(bookingId);
      
      debugPrint('StaffQrScannerScreen: Booking data received: ${bookingData.keys.toList()}');

      if (mounted) {
        // Navigate to booking detail screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => StaffBookingDetailScreen(
              bookingData: bookingData,
              bookingId: bookingId,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('StaffQrScannerScreen: Error getting booking: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: ${e.toString().replaceFirst('Exception: ', '')}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          // Reset last scanned code after a delay to allow re-scanning
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              setState(() {
                _lastScannedCode = null;
              });
            }
          });
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: const Text(
          'Scan QR Code',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Camera preview
          MobileScanner(
            controller: _controller,
            onDetect: _handleBarcode,
          ),
          
          // Gradient overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.3),
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withOpacity(0.6),
                  ],
                  stops: const [0.0, 0.2, 0.7, 1.0],
                ),
              ),
            ),
          ),
          
          // Scanning frame with modern design
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Stack(
                    children: [
                      // Animated scanning line
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _ScanningFramePainter(),
                        ),
                      ),
                      // Corner indicators with modern design
                      _buildCornerIndicator(Alignment.topLeft),
                      _buildCornerIndicator(Alignment.topRight),
                      _buildCornerIndicator(Alignment.bottomLeft),
                      _buildCornerIndicator(Alignment.bottomRight),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                // Instructions card
                Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).padding.bottom + 80,
                  ),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 32),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.qr_code_scanner_rounded,
                            color: Theme.of(context).colorScheme.primary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Text(
                          'Position QR code',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Processing indicator with modern design
          if (_isProcessing)
            Container(
              color: Colors.black.withOpacity(0.7),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).colorScheme.primary,
                        ),
                        strokeWidth: 3,
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Processing...',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Fetching booking information',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCornerIndicator(Alignment alignment) {
    return Align(
      alignment: alignment,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.transparent,
          border: Border(
            left: BorderSide(
              color: Theme.of(context).colorScheme.primary,
              width: alignment == Alignment.topLeft || alignment == Alignment.bottomLeft ? 4 : 0,
            ),
            right: BorderSide(
              color: Theme.of(context).colorScheme.primary,
              width: alignment == Alignment.topRight || alignment == Alignment.bottomRight ? 4 : 0,
            ),
            top: BorderSide(
              color: Theme.of(context).colorScheme.primary,
              width: alignment == Alignment.topLeft || alignment == Alignment.topRight ? 4 : 0,
            ),
            bottom: BorderSide(
              color: Theme.of(context).colorScheme.primary,
              width: alignment == Alignment.bottomLeft || alignment == Alignment.bottomRight ? 4 : 0,
            ),
          ),
        ),
        child: Stack(
          children: [
            if (alignment == Alignment.topLeft)
              Positioned(
                top: 0,
                left: 0,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                    ),
                  ),
                ),
              ),
            if (alignment == Alignment.topRight)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(24),
                    ),
                  ),
                ),
              ),
            if (alignment == Alignment.bottomLeft)
              Positioned(
                bottom: 0,
                left: 0,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(24),
                    ),
                  ),
                ),
              ),
            if (alignment == Alignment.bottomRight)
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: const BorderRadius.only(
                      bottomRight: Radius.circular(24),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ScanningFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, size.height),
          const Radius.circular(24),
        ),
      );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

