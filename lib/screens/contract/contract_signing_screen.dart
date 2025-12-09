import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../services/api_service.dart';
import '../payment/payment_screen.dart';

class ContractSigningScreen extends StatefulWidget {
  final String contractId;
  final Map<String, dynamic> bookingData;
  final double totalAmount;
  final double depositAmount;

  const ContractSigningScreen({
    super.key,
    required this.contractId,
    required this.bookingData,
    required this.totalAmount,
    required this.depositAmount,
  });

  @override
  State<ContractSigningScreen> createState() => _ContractSigningScreenState();
}

class _ContractSigningScreenState extends State<ContractSigningScreen> {
  bool _isLoadingPdf = true;
  Uint8List? _pdfBytes;
  String? _pdfError;
  bool _isSigning = false;
  bool _isAlreadySigned = false;
  final GlobalKey _signatureKey = GlobalKey();
  WebViewController? _webViewController;

  @override
  void initState() {
    super.initState();
    _loadContractPdf();
  }

  Future<void> _loadContractPdf() async {
    setState(() {
      _isLoadingPdf = true;
      _pdfError = null;
    });

    try {
      // First, check if contract is already signed
      try {
        final contractInfo = await ApiService.getContractInfo(
          contractId: widget.contractId,
        );
        
        // Check if contract is signed
        final isSigned = contractInfo['isSigned'] == true ||
                        contractInfo['signedAt'] != null ||
                        contractInfo['signedFileUrl'] != null ||
                        contractInfo['status']?.toString().toLowerCase() == 'signed';
        
        if (isSigned) {
          _isAlreadySigned = true;
          debugPrint('ContractSigningScreen: Contract is already signed');
        }
      } catch (e) {
        debugPrint('ContractSigningScreen: Could not get contract info, assuming not signed: $e');
        // Continue with preview if we can't get info
      }

      // Load PDF: use signed PDF if already signed, otherwise use preview
      final pdfBytes = _isAlreadySigned
          ? await ApiService.getContractPdf(contractId: widget.contractId)
          : await ApiService.getContractPreview(contractId: widget.contractId);

      if (!mounted) return;

      setState(() {
        _pdfBytes = pdfBytes;
        _isLoadingPdf = false;
      });

      // Initialize WebView controller and load PDF
      if (pdfBytes.isNotEmpty) {
        _webViewController = WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setBackgroundColor(Colors.white)
          ..setNavigationDelegate(
            NavigationDelegate(
              onPageFinished: (String url) {
                debugPrint('ContractSigningScreen: PDF loaded successfully');
              },
              onWebResourceError: (WebResourceError error) {
                debugPrint('ContractSigningScreen: WebView error: ${error.description}');
              },
            ),
          );
        
        // Use base64 data URL for PDF
        final base64Pdf = base64Encode(pdfBytes);
        final dataUrl = 'data:application/pdf;base64,$base64Pdf';
        debugPrint('ContractSigningScreen: Loading PDF with data URL (${pdfBytes.length} bytes)');
        await _webViewController!.loadRequest(Uri.parse(dataUrl));
        
        // Force rebuild to show WebView
        if (mounted) {
          setState(() {});
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _pdfError = e.toString().replaceFirst('Exception: ', '');
        _isLoadingPdf = false;
      });
    }
  }

