import 'dart:convert';
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

      final data = _handleResponse(response);

      // Save token if available
      if (data['token'] != null) {
        await _saveToken(data['token']);
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
      if (data['token'] != null) {
        await _saveToken(data['token']);
      } else if (data['accessToken'] != null) {
        await _saveToken(data['accessToken']);
      } else if (data['access_token'] != null) {
        await _saveToken(data['access_token']);
      } else if (data['data']?['token'] != null) {
        await _saveToken(data['data']['token']);
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

  // Create booking from cart
  static Future<Map<String, dynamic>> createBookingFromCart({
    required String customerName,
    required String customerPhone,
    required String customerEmail,
    String? customerAddress,
    String? notes,
  }) async {
    try {
      final response = await http.post(
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

      return _handleResponse(response);
    } catch (e) {
      throw Exception('Failed to create booking from cart: ${e.toString()}');
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
