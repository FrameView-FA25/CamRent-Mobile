import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/booking_cart_item.dart';

enum BookingItemType {
  camera(1),
  accessory(2),
  combo(3);

  final int value;
  const BookingItemType(this.value);

  // Get string representation for API (e.g., "Camera", "Accessory")
  String get stringValue {
    switch (this) {
      case BookingItemType.camera:
        return 'Camera';
      case BookingItemType.accessory:
        return 'Accessory';
      case BookingItemType.combo:
        return 'Combo';
    }
  }

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
      // Try to match by string value
      final lowerRaw = raw.toLowerCase();
      if (lowerRaw == 'camera') return BookingItemType.camera;
      if (lowerRaw == 'accessory') return BookingItemType.accessory;
      if (lowerRaw == 'combo') return BookingItemType.combo;
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

    // Check for server-side mapping errors (common .NET AutoMapper errors)
    final bodyLower = body.toLowerCase();
    if (bodyLower.contains('error mapping types') || 
        bodyLower.contains('mapping types') ||
        bodyLower.contains('automapper') ||
        bodyLower.contains('system.collections.generic.list')) {
      // Extract the meaningful error message
      if (body.contains('Error mapping types')) {
        final match = RegExp(r'Error mapping types[^\n]*', caseSensitive: false).firstMatch(body);
        if (match != null) {
          return 'Lỗi server: ${match.group(0)}. Vui lòng liên hệ quản trị viên.';
        }
      }
      // If it's a mapping error, return a user-friendly message
      return 'Lỗi xử lý dữ liệu từ server. Vui lòng thử lại sau hoặc liên hệ quản trị viên.';
    }

    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        const keys = ['message', 'error', 'errorMessage', 'detail', 'title', 'type'];
        for (final key in keys) {
          final value = decoded[key];
          if (value is String && value.trim().isNotEmpty) {
            // Check if it's a mapping error
            if (value.toLowerCase().contains('mapping') || 
                value.toLowerCase().contains('automapper')) {
              return 'Lỗi xử lý dữ liệu từ server. Vui lòng thử lại sau.';
            }
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
      // Fall back to raw body if it looks like an error message
      if (body.contains('Exception') || 
          body.contains('Error') || 
          body.contains('mapping')) {
        // Try to extract a clean error message
        final lines = body.split('\n');
        for (final line in lines) {
          if (line.trim().isNotEmpty && 
              (line.contains('Error') || line.contains('Exception'))) {
            // Return first meaningful error line, but limit length
            final cleanLine = line.trim();
            if (cleanLine.length > 200) {
              return '${cleanLine.substring(0, 200)}...';
            }
            return cleanLine;
          }
        }
      }
    }

    // Return raw body if it's short enough, otherwise truncate
    final trimmed = body.trim();
    if (trimmed.length > 500) {
      return '${trimmed.substring(0, 500)}...';
    }
    return trimmed;
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
    bool includeContentType = true, // For GET requests, set to false
  }) async {
    final headers = <String, String>{
      'Accept': 'application/json',
    };

    // Only include Content-Type for POST/PUT/PATCH requests
    if (includeContentType) {
      headers['Content-Type'] = 'application/json';
    }

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

       bool looksLikeCredentialIssue(String? message) {
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
           (statusCode >= 500 && looksLikeCredentialIssue(errorBody))) {
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
      // Add pagination parameters to get all items
      final uri = Uri.parse('$baseUrl/Cameras').replace(queryParameters: {
        'page': '1',
        'pageSize': '1000', // Get a large number to fetch all items
      });
      
      final response = await http.get(
        uri,
        headers: await _getHeaders(includeContentType: false),
      );

      // Check status code before processing
      if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint('Cameras API Response Status: ${response.statusCode}');
        debugPrint('Cameras API Response Body (first 500 chars): ${response.body.length > 500 ? response.body.substring(0, 500) + "..." : response.body}');
        
        List<dynamic> extractList(dynamic source) {
          if (source is List) {
            debugPrint('Response is a direct List with ${source.length} items');
            return source;
          }
          if (source is Map<String, dynamic>) {
            debugPrint('Response is a Map with keys: ${source.keys.toList()}');
            // Try common pagination response keys
            const keys = ['items', 'cameras', 'data', 'results', 'value', 'content'];
            for (final key in keys) {
              if (!source.containsKey(key)) continue;
              final value = source[key];
              debugPrint('Found key "$key" with type: ${value.runtimeType}');
              final result = extractList(value);
              if (result.isNotEmpty || identical(result, value)) {
                debugPrint('Extracted list from key "$key" with ${result.length} items');
                return result;
              }
            }
            // If no list found in common keys, check if the map itself contains array-like structure
            // Sometimes the response might be wrapped differently
            if (source.isNotEmpty) {
              // Check if all values are maps (list of items)
              final values = source.values.toList();
              if (values.isNotEmpty && values.first is Map) {
                debugPrint('Extracted list from map values with ${values.length} items');
                return values;
              }
            }
          }
          debugPrint('Could not extract list from response');
          return const [];
        }

        try {
          // Check if response body contains server-side errors before parsing
          final errorMsg = _extractErrorMessage(response.body);
          if (errorMsg != null && 
              (response.body.toLowerCase().contains('error mapping') ||
               response.body.toLowerCase().contains('mapping types') ||
               response.body.toLowerCase().contains('exception'))) {
            debugPrint('Server returned error message for cameras: $errorMsg');
            throw Exception(errorMsg);
          }
          
          // Try to parse as JSON
          dynamic decoded;
          try {
            decoded = jsonDecode(response.body);
          } catch (jsonError) {
            debugPrint('Failed to parse JSON: $jsonError');
            debugPrint('Response body: ${response.body}');
            // Check if it's an error message in text format
            final textError = _extractErrorMessage(response.body);
            if (textError != null) {
              throw Exception(textError);
            }
            // If response is not valid JSON, it might be an error message
            throw Exception('Server returned invalid JSON response. This might be a server error.');
          }
          
          debugPrint('Decoded response type: ${decoded.runtimeType}');
          
          // Handle different response formats
          List<dynamic> list;
          if (decoded is List) {
            // Direct list response
            list = decoded;
            debugPrint('Response is a direct List with ${list.length} items');
          } else if (decoded is Map<String, dynamic>) {
            // Try to extract list from map
            list = extractList(decoded);
            
            if (list.isEmpty) {
              // Check if there's an error in the response
              final errorMsg = _extractErrorMessage(response.body);
              if (errorMsg != null) {
                debugPrint('Error message found in response: $errorMsg');
                throw Exception(errorMsg);
              }
              
              // Log for debugging
              debugPrint('Warning: No cameras found in response. Response keys: ${decoded.keys.toList()}');
              debugPrint('Full response structure: $decoded');
            }
          } else {
            debugPrint('Unexpected response type: ${decoded.runtimeType}');
            throw Exception('Unexpected response format from server');
          }
          
          debugPrint('Successfully extracted ${list.length} cameras');
          return list;
        } catch (e) {
          debugPrint('Error parsing cameras response: $e');
          debugPrint('Response body (first 1000 chars): ${response.body.length > 1000 ? response.body.substring(0, 1000) + "..." : response.body}');
          
          // If it's already an Exception, re-throw it
          if (e is Exception) {
            throw e;
          }
          throw Exception('Invalid response format from server: ${e.toString()}');
        }
      } else {
        final errorMsg = _extractErrorMessage(response.body) ?? 
                        'Failed to load cameras (Status: ${response.statusCode})';
        throw Exception(errorMsg);
      }
    } catch (e) {
      debugPrint('Error fetching cameras: $e');
      throw Exception('Failed to fetch cameras: ${e.toString()}');
    }
  }

  static Future<Map<String, dynamic>> getCameraById(String id) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/Cameras/$id'),
        headers: await _getHeaders(includeContentType: false),
      );

      return _handleResponse(response);
    } catch (e) {
      throw Exception('Failed to fetch camera: ${e.toString()}');
    }
  }

  // Accessory APIs
  static Future<List<dynamic>> getAccessories() async {
    try {
      // Add pagination parameters to get all items
      final uri = Uri.parse('$baseUrl/Accessories').replace(queryParameters: {
        'page': '1',
        'pageSize': '1000', // Get a large number to fetch all items
      });
      
      final response = await http.get(
        uri,
        headers: await _getHeaders(includeContentType: false),
      );

      // Check status code before processing
      if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint('Accessories API Response Status: ${response.statusCode}');
        debugPrint('Accessories API Response Body (first 500 chars): ${response.body.length > 500 ? response.body.substring(0, 500) + "..." : response.body}');
        
        List<dynamic> extractList(dynamic source) {
          if (source is List) {
            debugPrint('Response is a direct List with ${source.length} items');
            return source;
          }
          if (source is Map<String, dynamic>) {
            debugPrint('Response is a Map with keys: ${source.keys.toList()}');
            // Try common pagination response keys
            const keys = ['items', 'accessories', 'data', 'results', 'value', 'content'];
            for (final key in keys) {
              if (!source.containsKey(key)) continue;
              final value = source[key];
              debugPrint('Found key "$key" with type: ${value.runtimeType}');
              final result = extractList(value);
              if (result.isNotEmpty || identical(result, value)) {
                debugPrint('Extracted list from key "$key" with ${result.length} items');
                return result;
              }
            }
            // If no list found in common keys, check if the map itself contains array-like structure
            if (source.isNotEmpty) {
              // Check if all values are maps (list of items)
              final values = source.values.toList();
              if (values.isNotEmpty && values.first is Map) {
                debugPrint('Extracted list from map values with ${values.length} items');
                return values;
              }
            }
          }
          debugPrint('Could not extract list from response');
          return const [];
        }

        try {
          // Check if response body contains server-side errors before parsing
          final errorMsg = _extractErrorMessage(response.body);
          if (errorMsg != null && 
              (response.body.toLowerCase().contains('error mapping') ||
               response.body.toLowerCase().contains('mapping types') ||
               response.body.toLowerCase().contains('exception'))) {
            debugPrint('Server returned error message for accessories: $errorMsg');
            throw Exception(errorMsg);
          }
          
          // Try to parse as JSON
          dynamic decoded;
          try {
            decoded = jsonDecode(response.body);
          } catch (jsonError) {
            debugPrint('Failed to parse JSON: $jsonError');
            debugPrint('Response body: ${response.body}');
            // Check if it's an error message in text format
            final textError = _extractErrorMessage(response.body);
            if (textError != null) {
              throw Exception(textError);
            }
            // If response is not valid JSON, it might be an error message
            throw Exception('Server returned invalid JSON response. This might be a server error.');
          }
          
          debugPrint('Decoded response type: ${decoded.runtimeType}');
          
          // Handle different response formats
          List<dynamic> list;
          if (decoded is List) {
            // Direct list response
            list = decoded;
            debugPrint('Response is a direct List with ${list.length} items');
          } else if (decoded is Map<String, dynamic>) {
            // Try to extract list from map
            list = extractList(decoded);
            
            if (list.isEmpty) {
              // Check if there's an error in the response
              final errorMsg = _extractErrorMessage(response.body);
              if (errorMsg != null) {
                debugPrint('Error message found in response: $errorMsg');
                throw Exception(errorMsg);
              }
              
              // Log for debugging
              debugPrint('Warning: No accessories found in response. Response keys: ${decoded.keys.toList()}');
              debugPrint('Full response structure: $decoded');
            }
          } else {
            debugPrint('Unexpected response type: ${decoded.runtimeType}');
            throw Exception('Unexpected response format from server');
          }
          
          debugPrint('Successfully extracted ${list.length} accessories');
          return list;
        } catch (e) {
          debugPrint('Error parsing accessories response: $e');
          debugPrint('Response body (first 1000 chars): ${response.body.length > 1000 ? response.body.substring(0, 1000) + "..." : response.body}');
          
          // If it's already an Exception, re-throw it
          if (e is Exception) {
            throw e;
          }
          throw Exception('Invalid response format from server: ${e.toString()}');
        }
      } else {
        final errorMsg = _extractErrorMessage(response.body) ?? 
                        'Failed to load accessories (Status: ${response.statusCode})';
        throw Exception(errorMsg);
      }
    } catch (e) {
      debugPrint('Error fetching accessories: $e');
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
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final body = <String, dynamic>{
        'id': itemId,
        'type': type.value,
        'quantity': quantity,
      };

      // Thêm ngày thuê nếu có
      if (startDate != null) {
        body['startDate'] = startDate.toIso8601String();
      }
      if (endDate != null) {
        body['endDate'] = endDate.toIso8601String();
      }

      final response = await http.post(
        Uri.parse('$baseUrl/Bookings/AddToCart'),
        headers: await _getHeaders(requiresAuth: true),
        body: jsonEncode(body),
      );

      return _handleResponse(response);
    } catch (e) {
      throw Exception('Failed to add to cart: ${e.toString()}');
    }
  }

  static Future<Map<String, dynamic>> addCameraToCart({
    required String cameraId,
    int quantity = 1,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return addItemToCart(
      itemId: cameraId,
      quantity: quantity,
      type: BookingItemType.camera,
      startDate: startDate,
      endDate: endDate,
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

      // Response headers show "allow: DELETE" - endpoint only supports DELETE, not POST
      // Try multiple DELETE approaches
      final headers = await _getHeaders(requiresAuth: true);
      
      debugPrint('Removing from cart - itemId: $itemId, type: ${type.stringValue}');
      debugPrint('Request headers: $headers');
      
      http.Response? response;
      
      // Try 1: DELETE with query parameters
      debugPrint('Trying DELETE with query parameters...');
      final uriWithQuery = Uri.parse('$baseUrl/Bookings/RemoveFromCart').replace(
        queryParameters: {
          'id': itemId,
          'type': type.stringValue,
        },
      );
      
      debugPrint('DELETE endpoint with query: $uriWithQuery');
      
      try {
        final request = http.Request('DELETE', uriWithQuery);
        request.headers.addAll(headers);
        final streamedResponse = await request.send();
        response = await http.Response.fromStream(streamedResponse);
        
        debugPrint('DELETE (query) response - Status: ${response.statusCode}');
        debugPrint('Response headers: ${response.headers}');
        
        if (response.statusCode >= 200 && response.statusCode < 300) {
          debugPrint('Success with DELETE (query parameters)');
          final body = response.body;
          if (body.isEmpty || body.trim().isEmpty) {
            debugPrint('Response body is empty, returning success');
            return {'success': true, 'message': 'Item removed successfully'};
          }
          return _handleResponse(response);
        }
      } catch (e) {
        debugPrint('DELETE (query) failed: $e');
      }
      
      // Try 2: DELETE with path parameter (if query params don't work)
      if (response == null || (response.statusCode >= 400 && response.statusCode != 405)) {
        debugPrint('Trying DELETE with path parameter...');
        try {
          final uriWithPath = Uri.parse('$baseUrl/Bookings/RemoveFromCart/$itemId');
          final uriWithPathAndQuery = uriWithPath.replace(
            queryParameters: {'type': type.stringValue},
          );
          
          debugPrint('DELETE endpoint with path: $uriWithPathAndQuery');
          
          final request = http.Request('DELETE', uriWithPathAndQuery);
          request.headers.addAll(headers);
          final streamedResponse = await request.send();
          response = await http.Response.fromStream(streamedResponse);
          
          debugPrint('DELETE (path) response - Status: ${response.statusCode}');
          debugPrint('Response headers: ${response.headers}');
          
          if (response.statusCode >= 200 && response.statusCode < 300) {
            debugPrint('Success with DELETE (path parameter)');
            final body = response.body;
            if (body.isEmpty || body.trim().isEmpty) {
              debugPrint('Response body is empty, returning success');
              return {'success': true, 'message': 'Item removed successfully'};
            }
            return _handleResponse(response);
          }
        } catch (e) {
          debugPrint('DELETE (path) failed: $e');
        }
      }
      
      // Try 3: DELETE with body (if other methods don't work)
      if (response == null || response.statusCode >= 400) {
        debugPrint('Trying DELETE with body...');
        try {
          final requestBody = {
            'id': itemId,
            'type': type.stringValue,
          };
          
          debugPrint('DELETE request body: $requestBody');
          
          final request = http.Request('DELETE', Uri.parse('$baseUrl/Bookings/RemoveFromCart'));
          request.headers.addAll(headers);
          request.body = jsonEncode(requestBody);
          
          final streamedResponse = await request.send();
          response = await http.Response.fromStream(streamedResponse);
          
          debugPrint('DELETE (body) response - Status: ${response.statusCode}');
          debugPrint('Response headers: ${response.headers}');
          
          if (response.statusCode >= 200 && response.statusCode < 300) {
            debugPrint('Success with DELETE (body)');
            final body = response.body;
            if (body.isEmpty || body.trim().isEmpty) {
              debugPrint('Response body is empty, returning success');
              return {'success': true, 'message': 'Item removed successfully'};
            }
            return _handleResponse(response);
          }
        } catch (e) {
          debugPrint('DELETE (body) failed: $e');
        }
      }
      
      if (response == null) {
        throw Exception('Tất cả các phương thức DELETE đều thất bại');
      }
      
      final statusCode = response.statusCode;
      final body = response.body;
      
      debugPrint('RemoveFromCart final response - Status: $statusCode');
      debugPrint('Response body: ${body.isNotEmpty ? (body.length > 500 ? "${body.substring(0, 500)}..." : body) : "empty"}');

      // If still 405, try one more approach with different endpoint
      if (statusCode == 405) {
        debugPrint('Method Not Allowed (405) - Trying alternative endpoint...');
        // Try without /api prefix or different path
        throw Exception('Endpoint không hỗ trợ phương thức này. Vui lòng liên hệ hỗ trợ.');
      }

      // Handle other errors
      final errorMsg = _extractErrorMessage(body);
      debugPrint('Remove from cart failed: Status $statusCode, Error: $errorMsg');
      debugPrint('Full response body: ${body.isEmpty ? "empty" : body}');
      throw Exception(
        errorMsg ?? 
        'Không thể xóa khỏi giỏ hàng (Status: $statusCode)',
      );
    } catch (e) {
      debugPrint('Error in removeFromCart: $e');
      // Don't double-wrap if it's already a user-friendly Exception
      if (e.toString().contains('Exception:') && 
          !e.toString().contains('Failed to remove from cart:')) {
        rethrow;
      }
      throw Exception('Failed to remove from cart: ${e.toString().replaceFirst('Exception: ', '')}');
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
      // Step 0: Get cart items to extract dates and location info
      final cartData = await getBookingCart();
      final cartItemsRaw = cartData['items'] as List<dynamic>? ?? [];
      
      debugPrint('Cart items count: ${cartItemsRaw.length}');
      
      // Parse cart items using BookingCartItem to get proper dates
      final cartItems = <BookingCartItem>[];
      for (int i = 0; i < cartItemsRaw.length; i++) {
        final item = cartItemsRaw[i];
        if (item is Map<String, dynamic>) {
          try {
            // Log raw item data for debugging
            debugPrint('Cart item $i raw data: ${item.keys.toList()}');
            if (item.containsKey('startDate') || item.containsKey('start_date') || 
                item.containsKey('fromDate') || item.containsKey('from')) {
              debugPrint('Cart item $i date fields found');
            }
            if (item.containsKey('bookingItem')) {
              final bookingItem = item['bookingItem'];
              if (bookingItem is Map<String, dynamic>) {
                debugPrint('Cart item $i bookingItem keys: ${bookingItem.keys.toList()}');
              }
            }
            
            final parsedItem = BookingCartItem.fromJson(item);
            cartItems.add(parsedItem);
            
            debugPrint('Cart item $i parsed - startDate: ${parsedItem.startDate}, endDate: ${parsedItem.endDate}');
          } catch (e, stackTrace) {
            debugPrint('Warning: Failed to parse cart item $i: $e');
            debugPrint('StackTrace: $stackTrace');
          }
        }
      }
      
      // Find earliest start date and latest end date from cart items
      DateTime? earliestStartDate;
      DateTime? latestEndDate;
      
      for (final item in cartItems) {
        // Use parsed dates from BookingCartItem
        final startDate = item.startDate;
        final endDate = item.endDate;
        
        if (startDate != null) {
          if (earliestStartDate == null || startDate.isBefore(earliestStartDate)) {
            earliestStartDate = startDate;
          }
        }
        
        if (endDate != null) {
          if (latestEndDate == null || endDate.isAfter(latestEndDate)) {
            latestEndDate = endDate;
          }
        }
      }
      
      debugPrint('Extracted dates from cart: earliestStartDate=$earliestStartDate, latestEndDate=$latestEndDate');
      
      // Use current time if no dates found
      final now = DateTime.now();
      // Set time to a reasonable hour (e.g., 10 AM) if using default
      var pickupAt = earliestStartDate ?? DateTime(now.year, now.month, now.day, 10);
      var returnAt = latestEndDate ?? DateTime(now.year, now.month, now.day + 1, 18);
      
      debugPrint('Initial dates (local): pickupAt=$pickupAt, returnAt=$returnAt');
      
      // Normalize dates - ensure they're at the start/end of day
      // Convert to UTC to avoid timezone issues
      // Preserve the date values but convert to UTC
      pickupAt = DateTime.utc(pickupAt.year, pickupAt.month, pickupAt.day, 10, 0, 0);
      returnAt = DateTime.utc(returnAt.year, returnAt.month, returnAt.day, 18, 0, 0);
      
      // Ensure pickupAt is strictly before returnAt
      if (pickupAt.isAfter(returnAt) || pickupAt.isAtSameMomentAs(returnAt)) {
        debugPrint('Warning: pickupAt ($pickupAt) is not before returnAt ($returnAt), adjusting...');
        // If dates are wrong, use returnAt as next day after pickupAt
        returnAt = DateTime.utc(pickupAt.year, pickupAt.month, pickupAt.day + 1, 18, 0, 0);
      }
      
      // Triple check - ensure returnAt is definitely after pickupAt
      if (!returnAt.isAfter(pickupAt)) {
        debugPrint('Error: returnAt ($returnAt) is not after pickupAt ($pickupAt), forcing next day...');
        returnAt = DateTime.utc(pickupAt.year, pickupAt.month, pickupAt.day + 1, 18, 0, 0);
      }
      
      // Final validation
      final duration = returnAt.difference(pickupAt);
      debugPrint('Using dates (UTC) - pickupAt: $pickupAt, returnAt: $returnAt');
      debugPrint('Date difference: ${duration.inHours} hours (${duration.inDays} days)');
      debugPrint('Date comparison - pickupAt isBefore returnAt: ${pickupAt.isBefore(returnAt)}');
      debugPrint('Date comparison - pickupAt isAfter returnAt: ${pickupAt.isAfter(returnAt)}');
      debugPrint('Date comparison - pickupAt isAtSameMomentAs returnAt: ${pickupAt.isAtSameMomentAs(returnAt)}');
      
      // Build location Address object
      // Format: { "country": "VietNam", "province": "...", "district": "..." }
      final locationAddress = <String, dynamic>{
        'country': 'VietNam',
        'province': customerAddress ?? 'LamDong',
        'district': 'Dalat',
      };
      
      // Step 1: Create booking from cart
      // Format dates to ISO8601 strings
      final pickupAtString = pickupAt.toIso8601String();
      final returnAtString = returnAt.toIso8601String();
      
      debugPrint('Date strings to send - pickupAt: $pickupAtString, returnAt: $returnAtString');
      
      // Request body format: only location, pickupAt, returnAt (no customer fields, no notes)
      final requestBody = <String, dynamic>{
        'location': locationAddress, // lowercase 'location'
        'pickupAt': pickupAtString,
        'returnAt': returnAtString,
      };

      debugPrint('Creating booking from cart with body: $requestBody');
      debugPrint('Request body JSON: ${jsonEncode(requestBody)}');
      
      final bookingResponse = await http.post(
        Uri.parse('$baseUrl/Bookings'),
        headers: await _getHeaders(requiresAuth: true),
        body: jsonEncode(requestBody),
      );

      debugPrint('Booking creation response: Status ${bookingResponse.statusCode}');
      debugPrint('Response body: ${bookingResponse.body.isNotEmpty ? (bookingResponse.body.length > 500 ? "${bookingResponse.body.substring(0, 500)}..." : bookingResponse.body) : "empty"}');

      // Check for errors before processing
      if (bookingResponse.statusCode >= 400) {
        final errorMsg = _extractErrorMessage(bookingResponse.body);
        debugPrint('Booking creation failed: $errorMsg');
        throw Exception(
          errorMsg ?? 
          'Không thể tạo đơn đặt hàng (Status: ${bookingResponse.statusCode})',
        );
      }

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
      final requestBody = {'bookingId': bookingId};
      
      debugPrint('Creating payment authorization for booking: $bookingId');
      
      final response = await http.post(
        Uri.parse('$baseUrl/Payments/authorize'),
        headers: await _getHeaders(requiresAuth: true),
        body: jsonEncode(requestBody),
      );

      final statusCode = response.statusCode;
      final body = response.body;

      debugPrint('Payment authorization response: Status $statusCode');
      debugPrint('Response body: ${body.isNotEmpty ? (body.length > 500 ? "${body.substring(0, 500)}..." : body) : "empty"}');

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

      final errorMsg = _extractErrorMessage(body);
      debugPrint('Payment authorization failed: $errorMsg');
      throw Exception(
        errorMsg ?? 
        'Không thể tạo thanh toán (Status: $statusCode)',
      );
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
      final requestBody = {
        'amount': amount,
        if (description != null && description.isNotEmpty)
          'description': description,
      };
      
      debugPrint('Initializing VNPay payment for paymentId: $paymentId, amount: $amount');
      
      final response = await http.post(
        Uri.parse('$baseUrl/Payments/$paymentId/vnpay'),
        headers: await _getHeaders(requiresAuth: true),
        body: jsonEncode(requestBody),
      );

      final statusCode = response.statusCode;
      final body = response.body;

      debugPrint('VNPay initialization response: Status $statusCode');
      debugPrint('Response body: ${body.isNotEmpty ? (body.length > 500 ? "${body.substring(0, 500)}..." : body) : "empty"}');

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

      final errorMsg = _extractErrorMessage(body);
      debugPrint('VNPay initialization failed: $errorMsg');
      throw Exception(
        errorMsg ?? 
        'Không thể khởi tạo thanh toán VNPay (Status: $statusCode)',
      );
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

  // Initialize PayOS payment
  static Future<String> initializePayOSPayment({
    required String paymentId,
    required double amount,
    String? description,
    String? returnUrl,
    String? cancelUrl,
  }) async {
    try {
      final requestBody = {
        'amount': amount,
        'description': description ?? 'None',
        'returnUrl': returnUrl ?? 'string',
        'cancelUrl': cancelUrl ?? 'string',
      };
      
      debugPrint('Initializing PayOS payment for paymentId: $paymentId, amount: $amount');
      debugPrint('Request body: $requestBody');
      
      final response = await http.post(
        Uri.parse('$baseUrl/Payments/$paymentId/payos'),
        headers: await _getHeaders(requiresAuth: true),
        body: jsonEncode(requestBody),
      );

      final statusCode = response.statusCode;
      final body = response.body;

      debugPrint('PayOS initialization response: Status $statusCode');
      debugPrint('Response body: ${body.isNotEmpty ? (body.length > 500 ? "${body.substring(0, 500)}..." : body) : "empty"}');

      if (statusCode >= 200 && statusCode < 300) {
        if (body.isEmpty) {
          throw Exception('Empty response from PayOS initialization');
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
                   decoded['payosUrl']?.toString() ?? 
                   decoded['checkoutUrl']?.toString() ??
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

      final errorMsg = _extractErrorMessage(body);
      debugPrint('PayOS initialization failed: $errorMsg');
      
      // Check for specific error types and provide user-friendly messages
      String userFriendlyMsg;
      if (errorMsg != null) {
        final errorLower = errorMsg.toLowerCase();
        if (errorLower.contains('name or service not known') || 
            errorLower.contains('api.payos.vn')) {
          userFriendlyMsg = 'Không thể kết nối đến PayOS. Vui lòng thử lại sau hoặc liên hệ hỗ trợ.';
        } else if (errorLower.contains('network') || errorLower.contains('connection')) {
          userFriendlyMsg = 'Lỗi kết nối mạng. Vui lòng kiểm tra kết nối và thử lại.';
        } else if (statusCode >= 500) {
          userFriendlyMsg = 'Máy chủ đang gặp sự cố. Vui lòng thử lại sau.';
        } else {
          userFriendlyMsg = errorMsg;
        }
      } else {
        userFriendlyMsg = 'Không thể khởi tạo thanh toán PayOS (Status: $statusCode)';
      }
      
      throw Exception(userFriendlyMsg);
    } catch (e) {
      // Don't double-wrap if it's already a user-friendly Exception
      if (e.toString().contains('Exception:') && 
          !e.toString().contains('Failed to initialize PayOS payment:')) {
        rethrow;
      }
      throw Exception('Không thể khởi tạo thanh toán PayOS: ${e.toString().replaceFirst('Exception: ', '')}');
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

  // Get renter's booking history (lịch sử giao dịch)
  // Endpoint: /api/Bookings/renterbookings
  // Returns: List of booking objects with id, type, status, items, etc.
  static Future<List<dynamic>> getBookings() async {
    try {
      // Check if user is authenticated
      final token = await _getToken();
      if (token == null || token.isEmpty) {
        debugPrint('getBookings: No token found, user not authenticated');
        throw Exception('Vui lòng đăng nhập để xem lịch sử đặt lịch');
      }

      debugPrint('getBookings: Calling endpoint /Bookings/renterbookings');
      
      // Use /Bookings/renterbookings endpoint to get renter's booking history
      http.Response response = await http.get(
        Uri.parse('$baseUrl/Bookings/renterbookings'),
        headers: await _getHeaders(requiresAuth: true, includeContentType: false),
      );

      // If 404, try alternative endpoint
      if (response.statusCode == 404) {
        debugPrint('getBookings: 404 error, trying alternative endpoint /Bookings');
        response = await http.get(
          Uri.parse('$baseUrl/Bookings'),
          headers: await _getHeaders(requiresAuth: true, includeContentType: false),
        );
      }

      final statusCode = response.statusCode;
      final body = response.body;

      debugPrint('getBookings response - Status: $statusCode');
      debugPrint('getBookings response body (first 500 chars): ${body.length > 500 ? "${body.substring(0, 500)}..." : body}');

      // Handle authentication errors
      if (statusCode == 401) {
        debugPrint('getBookings: 401 Unauthorized - token may be invalid or expired');
        throw Exception('Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại');
      }

      // Handle not found
      if (statusCode == 404) {
        debugPrint('getBookings: 404 Not Found - endpoint may not exist');
        throw Exception('Không tìm thấy endpoint. Vui lòng thử lại sau');
      }

      if (statusCode >= 200 && statusCode < 300) {
        if (body.isEmpty) {
          debugPrint('getBookings: Empty response body');
          return [];
        }
        try {
          final decoded = jsonDecode(body);
          debugPrint('getBookings: Decoded type: ${decoded.runtimeType}');
          
          // API trả về array trực tiếp
          if (decoded is List) {
            debugPrint('getBookings: Found ${decoded.length} bookings in array');
            if (decoded.isNotEmpty) {
              debugPrint('getBookings: First item type: ${decoded.first.runtimeType}');
              debugPrint('getBookings: First item keys: ${decoded.first is Map ? (decoded.first as Map).keys.toList() : "Not a Map"}');
            }
            return decoded;
          }
          // Hoặc trong object
          if (decoded is Map<String, dynamic>) {
            debugPrint('getBookings: Response is Map with keys: ${decoded.keys.toList()}');
            final list =
                decoded['data'] ?? decoded['bookings'] ?? decoded['items'] ?? decoded['result'];
            if (list is List) {
              debugPrint('getBookings: Found ${list.length} bookings in object');
              if (list.isNotEmpty) {
                debugPrint('getBookings: First item type: ${list.first.runtimeType}');
                debugPrint('getBookings: First item keys: ${list.first is Map ? (list.first as Map).keys.toList() : "Not a Map"}');
              }
              return list;
            } else if (list != null) {
              debugPrint('getBookings: Found non-list data: ${list.runtimeType}');
            }
          }
          debugPrint('getBookings: No bookings found in response. Full decoded: $decoded');
          return [];
        } catch (e, stackTrace) {
          debugPrint('getBookings: JSON decode error: $e');
          debugPrint('getBookings: StackTrace: $stackTrace');
          debugPrint('getBookings: Response body that failed to parse: ${body.substring(0, body.length > 1000 ? 1000 : body.length)}');
          throw Exception('Không thể đọc dữ liệu từ server. Vui lòng thử lại sau');
        }
      }

      final errorMsg = _extractErrorMessage(body);
      debugPrint('getBookings: Error $statusCode - $errorMsg');
      
      // Provide user-friendly error messages
      if (statusCode >= 500) {
        throw Exception('Máy chủ đang gặp sự cố. Vui lòng thử lại sau');
      }
      
      throw Exception(errorMsg ?? 'Không thể tải lịch sử đặt lịch (Lỗi: $statusCode)');
    } catch (e) {
      debugPrint('getBookings: Exception - ${e.toString()}');
      // Re-throw if it's already a user-friendly Exception
      if (e is Exception && !e.toString().contains('Exception:')) {
        rethrow;
      }
      throw Exception('Không thể tải lịch sử đặt lịch: ${e.toString()}');
    }
  }

  // Get bookings for a specific camera to check availability
  static Future<List<Map<String, dynamic>>> getCameraBookings(String cameraId) async {
    try {
      final allBookings = await getBookings();
      final cameraBookings = <Map<String, dynamic>>[];

      for (final booking in allBookings) {
        if (booking is! Map<String, dynamic>) continue;
        
        // Check if booking contains this camera
        final items = booking['items'] as List<dynamic>?;
        if (items != null) {
          for (final item in items) {
            if (item is Map<String, dynamic>) {
              final itemCameraId = item['cameraId']?.toString() ?? 
                                  item['itemId']?.toString();
              if (itemCameraId == cameraId) {
                cameraBookings.add(booking);
                break;
              }
            }
          }
        }
      }

      return cameraBookings;
    } catch (e) {
      debugPrint('Error fetching camera bookings: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>> getBookingById(String id) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/bookings/$id'),
        headers: await _getHeaders(requiresAuth: true, includeContentType: false),
      );

      return _handleResponse(response);
    } catch (e) {
      throw Exception('Failed to fetch booking: ${e.toString()}');
    }
  }

  // User APIs
  static Future<Map<String, dynamic>> getProfile() async {
    try {
      // Check if token exists before making request
      final token = await _getToken();
      if (token == null || token.isEmpty) {
        throw Exception('Chưa đăng nhập. Vui lòng đăng nhập để xem thông tin cá nhân.');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/UserProfiles/UserID'),
        headers: await _getHeaders(requiresAuth: true, includeContentType: false),
      );

      // Handle different response scenarios
      if (response.statusCode == 401 || response.statusCode == 403) {
        // Token might be expired or invalid
        await clearToken();
        throw Exception('Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.');
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (response.body.isEmpty) {
          throw Exception('Không nhận được dữ liệu từ server');
        }

        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic>) {
            return decoded;
          }
          // If response is not a map, wrap it
          return {'data': decoded};
        } catch (e) {
          debugPrint('Error parsing profile response: $e');
          throw Exception('Định dạng dữ liệu không hợp lệ');
        }
      } else {
        final errorMsg = _extractErrorMessage(response.body) ?? 
                        'Không thể tải thông tin cá nhân (Status: ${response.statusCode})';
        throw Exception(errorMsg);
      }
    } catch (e) {
      debugPrint('Error fetching profile: $e');
      // Re-throw with user-friendly message if it's already an Exception
      if (e is Exception) {
        throw e;
      }
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