  Future<void> _handleSignContract() async {
    // Get signature from pad
    final signaturePad = _signatureKey.currentState as SignaturePadState?;
    if (signaturePad == null || signaturePad.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng ký vào ô chữ ký'),
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
        contractId: widget.contractId,
        signatureBase64: signatureBase64,
      );

      if (!mounted) return;

      if (!mounted) return;

      // Mark as signed and reload PDF to show signed version
      setState(() {
        _isAlreadySigned = true;
      });
      
      // Reload PDF to show signed version
      await _loadContractPdf();

      if (!mounted) return;

      // Show success popup
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 28),
              SizedBox(width: 8),
              Text('Ký hợp đồng thành công'),
            ],
          ),
          content: const Text(
            'Bạn đã ký hợp đồng thành công. Vui lòng tiếp tục đến bước thanh toán.',
          ),
          actions: [
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                // Navigate to payment amount screen
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PaymentAmountScreen(
                      bookingData: widget.bookingData,
                      totalAmount: widget.totalAmount,
                      depositAmount: widget.depositAmount,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.arrow_forward, size: 18),
              label: const Text('Tiếp tục'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final errorMsg = e.toString().replaceFirst('Exception: ', '');
      
      // If contract is already signed, navigate to payment screen
      if (errorMsg.toLowerCase().contains('already signed') || 
          errorMsg.toLowerCase().contains('signer already signed')) {
        debugPrint('ContractSigningScreen: Contract already signed, navigating to payment');
        
        // Mark as signed
        setState(() {
          _isAlreadySigned = true;
          _isSigning = false;
        });
        
        // Navigate directly to payment amount screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => PaymentAmountScreen(
              bookingData: widget.bookingData,
              totalAmount: widget.totalAmount,
              depositAmount: widget.depositAmount,
            ),
          ),
        );
        return;
      }
      
      // For other errors, show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi ký hợp đồng: $errorMsg'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSigning = false;
        });
      }
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isAlreadySigned ? 'Xem hợp đồng đã ký' : 'Ký hợp đồng',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Vui lòng đọc và ký hợp đồng',
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
                child: _isLoadingPdf
                    ? const Center(child: CircularProgressIndicator())
                    : _pdfError != null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  size: 64,
                                  color: Colors.red,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Lỗi: $_pdfError',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.red,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: _loadContractPdf,
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Thử lại'),
                                ),
                              ],
                            ),
                          )
                        : SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // PDF Viewer
                                Container(
                                  height: 400,
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
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: _pdfBytes != null && _webViewController != null
                                        ? WebViewWidget(
                                            controller: _webViewController!,
                                          )
                                        : _isLoadingPdf
                                            ? const Center(
                                                child: CircularProgressIndicator(),
                                              )
                                            : Center(
                                                child: Column(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Icon(
                                                      Icons.picture_as_pdf,
                                                      size: 48,
                                                      color: Colors.grey[400],
                                                    ),
                                                    const SizedBox(height: 8),
                                                    Text(
                                                      'Đang tải hợp đồng...',
                                                      style: TextStyle(
                                                        color: Colors.grey[600],
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                  ),
                                ),
                                // Show signature section only if not already signed
                                if (!_isAlreadySigned) ...[
                                  const SizedBox(height: 24),
                                  // Signature Section
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.edit,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary,
                                            ),
                                            const SizedBox(width: 8),
                                            const Text(
                                              'Chữ ký của bạn',
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        Container(
                                          height: 120, // Match BE signature block height
                                          decoration: BoxDecoration(
                                            color: Colors.grey[50],
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: Colors.grey[300]!,
                                              width: 2,
                                            ),
                                          ),
                                          child: SignaturePad(
                                            key: _signatureKey,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            TextButton.icon(
                                              onPressed: () {
                                                (_signatureKey.currentState
                                                        as SignaturePadState?)
                                                    ?.clear();
                                              },
                                              icon: const Icon(Icons.clear),
                                              label: const Text('Xóa'),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ] else ...[
                                  // Show message if already signed
                                  const SizedBox(height: 24),
                                  Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.green.withOpacity(0.3),
                                        width: 1,
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.check_circle,
                                              color: Colors.green,
                                              size: 28,
                                            ),
                                            const SizedBox(width: 12),
                                            const Expanded(
                                              child: Text(
                                                'Hợp đồng đã được ký',
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.green,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        const Text(
                                          'Bạn có thể xem lại hợp đồng đã ký ở trên. Vui lòng tiếp tục đến bước thanh toán.',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 24),
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
                  child: _isAlreadySigned
                      ? ElevatedButton.icon(
                          onPressed: () {
                            // Navigate to payment amount screen if already signed
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PaymentAmountScreen(
                                  bookingData: widget.bookingData,
                                  totalAmount: widget.totalAmount,
                                  depositAmount: widget.depositAmount,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.arrow_forward),
                          label: const Text(
                            'Tiếp tục thanh toán',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        )
                      : ElevatedButton.icon(
                          onPressed: _isSigning ? null : _handleSignContract,
                          icon: _isSigning
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.check),
                          label: Text(
                            _isSigning ? 'Đang ký...' : 'Ký hợp đồng',
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
}

// Payment Amount Screen
class PaymentAmountScreen extends StatelessWidget {
  final Map<String, dynamic> bookingData;
  final double totalAmount;
  final double depositAmount;

  const PaymentAmountScreen({
    super.key,
    required this.bookingData,
    required this.totalAmount,
    required this.depositAmount,
  });

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
                            'Số tiền thanh toán',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Xác nhận số tiền cần thanh toán',
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
                        'Hợp đồng đã được ký',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Payment Amount Card
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
                                  Icons.payment,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Số tiền thanh toán',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Tổng tiền',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  _formatCurrency(totalAmount),
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                            if (depositAmount > 0) ...[
                              const Divider(),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Đặt cọc',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  Text(
                                    _formatCurrency(depositAmount),
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
                      const SizedBox(height: 24),
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
                    onPressed: () {
                      // Navigate to payment screen
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PaymentScreen(
                            bookingData: bookingData,
                            totalAmount: totalAmount,
                            depositAmount: depositAmount,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.payment),
                    label: const Text(
                      'Tiếp tục thanh toán',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
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
}

// Signature Pad Widget (reused from booking_detail_screen)
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

    // Add padding (reduced for smaller signature)
    const padding = 5.0;
    final signatureWidth = maxX - minX;
    final signatureHeight = maxY - minY;

    if (signatureWidth <= 0 || signatureHeight <= 0) {
      throw Exception('Invalid signature bounds');
    }

    // BE signature block: height 120, FitWidth scaling
    // Target: max height 120px, width should fit the signature naturally (FitWidth)
    const maxHeight = 120.0;
    const maxWidth = 250.0; // Smaller max width for signature to match BE
    
    // Calculate scale to fit width (FitWidth like BE), but don't exceed max height
    final widthScale = maxWidth / (signatureWidth + padding * 2);
    final heightScale = maxHeight / (signatureHeight + padding * 2);
    
    // Use FitWidth approach: scale to fit width, but limit height
    double scale = widthScale;
    double finalWidth = (signatureWidth + padding * 2) * scale;
    double finalHeight = (signatureHeight + padding * 2) * scale;
    
    // If height exceeds max, scale down to fit height
    if (finalHeight > maxHeight) {
      scale = heightScale;
      finalWidth = (signatureWidth + padding * 2) * scale;
      finalHeight = (signatureHeight + padding * 2) * scale;
    }
    
    final width = finalWidth.ceil();
    final height = finalHeight.ceil().clamp(1, maxHeight.toInt());

    // Create picture recorder
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2 * scale // Scale stroke width
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Draw signature with scaling
    canvas.translate(-minX * scale + padding * scale, -minY * scale + padding * scale);
    canvas.scale(scale);
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

