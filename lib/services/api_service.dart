import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

enum BookingItemType {
  camera(1),
  accessory(2),
  combo(3);

  final int value;
  const BookingItemType(this.value);

  static BookingItemType? fromValue(dynamic raw) {
    if (raw is int) {
      for (final type in BookingItemType.values) {
        if (type.value == raw) {
          return type;
        }
      }
      return null;
    }
    if (raw is String) {
      final parsed = int.tryParse(raw);
      if (parsed != null) {
        return fromValue(parsed);
      }
    }
    return null;
  }
}

class ApiService {
  static const String baseUrl = 'https://camrent-backend.up.railway.app/api';

  static String? _extractErrorMessage(String? body) {
    if (body == null || body.trim().isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        const keys = ['message', 'error', 'errorMessage', 'detail'];
        for (final key in keys) {
          final value = decoded[key];
          if (value is String && value.trim().isNotEmpty) {
            return value.trim();
          }
        }
        final firstString = decoded.values.firstWhere(
          (value) => value is String && value.trim().isNotEmpty,
          orElse: () => null,
        );
        if (firstString is String) {
          return firstString.trim();
        }
      }
      if (decoded is String && decoded.trim().isNotEmpty) {
        return decoded.trim();
      }
    } catch (_) {
      // Fall back to raw body
    }

