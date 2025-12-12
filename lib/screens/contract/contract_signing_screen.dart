import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
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
  String? _tempPdfPath;
  final PdfViewerController _pdfViewerController = PdfViewerController();

  /// Ensure bookingId is correctly set in bookingData (not contractId)
  Map<String, dynamic> _ensureBookingIdInData(Map<String, dynamic> data) {
    final updated = Map<String, dynamic>.from(data);
    
    // Extract bookingId from data
    final bookingId = data['id']?.toString() ?? 
                     data['bookingId']?.toString();
    
    // Check if 'id' might be a contractId by checking contracts array
    if (data.containsKey('contracts') && data['contracts'] is List) {
      final contracts = data['contracts'] as List;
      for (final contract in contracts) {
        if (contract is Map<String, dynamic>) {
          final contractId = contract['id']?.toString();
          // If current 'id' matches a contractId, we need to find the real bookingId
          if (contractId != null && data['id']?.toString() == contractId) {
            // This means 'id' is actually a contractId, not bookingId
            // Try to find bookingId from other sources
            debugPrint('ContractSigningScreen: WARNING - id field contains contractId, searching for bookingId');
            break;
          }
        }
      }
    }
    
    // Ensure bookingId is set correctly
    if (bookingId != null && bookingId.isNotEmpty) {
      updated['id'] = bookingId;
      updated['bookingId'] = bookingId;
      debugPrint('ContractSigningScreen: Set bookingId in data: $bookingId');
    } else {
      debugPrint('ContractSigningScreen: WARNING - No bookingId found in data');
    }
    
    return updated;
  }

  @override
  void initState() {
    super.initState();
    _loadContractPdf();
  }

  @override
  void dispose() {
    _pdfViewerController.dispose();
    super.dispose();
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

      // Save PDF to temporary file for PDF viewer
      final tempDir = await getTemporaryDirectory();
      final fileName = 'contract_${widget.contractId}.pdf';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(pdfBytes);
      
      // Verify file was written
      final fileExists = await file.exists();
      final fileSize = fileExists ? await file.length() : 0;
      debugPrint('ContractSigningScreen: PDF file saved: ${file.path}');
      debugPrint('ContractSigningScreen: File exists: $fileExists, Size: $fileSize bytes');

      if (!mounted) return;

      setState(() {
        _pdfBytes = pdfBytes;
        _tempPdfPath = file.path;
        _isLoadingPdf = false;
      });

      debugPrint('ContractSigningScreen: PDF loaded successfully (${pdfBytes.length} bytes)');
    } catch (e) {
      if (!mounted) return;
      final errorMessage = e.toString().replaceFirst('Exception: ', '');
      debugPrint('ContractSigningScreen: Error loading PDF: $errorMessage');
      setState(() {
        // Cải thiện error message
        if (errorMessage.isEmpty || errorMessage == 'Error' || errorMessage.toLowerCase() == 'error') {
          _pdfError = 'Không thể tải file PDF. Vui lòng kiểm tra kết nối và thử lại.';
        } else {
          _pdfError = errorMessage;
        }
        _isLoadingPdf = false;
      });
    }
  }

  Future<void> _openPdfInExternalApp() async {
    if (_pdfBytes == null || _pdfBytes!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không có file PDF để mở'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // Get temporary directory
      final tempDir = await getTemporaryDirectory();
      final fileName = 'contract_${widget.contractId}.pdf';
      final file = File('${tempDir.path}/$fileName');

      // Write PDF bytes to file
      await file.writeAsBytes(_pdfBytes!);
      debugPrint('ContractSigningScreen: PDF saved to ${file.path}');

      // Open file with external app using open_file (handles FileProvider automatically)
      try {
        final result = await OpenFile.open(file.path);
        debugPrint('ContractSigningScreen: PDF opened successfully. Result: $result');
        
        if (result.type != ResultType.done) {
          String errorMessage = 'Không thể mở file PDF';
          if (result.type == ResultType.noAppToOpen) {
            errorMessage = 'Không tìm thấy ứng dụng đọc PDF. Vui lòng cài đặt ứng dụng đọc PDF.';
          } else if (result.type == ResultType.fileNotFound) {
            errorMessage = 'Không tìm thấy file PDF';
          } else if (result.type == ResultType.permissionDenied) {
            errorMessage = 'Không có quyền mở file PDF';
          } else if (result.message.isNotEmpty) {
            errorMessage = result.message;
          }
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(errorMessage),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        }
      } catch (openError) {
        debugPrint('ContractSigningScreen: Error opening file: $openError');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi khi mở PDF: ${openError.toString().replaceFirst('Exception: ', '')}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('ContractSigningScreen: Error opening PDF: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi mở PDF: ${e.toString().replaceFirst('Exception: ', '')}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
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
        barrierDismissible: true, // Allow dismissing by tapping outside
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 28),
              SizedBox(width: 8),
              Text('Ký hợp đồng'),
            ],
            
          ),
          content: const Text(
            'Bạn đã ký hợp đồng thành công. Vui lòng tiếp tục đến bước thanh toán.',
          ),
          actions: [
            TextButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                // Stay on current screen to view PDF
              },
              icon: const Icon(Icons.picture_as_pdf, size: 18),
              label: const Text('Xem PDF'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.blue,
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                // Ensure bookingId is correctly set before navigation
                final updatedBookingData = _ensureBookingIdInData(widget.bookingData);
                // Navigate to payment amount screen
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PaymentAmountScreen(
                      bookingData: updatedBookingData,
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
        
        // Ensure bookingId is correctly set before navigation
        final updatedBookingData = _ensureBookingIdInData(widget.bookingData);
        
        // Navigate directly to payment amount screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => PaymentAmountScreen(
              bookingData: updatedBookingData,
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
                    : Column(
                            children: [
                              // PDF Viewer - Sử dụng Expanded để tự điều chỉnh
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Container(
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
                                      child: _pdfError != null
                                          ? Center(
                                              child: Padding(
                                                padding: const EdgeInsets.all(16),
                                                child: Column(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    const Icon(
                                                      Icons.error_outline,
                                                      size: 48,
                                                      color: Colors.red,
                                                    ),
                                                    const SizedBox(height: 8),
                                                    Text(
                                                      _pdfError!,
                                                      style: const TextStyle(
                                                        color: Colors.red,
                                                        fontSize: 14,
                                                      ),
                                                      textAlign: TextAlign.center,
                                                    ),
                                                    const SizedBox(height: 16),
                                                    ElevatedButton.icon(
                                                      onPressed: _loadContractPdf,
                                                      icon: const Icon(Icons.refresh),
                                                      label: const Text('Thử lại'),
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor: Colors.orange,
                                                        foregroundColor: Colors.white,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            )
                                          : _tempPdfPath != null
                                                  ? FutureBuilder<bool>(
                                                      future: File(_tempPdfPath!).exists(),
                                                      builder: (context, snapshot) {
                                                        if (snapshot.connectionState == ConnectionState.waiting) {
                                                          return const Center(child: CircularProgressIndicator());
                                                        }
                                                        
                                                        if (snapshot.hasError || !(snapshot.data ?? false)) {
                                                          return Center(
                                                            child: Padding(
                                                              padding: const EdgeInsets.all(16),
                                                              child: Column(
                                                                mainAxisAlignment: MainAxisAlignment.center,
                                                                children: [
                                                                  const Icon(
                                                                    Icons.error_outline,
                                                                    size: 48,
                                                                    color: Colors.red,
                                                                  ),
                                                                  const SizedBox(height: 8),
                                                                  const Text(
                                                                    'Không tìm thấy file PDF',
                                                                    style: TextStyle(
                                                                      color: Colors.red,
                                                                      fontSize: 14,
                                                                    ),
                                                                    textAlign: TextAlign.center,
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          );
                                                        }
                                                        
                                                        return SfPdfViewer.file(
                                                          File(_tempPdfPath!),
                                                          controller: _pdfViewerController,
                                                          enableDoubleTapZooming: true,
                                                          enableTextSelection: false,
                                                          onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
                                                            debugPrint('ContractSigningScreen: PDF load failed: ${details.error}');
                                                            if (mounted) {
                                                              final errorMsg = details.error.toString();
                                                              setState(() {
                                                                if (errorMsg.isEmpty || errorMsg == 'Error' || errorMsg.toLowerCase() == 'error') {
                                                                  _pdfError = 'Không thể tải file PDF. Vui lòng kiểm tra kết nối và thử lại.';
                                                                } else {
                                                                  _pdfError = 'Lỗi tải PDF: $errorMsg';
                                                                }
                                                              });
                                                            }
                                                          },
                                                          onDocumentLoaded: (PdfDocumentLoadedDetails details) {
                                                            debugPrint('ContractSigningScreen: PDF loaded successfully. Pages: ${details.document.pages.count}');
                                                          },
                                                        );
                                                      },
                                                    )
                                                  : const Center(
                                                      child: CircularProgressIndicator(),
                                                    ),
                                    ),
                                  ),
                                ),
                              ),
                              // Content below PDF (signature, buttons, etc.) - Flexible để không bị tràn
                              // Luôn hiển thị phần này ngay cả khi có lỗi PDF để user vẫn có thể ký
                              Flexible(
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                // Button to open PDF in external app - chỉ hiển thị khi PDF load thành công
                                if (_pdfBytes != null && _pdfBytes!.isNotEmpty && !_isLoadingPdf && _pdfError == null) ...[
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    onPressed: _openPdfInExternalApp,
                                    icon: const Icon(Icons.open_in_new),
                                    label: const Text('Mở PDF bằng ứng dụng khác'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.grey[300],
                                      foregroundColor: Colors.black87,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 24,
                                        vertical: 12,
                                      ),
                                    ),
                                  ),
                                ],
                                // Show signature section only if not already signed
                                // Hiển thị ngay cả khi có lỗi PDF để user vẫn có thể ký hợp đồng
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
                                      const SizedBox(height: 16),
                                    ],
                                  ),
                                ),
                              ),
                            ],
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
                            // Ensure bookingId is correctly set before navigation
                            final updatedBookingData = _ensureBookingIdInData(widget.bookingData);
                            // Navigate to payment amount screen if already signed
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PaymentAmountScreen(
                                  bookingData: updatedBookingData,
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

  // Tính số tiền thanh toán: số ngày thuê * giá thuê theo ngày * (1 + phí nền tảng %)
  // Helper method để lấy thông tin tính toán
  Map<String, double> _getCalculationDetails() {
    try {
      final pickupAtStr = bookingData['pickupAt']?.toString();
      final returnAtStr = bookingData['returnAt']?.toString();
      var baseDailyRateRaw = bookingData['snapshotBaseDailyRate'];
      var platformFeePercentRaw = bookingData['snapshotPlatformFeePercent'];
      
      // Ưu tiên lấy tổng giá thuê từ booking data
      var snapshotRentalTotalRaw = bookingData['snapshotRentalTotal'];
      final snapshotRentalTotal = (snapshotRentalTotalRaw is num ? snapshotRentalTotalRaw.toDouble() : (snapshotRentalTotalRaw?.toDouble() ?? 0.0));
      
      // Fallback: Thử lấy từ items nếu không có trong snapshot
      if (baseDailyRateRaw == null || (baseDailyRateRaw is num && baseDailyRateRaw <= 0)) {
        final items = bookingData['items'];
        if (items is List && items.isNotEmpty) {
          final firstItem = items[0];
          if (firstItem is Map<String, dynamic>) {
            final camera = firstItem['camera'];
            if (camera is Map<String, dynamic>) {
              baseDailyRateRaw ??= camera['pricePerDay'] ?? camera['price_per_day'] ?? camera['dailyRate'] ?? camera['daily_rate'];
            }
            // Thử lấy từ item trực tiếp
            baseDailyRateRaw ??= firstItem['pricePerDay'] ?? firstItem['price_per_day'] ?? firstItem['dailyRate'] ?? firstItem['daily_rate'];
          }
        }
      }
      
      if (platformFeePercentRaw == null || (platformFeePercentRaw is num && platformFeePercentRaw <= 0)) {
        final items = bookingData['items'];
        if (items is List && items.isNotEmpty) {
          final firstItem = items[0];
          if (firstItem is Map<String, dynamic>) {
            final camera = firstItem['camera'];
            if (camera is Map<String, dynamic>) {
              platformFeePercentRaw ??= camera['platformFeePercent'] ?? camera['platform_fee_percent'] ?? camera['feePercent'] ?? camera['fee_percent'];
            }
            // Thử lấy từ item trực tiếp
            platformFeePercentRaw ??= firstItem['platformFeePercent'] ?? firstItem['platform_fee_percent'] ?? firstItem['feePercent'] ?? firstItem['fee_percent'];
          }
        }
        // Mặc định 10% nếu vẫn không có
        if (platformFeePercentRaw == null || (platformFeePercentRaw is num && platformFeePercentRaw <= 0)) {
          platformFeePercentRaw = 10.0;
        }
      }
      
      final baseDailyRate = (baseDailyRateRaw is num ? baseDailyRateRaw.toDouble() : (baseDailyRateRaw?.toDouble() ?? 0.0));
      var platformFeePercent = (platformFeePercentRaw is num ? platformFeePercentRaw.toDouble() : (platformFeePercentRaw?.toDouble() ?? 10.0));

      // ƯU TIÊN: Nếu có snapshotRentalTotal từ booking, sử dụng nó làm baseTotal
      // Đây là nguồn dữ liệu chính xác nhất từ backend
      if (snapshotRentalTotal > 0) {
        final baseTotal = snapshotRentalTotal;
        final platformFee = baseTotal * (platformFeePercent / 100);
        final remainingAmount = baseTotal - platformFee;
        debugPrint('ContractSigningScreen: Using snapshotRentalTotal from booking: $baseTotal');
        return {
          'baseTotal': baseTotal,
          'platformFee': platformFee,
          'platformFeePercent': platformFeePercent,
          'paymentAmount': platformFee,
          'remainingAmount': remainingAmount,
        };
      }
      
      debugPrint('ContractSigningScreen: snapshotRentalTotal not available, calculating from dates and rates');

      if (pickupAtStr == null || returnAtStr == null) {
        // Nếu không có dates, tính từ totalAmount với platformFeePercent mặc định
        if (totalAmount > 0 && platformFeePercent > 0) {
          // Giả sử totalAmount là baseTotal, tính platformFee
          final estimatedBaseTotal = totalAmount;
          final platformFee = estimatedBaseTotal * (platformFeePercent / 100);
          return {
            'baseTotal': estimatedBaseTotal,
            'platformFee': platformFee,
            'platformFeePercent': platformFeePercent,
            'paymentAmount': platformFee,
            'remainingAmount': estimatedBaseTotal - platformFee,
          };
        }
        return {
          'baseTotal': totalAmount,
          'platformFee': 0.0,
          'platformFeePercent': platformFeePercent,
          'paymentAmount': totalAmount,
          'remainingAmount': 0.0,
        };
      }

      final pickupAt = DateTime.parse(pickupAtStr);
      final returnAt = DateTime.parse(returnAtStr);
      final rentalDays = returnAt.difference(pickupAt).inDays;
      
      if (rentalDays <= 0) {
        // Nếu rentalDays <= 0, tính từ totalAmount
        if (totalAmount > 0 && platformFeePercent > 0) {
          final estimatedBaseTotal = totalAmount;
          final platformFee = estimatedBaseTotal * (platformFeePercent / 100);
          return {
            'baseTotal': estimatedBaseTotal,
            'platformFee': platformFee,
            'platformFeePercent': platformFeePercent,
            'paymentAmount': platformFee,
            'remainingAmount': estimatedBaseTotal - platformFee,
          };
        }
        return {
          'baseTotal': totalAmount,
          'platformFee': 0.0,
          'platformFeePercent': platformFeePercent,
          'paymentAmount': totalAmount,
          'remainingAmount': 0.0,
        };
      }

      // Nếu baseDailyRate vẫn là 0, tính từ totalAmount và rentalDays
      double finalBaseDailyRate = baseDailyRate;
      if (finalBaseDailyRate <= 0 && totalAmount > 0 && rentalDays > 0) {
        finalBaseDailyRate = totalAmount / rentalDays;
      }

      if (finalBaseDailyRate <= 0) {
        // Fallback cuối cùng: sử dụng totalAmount
        if (totalAmount > 0 && platformFeePercent > 0) {
          final estimatedBaseTotal = totalAmount;
          final platformFee = estimatedBaseTotal * (platformFeePercent / 100);
          return {
            'baseTotal': estimatedBaseTotal,
            'platformFee': platformFee,
            'platformFeePercent': platformFeePercent,
            'paymentAmount': platformFee,
            'remainingAmount': estimatedBaseTotal - platformFee,
          };
        }
        return {
          'baseTotal': totalAmount,
          'platformFee': 0.0,
          'platformFeePercent': platformFeePercent,
          'paymentAmount': totalAmount,
          'remainingAmount': 0.0,
        };
      }

      final baseTotal = rentalDays * finalBaseDailyRate; // Tổng giá thuê cơ bản
      final platformFee = baseTotal * (platformFeePercent / 100); // Phí nền tảng = % của tổng giá thuê
      final remainingAmount = baseTotal - platformFee; // Phần còn lại (thanh toán khi nhận thiết bị)

      return {
        'baseTotal': baseTotal.toDouble(),
        'platformFee': platformFee.toDouble(),
        'platformFeePercent': platformFeePercent.toDouble(), // Thêm phần trăm để hiển thị
        'paymentAmount': platformFee.toDouble(), // Số tiền thanh toán = phí nền tảng
        'remainingAmount': remainingAmount.toDouble(),
      };
    } catch (e) {
      debugPrint('ContractSigningScreen: Error calculating: $e');
      // Fallback: tính từ totalAmount với platformFeePercent mặc định 10%
      final platformFeePercent = 10.0;
      if (totalAmount > 0) {
        final platformFee = totalAmount * (platformFeePercent / 100);
        return {
          'baseTotal': totalAmount,
          'platformFee': platformFee,
          'platformFeePercent': platformFeePercent,
          'paymentAmount': platformFee,
          'remainingAmount': totalAmount - platformFee,
        };
      }
      return {
        'baseTotal': 0.0,
        'platformFee': 0.0,
        'platformFeePercent': platformFeePercent,
        'paymentAmount': totalAmount,
        'remainingAmount': 0.0,
      };
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
                            Builder(
                              builder: (context) {
                                final details = _getCalculationDetails();
                                final baseTotal = details['baseTotal'] ?? 0.0;
                                final platformFee = details['platformFee'] ?? 0.0;
                                final platformFeePercent = details['platformFeePercent'] ?? 0.0;
                                final remainingAmount = details['remainingAmount'] ?? 0.0;
                                
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    // Tổng giá thuê cơ bản
                                    if (baseTotal > 0) ...[
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text(
                                            'Tổng giá thuê',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey,
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
                                    ],
                                    // Phí nền tảng (số tiền thanh toán)
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            platformFeePercent > 0
                                                ? 'Phí nền tảng (${platformFeePercent.toStringAsFixed(0)}%)'
                                                : 'Phí nền tảng (số tiền thanh toán)',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          _formatCurrency(platformFee),
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Theme.of(context).colorScheme.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    // Phần còn lại
                                    if (remainingAmount > 0) ...[
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Phần thanh toán khi nhận thiết bị',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                          Text(
                                            _formatCurrency(remainingAmount),
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey[700],
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                );
                              },
                            ),
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