    return body.trim();
  }

  static String? _extractToken(dynamic source) {
    if (source == null) return null;

    if (source is String && source.trim().isNotEmpty) {
      // Strings cannot contain token info unless already the token value.
      return null;
    }

    if (source is Map<String, dynamic>) {
      for (final key in ['token', 'accessToken', 'access_token']) {
        final value = source[key];
        if (value is String && value.trim().isNotEmpty) {
          return value.trim();
        }
      }

      // Recursively search nested payloads
      for (final value in source.values) {
        final possible = _extractToken(value);
        if (possible != null) {
          return possible;
        }
      }
    } else if (source is List) {
      for (final item in source) {
        final possible = _extractToken(item);
        if (possible != null) {
          return possible;
        }
      }
    }

    return null;
  }

  // Get auth token from shared preferences
  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  // Save auth token to shared preferences
  static Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  // Clear auth token
  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  // Get headers with authentication
  static Future<Map<String, String>> _getHeaders({
    bool requiresAuth = false,
  }) async {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (requiresAuth) {
      final token = await _getToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  // Handle API response
  static Map<String, dynamic> _handleResponse(http.Response response) {
    final statusCode = response.statusCode;
    final body = response.body;

    if (statusCode >= 200 && statusCode < 300) {
      if (body.isEmpty) {
        return {'success': true};
      }
      try {
        final decoded = jsonDecode(body);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
        return {'success': true, 'data': decoded};
      } catch (_) {
        return {'success': true, 'message': body};
      }
    }

    try {
      final error = jsonDecode(body);
      if (error is Map<String, dynamic>) {
        throw Exception(error['message'] ?? 'An error occurred');
      }
      throw Exception('Error: $statusCode');
    } catch (_) {
      throw Exception(body.isNotEmpty ? body : 'Error: $statusCode');
    }
  }

  // Authentication APIs
  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/Auths/Login'),
        headers: await _getHeaders(),
        body: jsonEncode({'email': email, 'password': password}),
      );

       final statusCode = response.statusCode;
       final errorBody = response.body;

       bool _looksLikeCredentialIssue(String? message) {
         if (message == null) return false;
         final lowered = message.toLowerCase();
         const keywords = [
           'password',
           'credential',
           'email',
           'username',
           'account',
           'invalid',
           'incorrect',
           'unauthorized',
         ];
         return keywords.any(lowered.contains);
       }

       if (statusCode == 400 ||
           statusCode == 401 ||
           statusCode == 403 ||
           (statusCode >= 500 && _looksLikeCredentialIssue(errorBody))) {
         throw Exception(
           _extractErrorMessage(errorBody) ??
               'Email hoặc mật khẩu không chính xác',
         );
       }

       if (statusCode >= 500) {
         throw Exception(
           _extractErrorMessage(errorBody) ??
               'Máy chủ đang gặp sự cố, vui lòng thử lại sau.',
         );
       }

      final data = _handleResponse(response);

      // Save token if available
      final token = _extractToken(data);
      if (token != null) {
        await _saveToken(token);
      }

      return data;
    } catch (e) {
      throw Exception('Login failed: ${e.toString()}');
    }
  }

  static Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String fullName,
    String? phone,
    int? role,
  }) async {
    try {
      // Build request body
      final body = <String, dynamic>{
        'email': email,
        'password': password,
        'fullName': fullName,
      };

      // Only include phone if provided
      if (phone != null && phone.isNotEmpty) {
        body['phone'] = phone;
      } else {
        body['phone'] = 'string'; // Default value as per API spec
      }

      if (role != null) {
        body['role'] = role;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/Auths/RenterRegister'),
        headers: await _getHeaders(),
        body: jsonEncode(body),
      );

      final data = _handleResponse(response);

      // Save token if available (check multiple possible token field names)
      final token = _extractToken(data);
      if (token != null) {
        await _saveToken(token);
      }

      return data;
    } catch (e) {
      throw Exception('Registration failed: ${e.toString()}');
    }
  }

  // Alias for register (for backward compatibility)
  static Future<Map<String, dynamic>> renterRegister({
    required String email,
    required String password,
    required String fullName,
    String? phone,
    int role = 0,
  }) async {
    return register(
      email: email,
      password: password,
      fullName: fullName,
      phone: phone,
      role: role,
    );
  }

  // Camera APIs
  static Future<List<dynamic>> getCameras() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/Cameras'),
        headers: await _getHeaders(),
      );

      List<dynamic> extractList(dynamic source) {
        if (source is List) {
          return source;
        }
        if (source is Map<String, dynamic>) {
          const keys = ['items', 'cameras', 'data', 'results', 'value'];
          for (final key in keys) {
            if (!source.containsKey(key)) continue;
            final value = source[key];
            final result = extractList(value);
            if (result.isNotEmpty || identical(result, value)) {
              return result;
            }
          }
        }
        return const [];
      }

      final data = _handleResponse(response);
      return extractList(data);
    } catch (e) {
      throw Exception('Failed to fetch cameras: ${e.toString()}');
    }
  }

  static Future<Map<String, dynamic>> getCameraById(String id) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/Cameras/$id'),
        headers: await _getHeaders(),
      );

      return _handleResponse(response);
    } catch (e) {
      throw Exception('Failed to fetch camera: ${e.toString()}');
    }
  }

  // Accessory APIs
  static Future<List<dynamic>> getAccessories() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/Accessories'),
        headers: await _getHeaders(),
      );

      List<dynamic> extractList(dynamic source) {
        if (source is List) {
          return source;
        }
        if (source is Map<String, dynamic>) {
          const keys = ['items', 'accessories', 'data', 'results', 'value'];
          for (final key in keys) {
            if (!source.containsKey(key)) continue;
            final value = source[key];
            final result = extractList(value);
            if (result.isNotEmpty || identical(result, value)) {
              return result;
            }
          }
        }
        return const [];
      }

      final data = _handleResponse(response);
      return extractList(data);
    } catch (e) {
      throw Exception('Failed to fetch accessories: ${e.toString()}');
    }
  }

  // Booking cart APIs
  static Future<Map<String, dynamic>> getBookingCart() async {
    try {
      final headers = await _getHeaders(requiresAuth: true);

      Future<http.Response> fetchCart(Uri uri) {
        return http.get(uri, headers: headers);
      }

      http.Response response = await fetchCart(
        Uri.parse('$baseUrl/Bookings/GetCart'),
      );

      // Retry with alternate spelling if endpoint differs
      if (response.statusCode == 404) {
        response = await fetchCart(Uri.parse('$baseUrl/Bookings/GetCard'));
      }

      final data = _handleResponse(response);
      List<dynamic>? items;
      final result = Map<String, dynamic>.from(data);

      final directKeys = ['items', 'cartItems'];
      for (final key in directKeys) {
        final value = data[key];
        if (value is List) {
          items = value;
          break;
        }
      }

      if (items == null) {
        final nested = data['data'];
        if (nested is List) {
          items = nested;
        } else if (nested is Map<String, dynamic>) {
          for (final key in directKeys) {
            final value = nested[key];
            if (value is List) {
              items = value;
              break;
            }
          }
        }
      }

      result['items'] = items ?? const [];
      return result;
    } catch (e) {
      throw Exception('Failed to load cart: ${e.toString()}');
    }
  }

  static Future<Map<String, dynamic>> addItemToCart({
    required String itemId,
    BookingItemType type = BookingItemType.camera,
    int quantity = 1,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/Bookings/AddToCart'),
        headers: await _getHeaders(requiresAuth: true),
        body: jsonEncode({
          'id': itemId,
          'type': type.value,
          'quantity': quantity,
        }),
      );

      return _handleResponse(response);
    } catch (e) {
      throw Exception('Failed to add to cart: ${e.toString()}');
    }
  }

  static Future<Map<String, dynamic>> addCameraToCart({
    required String cameraId,
    int quantity = 1,
  }) {
    return addItemToCart(
      itemId: cameraId,
      quantity: quantity,
      type: BookingItemType.camera,
    );
  }

  static Future<Map<String, dynamic>> addAccessoryToCart({
    required String accessoryId,
    int quantity = 1,
  }) {
    return addItemToCart(
      itemId: accessoryId,
      quantity: quantity,
      type: BookingItemType.accessory,
    );
  }

  static Future<Map<String, dynamic>> addComboToCart({
    required String comboId,
    int quantity = 1,
  }) {
    return addItemToCart(
      itemId: comboId,
      quantity: quantity,
      type: BookingItemType.combo,
    );
  }

  static Future<Map<String, dynamic>> removeFromCart({
    required String itemId,
    required BookingItemType type,
  }) async {
    try {
      // Validate UUID format
      if (itemId.isEmpty) {
        throw Exception('Item ID không được để trống');
      }

      // Try to parse as UUID to validate format
      final uuidPattern = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
        caseSensitive: false,
      );

      if (!uuidPattern.hasMatch(itemId)) {
        throw Exception('Item ID không đúng định dạng UUID: $itemId');
      }

      final response = await http.post(
        Uri.parse('$baseUrl/Bookings/RemoveFromCart'),
        headers: await _getHeaders(requiresAuth: true),
        body: jsonEncode({
          'request': {'id': itemId, 'type': type.value},
        }),
      );

      return _handleResponse(response);
    } catch (e) {
      throw Exception('Failed to remove from cart: ${e.toString()}');
    }
  }

  // Create booking from cart with payment integration
  static Future<Map<String, dynamic>> createBookingFromCart({
    required String customerName,
    required String customerPhone,
    required String customerEmail,
    String? customerAddress,
    String? notes,
    bool createPayment = true,
    double? paymentAmount,
    String? paymentDescription,
  }) async {
    try {
      // Step 1: Create booking
      final bookingResponse = await http.post(
        Uri.parse('$baseUrl/Bookings'),
        headers: await _getHeaders(requiresAuth: true),
        body: jsonEncode({
          'customerName': customerName,
          'customerPhone': customerPhone,
          'customerEmail': customerEmail,
          if (customerAddress != null && customerAddress.isNotEmpty)
            'customerAddress': customerAddress,
          if (notes != null && notes.isNotEmpty) 'notes': notes,
        }),
      );

      final bookingData = _handleResponse(bookingResponse);
      
      // Step 2: Create payment authorization if requested
      if (createPayment) {
        final bookingId = bookingData['id']?.toString() ?? 
                         bookingData['bookingId']?.toString();
        
        if (bookingId != null && bookingId.isNotEmpty) {
          try {
            // Create payment authorization
            final paymentId = await createPaymentAuthorization(
              bookingId: bookingId,
            );
            
            // Initialize VNPay/VietQR payment if amount is provided
            String? paymentUrl;
            if (paymentAmount != null && paymentAmount > 0) {
              paymentUrl = await initializeVnPayPayment(
                paymentId: paymentId,
                amount: paymentAmount,
                description: paymentDescription ?? 
                          'Thanh toán đặt cọc cho đơn hàng $bookingId',
              );
            }
            
            // Merge payment info into booking data
            return {
              ...bookingData,
              'paymentId': paymentId,
              'paymentUrl': paymentUrl,
            };
          } catch (e) {
            // If payment creation fails, still return booking data
            // but log the error
            // Log error but don't throw - booking is still created
            debugPrint('Warning: Failed to create payment: $e');
            return bookingData;
          }
        }
      }
      
      return bookingData;
    } catch (e) {
      throw Exception('Failed to create booking from cart: ${e.toString()}');
    }
  }
  
  // Payment APIs
  static Future<String> createPaymentAuthorization({
    required String bookingId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/Payments/authorize'),
        headers: await _getHeaders(requiresAuth: true),
        body: jsonEncode({
          'bookingId': bookingId,
        }),
      );

      final statusCode = response.statusCode;
      final body = response.body;

      if (statusCode >= 200 && statusCode < 300) {
        if (body.isEmpty) {
          throw Exception('Empty response from payment authorization');
        }
        
        try {
          // API may return UUID string directly (as JSON string)
          final decoded = jsonDecode(body);
          if (decoded is String) {
            return decoded;
          }
          
          // Or return as object with id field
          if (decoded is Map<String, dynamic>) {
            final id = decoded['id']?.toString() ?? 
                       decoded['paymentId']?.toString();
            if (id != null && id.isNotEmpty) {
              return id;
            }
            throw Exception('Payment ID not found in response');
          }
          
          // Fallback: return as string
          return decoded.toString();
        } catch (e) {
          // If JSON decode fails, try using body as string directly
          // (in case API returns plain string without JSON encoding)
          final trimmedBody = body.trim();
          if (trimmedBody.startsWith('"') && trimmedBody.endsWith('"')) {
            // Remove JSON string quotes
            return trimmedBody.substring(1, trimmedBody.length - 1);
          }
          return trimmedBody;
        }
      }

      throw Exception('Payment authorization failed: $statusCode');
    } catch (e) {
      throw Exception('Failed to create payment authorization: ${e.toString()}');
    }
  }
  
  static Future<String> initializeVnPayPayment({
    required String paymentId,
    required double amount,
    String? description,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/Payments/$paymentId/vnpay'),
        headers: await _getHeaders(requiresAuth: true),
        body: jsonEncode({
          'amount': amount,
          if (description != null && description.isNotEmpty)
            'description': description,
        }),
      );

      final statusCode = response.statusCode;
      final body = response.body;

      if (statusCode >= 200 && statusCode < 300) {
        if (body.isEmpty) {
          throw Exception('Empty response from VNPay initialization');
        }
        
        try {
          // API may return payment URL string directly (as JSON string)
          final decoded = jsonDecode(body);
          if (decoded is String) {
            return decoded;
          }
          
          // Or return as object with url field
          if (decoded is Map<String, dynamic>) {
            return decoded['url']?.toString() ?? 
                   decoded['paymentUrl']?.toString() ?? 
                   decoded['vnpayUrl']?.toString() ?? 
                   '';
          }
          
          // Fallback: return as string
          return decoded.toString();
        } catch (e) {
          // If JSON decode fails, try using body as string directly
          // (in case API returns plain string without JSON encoding)
          final trimmedBody = body.trim();
          if (trimmedBody.startsWith('"') && trimmedBody.endsWith('"')) {
            // Remove JSON string quotes
            return trimmedBody.substring(1, trimmedBody.length - 1);
          }
          return trimmedBody;
        }
      }

      throw Exception('VNPay initialization failed: $statusCode');
    } catch (e) {
      throw Exception('Failed to initialize VNPay payment: ${e.toString()}');
    }
  }
  
  static Future<void> capturePayment({
    required String paymentId,
    double? amount,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/Payments/$paymentId/capture'),
        headers: await _getHeaders(requiresAuth: true),
        body: jsonEncode({
          if (amount != null && amount > 0) 'amount': amount,
        }),
      );

      _handleResponse(response);
    } catch (e) {
      throw Exception('Failed to capture payment: ${e.toString()}');
    }
  }

  // Booking APIs
  static Future<Map<String, dynamic>> createBooking({
    required String cameraId,
    required DateTime startDate,
    required DateTime endDate,
    required String customerName,
    required String customerPhone,
    required String customerEmail,
    String? customerAddress,
    String? notes,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/bookings'),
        headers: await _getHeaders(requiresAuth: true),
        body: jsonEncode({
          'cameraId': cameraId,
          'startDate': startDate.toIso8601String().split('T')[0],
          'endDate': endDate.toIso8601String().split('T')[0],
          'customerName': customerName,
          'customerPhone': customerPhone,
          'customerEmail': customerEmail,
          'customerAddress': customerAddress,
          'notes': notes,
        }),
      );

      return _handleResponse(response);
    } catch (e) {
      throw Exception('Failed to create booking: ${e.toString()}');
    }
  }

  static Future<List<dynamic>> getBookings() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/Bookings'),
        headers: await _getHeaders(requiresAuth: true),
      );

      final statusCode = response.statusCode;
      final body = response.body;

      if (statusCode >= 200 && statusCode < 300) {
        if (body.isEmpty) {
          return [];
        }
        try {
          final decoded = jsonDecode(body);
          // API có thể trả về array trực tiếp
          if (decoded is List) {
            return decoded;
          }
          // Hoặc trong object
          if (decoded is Map<String, dynamic>) {
            final list =
                decoded['data'] ?? decoded['bookings'] ?? decoded['items'];
            if (list is List) {
              return list;
            }
          }
          return [];
        } catch (_) {
          return [];
        }
      }

      throw Exception('Error: $statusCode');
    } catch (e) {
      throw Exception('Failed to fetch bookings: ${e.toString()}');
    }
  }

  static Future<Map<String, dynamic>> getBookingById(String id) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/bookings/$id'),
        headers: await _getHeaders(requiresAuth: true),
      );

      return _handleResponse(response);
    } catch (e) {
      throw Exception('Failed to fetch booking: ${e.toString()}');
    }
  }

  // User APIs
  static Future<Map<String, dynamic>> getProfile() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/UserProfiles/UserID'),
        headers: await _getHeaders(requiresAuth: true),
      );

      return _handleResponse(response);
    } catch (e) {
      throw Exception('Failed to fetch profile: ${e.toString()}');
    }
  }

  static Future<Map<String, dynamic>> updateProfile({
    required String userId,
    String? fullName,
    String? phone,
    Map<String, dynamic>? address,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (fullName != null) body['fullName'] = fullName;
      if (phone != null) body['phone'] = phone;
      if (address != null) body['address'] = address;

      final response = await http.put(
        Uri.parse('$baseUrl/UserProfiles/$userId'),
        headers: await _getHeaders(requiresAuth: true),
        body: jsonEncode(body),
      );

      return _handleResponse(response);
    } catch (e) {
      throw Exception('Failed to update profile: ${e.toString()}');
    }
  }
}
