import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

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

  // Save user role to shared preferences (as string)
  static Future<void> _saveRole(String? role) async {
    final prefs = await SharedPreferences.getInstance();
    if (role != null && role.isNotEmpty) {
      await prefs.setString('user_role', role);
      debugPrint('ApiService: Saved user role: $role');
    } else {
      await prefs.remove('user_role');
    }
  }

  // Get user role from shared preferences
  static Future<String?> getUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('user_role');
    debugPrint('ApiService: Retrieved user role: $role');
    return role;
  }
  
  // Check if user is Staff
  static Future<bool> isStaff() async {
    final role = await getUserRole();
    return role != null && role.toLowerCase() == 'staff';
  }
  
  // Check if user is Renter
  static Future<bool> isRenter() async {
    final role = await getUserRole();
    return role != null && role.toLowerCase() == 'renter';
  }

  // Clear auth token and role
  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_role');
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

      // Log full response for debugging
      debugPrint('ApiService: Login response data: $data');
      debugPrint('ApiService: Login response data keys: ${data.keys.toList()}');

      // Save token if available
      final token = _extractToken(data);
      if (token != null) {
        await _saveToken(token);
        debugPrint('ApiService: Token saved successfully');
      } else {
        debugPrint('ApiService: WARNING - No token found in response');
      }

      // Extract and save user role if available
      // Role might be in data['roles'] (array), data['role'], data['user']['roles'], etc.
      String? userRole;
      
      // Try roles array (most common format: roles: ["Staff"] or roles: ["Renter"])
      if (data.containsKey('roles') && data['roles'] != null) {
        debugPrint('ApiService: Found roles field: ${data['roles']} (type: ${data['roles'].runtimeType})');
        if (data['roles'] is List) {
          final rolesList = data['roles'] as List;
          if (rolesList.isNotEmpty) {
            // Get first role from array
            final firstRole = rolesList.first;
            if (firstRole is String) {
              userRole = firstRole;
            } else {
              userRole = firstRole.toString();
            }
            debugPrint('ApiService: Extracted role from roles array: $userRole');
          }
        }
      }
      
      // Try direct role field (string)
      if (userRole == null && data.containsKey('role') && data['role'] != null) {
        debugPrint('ApiService: Found role field: ${data['role']} (type: ${data['role'].runtimeType})');
        if (data['role'] is String) {
          userRole = data['role'] as String;
        } else {
          userRole = data['role'].toString();
        }
      }
      
      // Try nested user.roles or user.role
      if (userRole == null && data.containsKey('user') && data['user'] != null) {
        debugPrint('ApiService: Found user field: ${data['user']}');
        if (data['user'] is Map) {
          final user = data['user'] as Map<String, dynamic>;
          debugPrint('ApiService: User keys: ${user.keys.toList()}');
          
          // Try user.roles array
          if (user.containsKey('roles') && user['roles'] != null) {
            if (user['roles'] is List) {
              final rolesList = user['roles'] as List;
              if (rolesList.isNotEmpty) {
                final firstRole = rolesList.first;
                if (firstRole is String) {
                  userRole = firstRole;
                } else {
                  userRole = firstRole.toString();
                }
                debugPrint('ApiService: Extracted role from user.roles array: $userRole');
              }
            }
          }
          
          // Try user.role string
          if (userRole == null && user.containsKey('role') && user['role'] != null) {
            debugPrint('ApiService: Found user.role: ${user['role']} (type: ${user['role'].runtimeType})');
            if (user['role'] is String) {
              userRole = user['role'] as String;
            } else {
              userRole = user['role'].toString();
            }
          }
        }
      }
      
      // Try userRole field
      if (userRole == null && data.containsKey('userRole') && data['userRole'] != null) {
        debugPrint('ApiService: Found userRole field: ${data['userRole']} (type: ${data['userRole'].runtimeType})');
        if (data['userRole'] is String) {
          userRole = data['userRole'] as String;
        } else {
          userRole = data['userRole'].toString();
        }
      }
      
      // Try to get role from token payload (JWT decode)
      if (userRole == null && token != null) {
        try {
          final parts = token.split('.');
          if (parts.length == 3) {
            final payload = parts[1];
            String normalizedPayload = payload;
            switch (payload.length % 4) {
              case 1:
                normalizedPayload += '===';
                break;
              case 2:
                normalizedPayload += '==';
                break;
              case 3:
                normalizedPayload += '=';
                break;
            }
            try {
              final decodedPayload = utf8.decode(base64.decode(normalizedPayload));
              final payloadJson = jsonDecode(decodedPayload) as Map<String, dynamic>;
              debugPrint('ApiService: JWT payload keys: ${payloadJson.keys.toList()}');
              
              // Try roles array in JWT
              if (payloadJson.containsKey('roles') && payloadJson['roles'] is List) {
                final rolesList = payloadJson['roles'] as List;
                if (rolesList.isNotEmpty) {
                  final firstRole = rolesList.first;
                  if (firstRole is String) {
                    userRole = firstRole;
                  } else {
                    userRole = firstRole.toString();
                  }
                  debugPrint('ApiService: Found role in JWT roles array: $userRole');
                }
              }
              
              // Try role string in JWT
              if (userRole == null && payloadJson.containsKey('role')) {
                final jwtRole = payloadJson['role'];
                if (jwtRole is String) {
                  userRole = jwtRole;
                } else if (jwtRole is List && jwtRole.isNotEmpty) {
                  userRole = jwtRole.first.toString();
                } else {
                  userRole = jwtRole.toString();
                }
                debugPrint('ApiService: Found role in JWT: $userRole');
              }
              
              // Try common JWT role claims
              for (final claim in ['http://schemas.microsoft.com/ws/2008/06/identity/claims/role', 'Role', 'UserRole']) {
                if (userRole == null && payloadJson.containsKey(claim)) {
                  final claimRole = payloadJson[claim];
                  if (claimRole is String) {
                    userRole = claimRole;
                    break;
                  } else if (claimRole is List && claimRole.isNotEmpty) {
                    userRole = claimRole.first.toString();
                    break;
                  } else {
                    userRole = claimRole.toString();
                    break;
                  }
                }
              }
            } catch (e) {
              debugPrint('ApiService: Error decoding JWT payload: $e');
            }
          }
        } catch (e) {
          debugPrint('ApiService: Error parsing JWT token: $e');
        }
      }
      
      if (userRole != null) {
        // Normalize role name (capitalize first letter)
        userRole = userRole.trim();
        if (userRole.isNotEmpty) {
          userRole = userRole[0].toUpperCase() + userRole.substring(1).toLowerCase();
        }
        await _saveRole(userRole);
        debugPrint('ApiService: Login - User role detected and saved: $userRole');
      } else {
        debugPrint('ApiService: Login - WARNING: No user role found in response or token');
        debugPrint('ApiService: Login - Full response data: $data');
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
  /// Get available cameras within a date range (with 7-day padding)
  /// startDate and endDate are the user-selected dates
  /// The API will receive startDate - 7 days and endDate + 7 days
  static Future<List<dynamic>> getAvailableCameras({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      // Pad 7 days at the beginning and end
      final paddedStartDate = startDate.subtract(const Duration(days: 7));
      final paddedEndDate = endDate.add(const Duration(days: 7));
      
      // Format dates as ISO 8601 strings
      final startDateStr = paddedStartDate.toUtc().toIso8601String();
      final endDateStr = paddedEndDate.toUtc().toIso8601String();
      
      debugPrint('ApiService: getAvailableCameras - User dates: $startDate to $endDate');
      debugPrint('ApiService: getAvailableCameras - Padded dates: $paddedStartDate to $paddedEndDate');
      debugPrint('ApiService: getAvailableCameras - API dates: $startDateStr to $endDateStr');
      
      final uri = Uri.parse('$baseUrl/Cameras/available').replace(queryParameters: {
        'start': startDateStr,
        'end': endDateStr,
      });
      
      final response = await http.get(
        uri,
        headers: await _getHeaders(includeContentType: false),
      );

      // Check status code before processing
      if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint('Available Cameras API Response Status: ${response.statusCode}');
        
        List<dynamic> extractList(dynamic source) {
          if (source is List) {
            return source;
          }
          if (source is Map<String, dynamic>) {
            const keys = ['items', 'cameras', 'data', 'results', 'value', 'content'];
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

        try {
          final decoded = jsonDecode(response.body);
          List<dynamic> list;
          if (decoded is List) {
            list = decoded;
          } else if (decoded is Map<String, dynamic>) {
            list = extractList(decoded);
          } else {
            debugPrint('Unexpected response format: ${decoded.runtimeType}');
            return [];
          }
          
          debugPrint('ApiService: getAvailableCameras - Found ${list.length} available cameras');
          return list;
        } catch (e) {
          debugPrint('ApiService: getAvailableCameras - Error parsing response: $e');
          throw Exception('Không thể xử lý phản hồi từ server: ${e.toString()}');
        }
      } else {
        final errorMsg = _extractErrorMessage(response.body);
        throw Exception(errorMsg ?? 'Lỗi khi tải danh sách camera khả dụng: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('ApiService: getAvailableCameras - Error: $e');
      throw Exception('Không thể tải danh sách camera khả dụng: ${e.toString().replaceFirst('Exception: ', '')}');
    }
  }

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
        debugPrint('Cameras API Response Body (first 500 chars): ${response.body.length > 500 ? "${response.body.substring(0, 500)}..." : response.body}');
        
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
          debugPrint('Response body (first 1000 chars): ${response.body.length > 1000 ? "${response.body.substring(0, 1000)}..." : response.body}');
          
          // If it's already an Exception, re-throw it
          if (e is Exception) {
            rethrow;
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
        debugPrint('Accessories API Response Body (first 500 chars): ${response.body.length > 500 ? "${response.body.substring(0, 500)}..." : response.body}');
        
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
          debugPrint('Response body (first 1000 chars): ${response.body.length > 1000 ? "${response.body.substring(0, 1000)}..." : response.body}');
          
          // If it's already an Exception, re-throw it
          if (e is Exception) {
            rethrow;
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
      
      // Log full response for debugging
      debugPrint('getBookingCart: Response status: ${response.statusCode}');
      debugPrint('getBookingCart: Response body (first 1000 chars): ${response.body.length > 1000 ? "${response.body.substring(0, 1000)}..." : response.body}');
      debugPrint('getBookingCart: Parsed data type: ${data.runtimeType}');
      debugPrint('getBookingCart: Parsed data keys: ${data.keys.toList()}');
      debugPrint('getBookingCart: Full parsed data: $data');
      
      List<dynamic>? items;
      final result = Map<String, dynamic>.from(data);

      final directKeys = ['items', 'cartItems', 'cartItemsList', 'bookingItems'];
      for (final key in directKeys) {
        final value = data[key];
        debugPrint('getBookingCart: Checking key "$key": ${value.runtimeType}');
        if (value is List) {
          debugPrint('getBookingCart: Found items list in key "$key" with ${value.length} items');
          items = value;
          break;
        }
      }

      if (items == null) {
        debugPrint('getBookingCart: Items not found in direct keys, checking nested data...');
        final nested = data['data'];
        debugPrint('getBookingCart: Nested data type: ${nested.runtimeType}');
        if (nested is List) {
          debugPrint('getBookingCart: Found items list in data with ${nested.length} items');
          items = nested;
        } else if (nested is Map<String, dynamic>) {
          debugPrint('getBookingCart: Nested data keys: ${nested.keys.toList()}');
          for (final key in directKeys) {
            final value = nested[key];
            if (value is List) {
              debugPrint('getBookingCart: Found items list in nested["$key"] with ${value.length} items');
              items = value;
              break;
            }
          }
        }
      }

      if (items == null) {
        debugPrint('getBookingCart: WARNING - No items found in response!');
        debugPrint('getBookingCart: All top-level keys: ${data.keys.toList()}');
        // Try to find any list in the response
        for (final entry in data.entries) {
          if (entry.value is List) {
            debugPrint('getBookingCart: Found list in key "${entry.key}" with ${(entry.value as List).length} items');
          }
        }
      } else {
        debugPrint('getBookingCart: Successfully extracted ${items.length} items');
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

      debugPrint('addItemToCart: Request body: ${jsonEncode(body)}');
      debugPrint('addItemToCart: Response status: ${response.statusCode}');
      debugPrint('addItemToCart: Response body: ${response.body}');
      
      // Handle 400 status code specially - might be "already in cart" message
      if (response.statusCode == 400) {
        final errorMessage = _extractErrorMessage(response.body) ?? response.body;
        debugPrint('addItemToCart: 400 error - $errorMessage');
        
        // Check if it's an "already in cart" message
        final bodyLower = errorMessage.toLowerCase();
        final isAlreadyInCart = bodyLower.contains('đã có trong giỏ') ||
            bodyLower.contains('already in cart') ||
            bodyLower.contains('đã tồn tại') ||
            bodyLower.contains('already exists');
        
        if (isAlreadyInCart) {
          // Return a special response indicating item is already in cart
          // This allows UI to handle it gracefully
          return {
            'success': false,
            'alreadyInCart': true,
            'message': 'Thiết bị đã có trong giỏ hàng rồi',
          };
        }
        
        // For other 400 errors, throw exception
        throw Exception(errorMessage);
      }
      
      final result = _handleResponse(response);
      debugPrint('addItemToCart: Parsed response: $result');
      debugPrint('addItemToCart: Response keys: ${result.keys.toList()}');
      
      // Check if response contains items (some APIs return cart with items)
      if (result.containsKey('items') && result['items'] is List) {
        debugPrint('addItemToCart: Response contains items list with ${(result['items'] as List).length} items');
      }
      
      // Log cart ID if present
      final cartId = result['cartId'] ?? result['cart_id'] ?? result['id'] ?? result['_id'];
      if (cartId != null) {
        debugPrint('addItemToCart: Cart ID found: $cartId');
      } else {
        debugPrint('addItemToCart: No cart ID found in response');
      }
      
      // Always return success even if no cartId - cart will be reloaded separately
      if (!result.containsKey('success')) {
        result['success'] = true;
      }
      
      return result;
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
    required String province,
    required String district,
    required DateTime pickupAt,
    required DateTime returnAt,
    String? customerAddress,
    String? notes,
    bool createPayment = true,
    double? paymentAmount,
    String? paymentDescription,
  }) async {
    try {
      final cartData = await getBookingCart();
      final cartItemsRaw = cartData['items'] as List<dynamic>? ?? [];
      
      debugPrint('createBookingFromCart: Cart items count: ${cartItemsRaw.length}');
      debugPrint('createBookingFromCart: Cart data keys: ${cartData.keys.toList()}');
      
      if (cartItemsRaw.isEmpty) {
        throw Exception('Giỏ hàng đang trống. Vui lòng thêm sản phẩm trước khi đặt lịch.');
      }
      
      // Log each cart item structure for debugging
      for (int i = 0; i < cartItemsRaw.length; i++) {
        final item = cartItemsRaw[i];
        if (item is Map<String, dynamic>) {
          debugPrint('createBookingFromCart: Item $i keys: ${item.keys.toList()}');
          debugPrint('createBookingFromCart: Item $i has camera: ${item.containsKey('camera')}');
          debugPrint('createBookingFromCart: Item $i has bookingItem: ${item.containsKey('bookingItem')}');
          if (item.containsKey('camera')) {
            final camera = item['camera'];
            if (camera is Map<String, dynamic>) {
              debugPrint('createBookingFromCart: Item $i camera keys: ${camera.keys.toList()}');
            } else {
              debugPrint('createBookingFromCart: Item $i camera is null or not a map: ${camera.runtimeType}');
            }
          }
        }
      }

      String? cartId = cartData['id']?.toString() ?? cartData['cartId']?.toString();
      if (cartId == null || cartId.isEmpty) {
        cartId = cartData['cartId']?.toString() ?? cartData['id']?.toString();
      }

      // Validate cartId is present
      if (cartId == null || cartId.isEmpty) {
        throw Exception('Không tìm thấy giỏ hàng. Vui lòng thêm sản phẩm vào giỏ hàng trước.');
      }

      // Normalize pickup/return to UTC at fixed hours
      final normalizedPickup = DateTime.utc(
        pickupAt.year,
        pickupAt.month,
        pickupAt.day,
        10,
        0,
        0,
      );
      var normalizedReturn = DateTime.utc(
        returnAt.year,
        returnAt.month,
        returnAt.day,
        18,
        0,
        0,
      );
      if (!normalizedReturn.isAfter(normalizedPickup)) {
        normalizedReturn = normalizedPickup.add(const Duration(days: 1));
      }

      // Build location object according to API spec: only country, province, district
      final locationAddress = <String, dynamic>{
        'country': 'Vietnam',
        'province': province.isNotEmpty ? province : 'Hà Nội',
        'district': district.isNotEmpty ? district : '',
      };

      // Build request body according to API spec: location, pickupAt, returnAt
      // Also include cartId to help backend find the cart
      final requestBody = <String, dynamic>{
        'location': locationAddress,
        'pickupAt': normalizedPickup.toIso8601String(),
        'returnAt': normalizedReturn.toIso8601String(),
      };
      
      // Add cartId to request body if available (some backends may need it)
      if (cartId.isNotEmpty) {
        requestBody['cartId'] = cartId;
      }

      debugPrint('Creating booking from cart with body: $requestBody');
      debugPrint('createBookingFromCart: CartId being sent: $cartId');
      debugPrint('createBookingFromCart: Cart items count before booking: ${cartItemsRaw.length}');
      debugPrint('createBookingFromCart: Cart items structure: ${cartItemsRaw.map((item) => item is Map ? item.keys.toList() : item.runtimeType).toList()}');
      
      // Build URL with cartId as query parameter if available
      Uri bookingUrl = Uri.parse('$baseUrl/Bookings');
      if (cartId.isNotEmpty) {
        bookingUrl = bookingUrl.replace(queryParameters: {'cartId': cartId});
        debugPrint('createBookingFromCart: Added cartId to query parameter: $cartId');
      }
      
      final bookingResponse = await http.post(
        bookingUrl,
        headers: await _getHeaders(requiresAuth: true),
        body: jsonEncode(requestBody),
      );

      debugPrint('Booking creation response: Status ${bookingResponse.statusCode}');
      debugPrint('Response body: ${bookingResponse.body.isNotEmpty ? (bookingResponse.body.length > 500 ? "${bookingResponse.body.substring(0, 500)}..." : bookingResponse.body) : "empty"}');
      debugPrint('Response headers: ${bookingResponse.headers}');

      // Check for errors before processing
      if (bookingResponse.statusCode >= 400) {
        final errorMsg = _extractErrorMessage(bookingResponse.body);
        debugPrint('Booking creation failed: $errorMsg');
        debugPrint('Request body sent: ${jsonEncode(requestBody)}');
        debugPrint('Response body: ${bookingResponse.body}');
        debugPrint('Response status: ${bookingResponse.statusCode}');
        
        // Handle specific null reference error
        if (errorMsg != null && 
            (errorMsg.toLowerCase().contains('object reference') ||
             errorMsg.toLowerCase().contains('null reference') ||
             errorMsg.toLowerCase().contains('not set to an instance'))) {
          throw Exception(
            'Lỗi hệ thống: Dữ liệu không đầy đủ hoặc thiếu thông tin bắt buộc.\n'
            'Vui lòng kiểm tra lại:\n'
            '- Thông tin khách hàng (tên, số điện thoại, email)\n'
            '- Địa chỉ và tỉnh/thành phố\n'
            '- Ngày thuê và trả\n'
            'Nếu lỗi vẫn tiếp tục, vui lòng liên hệ hỗ trợ.'
          );
        }
        
        throw Exception(
          errorMsg ?? 
          'Không thể tạo đơn đặt hàng (Status: ${bookingResponse.statusCode})',
        );
      }

      // Try to extract booking ID from response
      // cartId is guaranteed to be non-null at this point due to validation above
      String bookingId = cartId; // Start with cartId as default
      Map<String, dynamic> bookingData;
      
      debugPrint('createBookingFromCart: Using cartId as initial bookingId: $bookingId');
      
      // First, try to parse response as JSON
      try {
        bookingData = _handleResponse(bookingResponse);
        debugPrint('createBookingFromCart: Parsed bookingData keys: ${bookingData.keys.toList()}');
        debugPrint('createBookingFromCart: Full bookingData: $bookingData');
        
        // Try to get bookingId from response - prioritize 'id' field
        final responseBookingId = bookingData['id']?.toString() ?? 
                   bookingData['bookingId']?.toString() ??
                   bookingData['_id']?.toString();
        if (responseBookingId != null && responseBookingId.isNotEmpty) {
          bookingId = responseBookingId;
          debugPrint('createBookingFromCart: Found bookingId in response: $bookingId');
        } else {
          debugPrint('createBookingFromCart: WARNING - No bookingId found in response, using cartId: $cartId');
        }
        
        // Ensure bookingId is in bookingData
        if (bookingId.isNotEmpty && !bookingData.containsKey('id')) {
          bookingData['id'] = bookingId;
          bookingData['bookingId'] = bookingId;
        }
        
        // Log contracts array if present
        if (bookingData.containsKey('contracts')) {
          final contracts = bookingData['contracts'];
          debugPrint('createBookingFromCart: Contracts found: ${contracts is List ? (contracts).length : "not a list"}');
          if (contracts is List) {
            debugPrint('createBookingFromCart: Contracts array: $contracts');
          }
        }
        
        // Log status if present
        if (bookingData.containsKey('status')) {
          debugPrint('createBookingFromCart: Booking status: ${bookingData['status']}');
        }
        if (bookingData.containsKey('statusText')) {
          debugPrint('createBookingFromCart: Booking statusText: ${bookingData['statusText']}');
        }
      } catch (e) {
        debugPrint('Failed to parse booking response as JSON: $e');
        bookingData = {'success': true, 'message': bookingResponse.body};
      }
      
      // Try to extract bookingId from response body string if it contains UUID
      if (bookingId == cartId && bookingResponse.body.isNotEmpty) {
        // Look for UUID pattern in response body
        final uuidPattern = RegExp(r'[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}', caseSensitive: false);
        final matches = uuidPattern.allMatches(bookingResponse.body);
        if (matches.isNotEmpty) {
          // Use the first UUID found (likely the bookingId)
          bookingId = matches.first.group(0) ?? cartId;
          debugPrint('createBookingFromCart: Extracted bookingId from response body string: $bookingId');
        }
      }
      
      // If bookingId not in response, try to get from Location header
      if (bookingId == cartId && bookingResponse.headers.containsKey('location')) {
        final location = bookingResponse.headers['location'];
        if (location != null && location.isNotEmpty) {
          // Extract ID from URL like /Bookings/{id} or /api/Bookings/{id}
          final uriMatch = RegExp(r'/(?:Bookings|bookings)/([a-f0-9-]+)', caseSensitive: false).firstMatch(location);
          if (uriMatch != null) {
            final extractedId = uriMatch.group(1);
            if (extractedId != null && extractedId.isNotEmpty) {
              bookingId = extractedId;
            debugPrint('Extracted bookingId from Location header: $bookingId');
            }
          }
        }
      }
      
      // If still no bookingId, try to get the latest booking
      if (bookingId.isEmpty) {
        debugPrint('BookingId not found in response, trying to get latest booking...');
        try {
          final bookingsRaw = await getBookings();
          if (bookingsRaw.isNotEmpty) {
            // getBookings returns List<dynamic> (List<Map<String, dynamic>>)
            // Sort by createdAt field in the map
            final bookings = bookingsRaw.whereType<Map<String, dynamic>>().toList();
            if (bookings.isNotEmpty) {
              bookings.sort((a, b) {
                DateTime? aDate;
                DateTime? bDate;
                
                // Try to parse createdAt from map
                if (a['createdAt'] != null) {
                  aDate = DateTime.tryParse(a['createdAt'].toString());
                }
                if (b['createdAt'] != null) {
                  bDate = DateTime.tryParse(b['createdAt'].toString());
                }
                
                // If no createdAt, use pickupAt as fallback
                if (aDate == null && a['pickupAt'] != null) {
                  aDate = DateTime.tryParse(a['pickupAt'].toString());
                }
                if (bDate == null && b['pickupAt'] != null) {
                  bDate = DateTime.tryParse(b['pickupAt'].toString());
                }
                
                // Default to now if still null
                aDate ??= DateTime.now();
                bDate ??= DateTime.now();
                
                return bDate.compareTo(aDate);
              });
              
              // Get ID from the most recent booking
              final latestBooking = bookings.first;
              final extractedId = latestBooking['id']?.toString() ?? 
                          latestBooking['_id']?.toString();
              
              if (extractedId != null && extractedId.isNotEmpty) {
                bookingId = extractedId;
                debugPrint('Found bookingId from latest booking: $bookingId');
                // Update bookingData with full booking info
                bookingData = {
                  ...bookingData,
                  'id': bookingId,
                  'bookingId': bookingId,
                };
              } else {
                debugPrint('WARNING: Latest booking found but has no ID');
              }
            }
          }
        } catch (e, stackTrace) {
          debugPrint('Failed to get latest booking: $e');
          debugPrint('StackTrace: $stackTrace');
        }
      }
      
      // Ensure bookingId is in bookingData
      final result = Map<String, dynamic>.from(bookingData);
      if (bookingId.isNotEmpty) {
        result['id'] = bookingId;
        result['bookingId'] = bookingId;
        debugPrint('createBookingFromCart: Final bookingId: $bookingId');
      } else {
        debugPrint('createBookingFromCart: WARNING - No bookingId found!');
      }
      
      // Step 2: Create payment authorization if requested
      if (createPayment) {
        if (bookingId.isNotEmpty) {
          try {
            debugPrint('createBookingFromCart: Creating payment authorization for bookingId: $bookingId');
            
            // Wait a bit for backend to process the booking
            // This helps avoid "Object reference not set" errors
            await Future.delayed(const Duration(milliseconds: 1000));
            
            // Try to create payment authorization with retry logic
            String? paymentId;
            int maxRetries = 3;
            int retryCount = 0;
            
            while (retryCount < maxRetries && paymentId == null) {
              try {
                paymentId = await createPaymentAuthorization(
              bookingId: bookingId,
                  mode: 1, // PaymentType.Deposit = 1
                  method: 1, // PaymentMethod.PayOs = 1
                );
                debugPrint('createBookingFromCart: Payment authorization created: $paymentId');
                break; // Success, exit retry loop
              } catch (e) {
                retryCount++;
                final errorMsg = e.toString();
                
                // Don't retry for 400 errors (Invalid payment mode, etc.) - these are configuration errors
                if (errorMsg.contains('Invalid payment mode') || 
                    errorMsg.contains('Status: 400')) {
                  debugPrint('createBookingFromCart: Payment authorization failed with configuration error, not retrying');
                  rethrow;
                }
                
                // If it's a 500 error with "Object reference not set", retry
                if (errorMsg.contains('Object reference not set') && retryCount < maxRetries) {
                  debugPrint('createBookingFromCart: Payment authorization failed (attempt $retryCount/$maxRetries), retrying...');
                  // Exponential backoff: 1s, 2s, 4s
                  await Future.delayed(Duration(milliseconds: 1000 * (1 << (retryCount - 1))));
                  continue;
                } else {
                  // Other errors or max retries reached, throw
                  rethrow;
                }
              }
            }
            
            if (paymentId == null) {
              throw Exception('Không thể tạo thanh toán sau $maxRetries lần thử. Vui lòng thử lại sau hoặc liên hệ hỗ trợ.');
            }
            
            // Initialize PayOS payment if amount is provided
            // PayOS is the primary payment method for this system
            String? paymentUrl;
            String? returnedPaymentId;
            if (paymentAmount != null && paymentAmount > 0) {
              debugPrint('createBookingFromCart: Initializing PayOS payment with amount: $paymentAmount');
              try {
                final paymentResult = await initializePayOSPayment(
                paymentId: paymentId,
                amount: paymentAmount,
                description: paymentDescription ?? 
                          'Thanh toán đặt cọc cho đơn hàng $bookingId',
                  returnUrl: 'https://camrent-backend.up.railway.app/api/Payments/return?bookingId=$bookingId&paymentId=$paymentId&status=success',
                  cancelUrl: 'https://camrent-backend.up.railway.app/api/Payments/return?bookingId=$bookingId&paymentId=$paymentId&status=cancel',
              );
                // Extract paymentId and redirectUrl from Map
                returnedPaymentId = paymentResult['paymentId']?.toString();
                paymentUrl = paymentResult['redirectUrl']?.toString();
                debugPrint('createBookingFromCart: PayOS payment URL created: ${paymentUrl?.isNotEmpty ?? false ? "yes" : "no"}');
                debugPrint('createBookingFromCart: Returned paymentId: $returnedPaymentId');
              } catch (e) {
                debugPrint('createBookingFromCart: Failed to initialize PayOS payment: $e');
                // Continue without payment URL - payment can still be processed later
              }
            }
            
            // Merge payment info into booking data
            result['paymentId'] = returnedPaymentId ?? paymentId;
            if (paymentUrl != null && paymentUrl.isNotEmpty) {
              result['paymentUrl'] = paymentUrl;
              debugPrint('createBookingFromCart: Payment URL saved to bookingData: $paymentUrl');
            } else {
              debugPrint('createBookingFromCart: WARNING - Payment URL is empty or null');
            }
            debugPrint('createBookingFromCart: Returning booking data with payment info');
            debugPrint('createBookingFromCart: Final bookingData keys: ${result.keys.toList()}');
            return result;
          } catch (e, stackTrace) {
            // If payment creation fails, still return booking data
            // but log the error
            debugPrint('createBookingFromCart: Warning - Failed to create payment: $e');
            debugPrint('createBookingFromCart: StackTrace: $stackTrace');
            // Return booking data even if payment creation fails
            return result;
          }
        } else {
          debugPrint('createBookingFromCart: WARNING - Cannot create payment - bookingId is null or empty');
          // Return booking data even without payment
          return result;
          }
        }
      
      // Return booking data with bookingId if available
      debugPrint('createBookingFromCart: Returning booking data without payment (createPayment=false)');
      return result;
    } catch (e) {
      throw Exception('Failed to create booking from cart: ${e.toString()}');
    }
  }
  
  // Payment APIs
  // Get payment URL directly from booking ID (simplified flow)
  // This method combines createPaymentAuthorization + initializePayOSPayment
  // Returns Map with 'paymentId' and 'paymentUrl' (redirectUrl)
  static Future<Map<String, dynamic>> getPaymentUrlFromBookingId({
    required String bookingId,
    String? mode,
    required double amount,
    String? description,
  }) async {
    int maxRetries = 5; // Increased retries
    int initialDelay = 3; // Initial delay before first attempt
    int retryDelay = 3; // Increased delay between retries
    
    // Initial delay to give backend time to process contract signing
    debugPrint('getPaymentUrlFromBookingId: Waiting ${initialDelay}s before first attempt...');
    await Future.delayed(Duration(seconds: initialDelay));
    
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        debugPrint('getPaymentUrlFromBookingId: Getting payment URL for bookingId: $bookingId (attempt $attempt/$maxRetries)');
      
      // Step 1: Create payment authorization
        String paymentId;
        try {
          // Convert mode string to int if provided
          int? modeInt;
          if (mode != null) {
            if (mode.toLowerCase() == 'deposit') {
              modeInt = 1; // PaymentType.Deposit
            } else if (mode.toLowerCase() == 'rental') {
              modeInt = 2; // PaymentType.Rental
            } else {
              // Try to parse as int
              modeInt = int.tryParse(mode);
            }
          }
          
          paymentId = await createPaymentAuthorization(
        bookingId: bookingId,
            mode: modeInt ?? 1, // Default to Deposit (1)
            method: 1, // Default to PayOs (1)
          );
        } catch (e) {
          final errorMsg = e.toString().toLowerCase();
          // If it's a null reference error and not the last attempt, retry
          if ((errorMsg.contains('object reference') || 
               errorMsg.contains('null reference') ||
               errorMsg.contains('chưa sẵn sàng')) && 
              attempt < maxRetries) {
            final delay = retryDelay * attempt; // Exponential backoff
            debugPrint('getPaymentUrlFromBookingId: Retryable error on attempt $attempt, waiting ${delay}s before retry...');
            await Future.delayed(Duration(seconds: delay));
            continue; // Retry
          }
          rethrow; // If it's not retryable or last attempt, throw
        }
      
      debugPrint('getPaymentUrlFromBookingId: Payment ID created: $paymentId');
      
      // Step 2: Initialize PayOS payment and get URL
      final paymentResult = await initializePayOSPayment(
        paymentId: paymentId,
        amount: amount,
        description: description ?? 'Thanh toán đặt cọc cho đơn hàng $bookingId',
        returnUrl: 'https://camrent-backend.up.railway.app/api/Payments/return?bookingId=$bookingId&paymentId=$paymentId&status=success',
        cancelUrl: 'https://camrent-backend.up.railway.app/api/Payments/return?bookingId=$bookingId&paymentId=$paymentId&status=cancel',
      );
      
      // Extract redirectUrl from Map response
      final paymentUrl = paymentResult['redirectUrl']?.toString() ?? '';
      final returnedPaymentId = paymentResult['paymentId']?.toString() ?? paymentId;
      
      debugPrint('getPaymentUrlFromBookingId: Payment URL received: ${paymentUrl.isNotEmpty ? "yes" : "no"}');
      debugPrint('getPaymentUrlFromBookingId: Returned paymentId: $returnedPaymentId');
      if (paymentUrl.isNotEmpty) {
        debugPrint('getPaymentUrlFromBookingId: Payment URL: $paymentUrl');
          return {
            'paymentId': returnedPaymentId,
            'paymentUrl': paymentUrl,
          };
      } else {
        debugPrint('getPaymentUrlFromBookingId: WARNING - Payment URL is empty!');
          if (attempt < maxRetries) {
            debugPrint('getPaymentUrlFromBookingId: Retrying...');
            await Future.delayed(Duration(seconds: retryDelay));
            continue;
      }
          throw Exception('Không nhận được URL thanh toán từ server');
        }
    } catch (e) {
        debugPrint('getPaymentUrlFromBookingId: Error on attempt $attempt: $e');
        if (attempt == maxRetries) {
          debugPrint('getPaymentUrlFromBookingId: All attempts failed');
      rethrow;
    }
        // Wait before retry
        await Future.delayed(Duration(seconds: retryDelay));
      }
    }
    
    throw Exception('Không thể lấy URL thanh toán sau $maxRetries lần thử');
  }

  static Future<String> createPaymentAuthorization({
    required String bookingId,
    int? mode, // PaymentType: 1 = Deposit, 2 = Rental
    int? method, // PaymentMethod: 1 = PayOs, 2 = Wallet
  }) async {
    try {
      // Build request body according to new API spec
      // PaymentType: Deposit = 1, Rental = 2
      // PaymentMethod: PayOs = 1, Wallet = 2
      final requestBody = <String, dynamic>{
        'bookingId': bookingId,
        'mode': mode ?? 1, // Default to Deposit (1)
        'method': method ?? 1, // Default to PayOs (1)
      };
      
      debugPrint('createPaymentAuthorization: Creating payment authorization');
      debugPrint('createPaymentAuthorization: bookingId: $bookingId');
      debugPrint('createPaymentAuthorization: mode (PaymentType): ${requestBody['mode']} (${requestBody['mode'] == 1 ? 'Deposit' : 'Rental'})');
      debugPrint('createPaymentAuthorization: method (PaymentMethod): ${requestBody['method']} (${requestBody['method'] == 1 ? 'PayOs' : 'Wallet'})');
      debugPrint('createPaymentAuthorization: Request body: $requestBody');
      
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
          String? paymentId;
          
          if (decoded is String) {
            paymentId = decoded;
          } else if (decoded is Map<String, dynamic>) {
          // Or return as object with id field
            paymentId = decoded['id']?.toString() ?? 
                       decoded['paymentId']?.toString();
            if (paymentId == null || paymentId.isEmpty) {
            throw Exception('Payment ID not found in response');
          }
          } else {
          // Fallback: return as string
            paymentId = decoded.toString();
          }
          
          // Clean payment ID: remove surrounding quotes
          paymentId = paymentId.replaceAll('"', '').replaceAll("'", '').trim();
          debugPrint('createPaymentAuthorization: Cleaned payment ID: $paymentId');
          return paymentId;
        } catch (e) {
          // If JSON decode fails, try using body as string directly
          // (in case API returns plain string without JSON encoding)
          final trimmedBody = body.trim();
          String paymentId = trimmedBody;
          
          // Remove JSON string quotes if present
          if (trimmedBody.startsWith('"') && trimmedBody.endsWith('"')) {
            paymentId = trimmedBody.substring(1, trimmedBody.length - 1);
          }
          
          // Clean payment ID: remove any remaining quotes
          paymentId = paymentId.replaceAll('"', '').replaceAll("'", '').trim();
          debugPrint('createPaymentAuthorization: Cleaned payment ID from raw body: $paymentId');
          return paymentId;
        }
      }

      final errorMsg = _extractErrorMessage(body);
      debugPrint('Payment authorization failed: $errorMsg');
      
      // Check for null reference errors (common backend issue)
      if (statusCode == 500 && (body.toLowerCase().contains('object reference') || 
                                body.toLowerCase().contains('null reference'))) {
        throw Exception('Booking chưa sẵn sàng để thanh toán. Vui lòng đợi vài giây rồi thử lại hoặc liên hệ hỗ trợ.');
      }
      
      // Provide user-friendly error messages
      String userFriendlyMsg;
      if (statusCode == 500) {
        if (errorMsg != null && errorMsg.contains('Object reference not set')) {
          userFriendlyMsg = 'Booking chưa sẵn sàng để thanh toán. Vui lòng thử lại sau vài giây hoặc liên hệ hỗ trợ.';
        } else {
          userFriendlyMsg = 'Lỗi server khi tạo thanh toán. Vui lòng thử lại sau hoặc liên hệ hỗ trợ.';
        }
      } else if (statusCode == 404) {
        userFriendlyMsg = 'Không tìm thấy booking. Vui lòng kiểm tra lại thông tin đặt lịch.';
      } else if (statusCode == 400) {
        userFriendlyMsg = errorMsg ?? 'Thông tin thanh toán không hợp lệ. Vui lòng kiểm tra lại.';
      } else {
        userFriendlyMsg = errorMsg ?? 'Không thể tạo thanh toán (Status: $statusCode)';
          }
          
      throw Exception(userFriendlyMsg);
        } catch (e) {
      throw Exception('Failed to create payment authorization: ${e.toString()}');
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
  /// Initialize PayOS payment and get payment link
  /// 
  /// Backend now returns: { "paymentId": "id", "redirectUrl": "url" }
  /// 
  /// Returns: Map with 'paymentId' and 'redirectUrl'
  static Future<Map<String, dynamic>> initializePayOSPayment({
    required String paymentId,
    required double amount,
    String? description,
    String? returnUrl,
    String? cancelUrl,
  }) async {
    try {
      // Clean payment ID: remove surrounding quotes
      final cleanedPaymentId = paymentId.replaceAll('"', '').replaceAll("'", '').trim();
      debugPrint('initializePayOSPayment: Original paymentId: $paymentId');
      debugPrint('initializePayOSPayment: Cleaned paymentId: $cleanedPaymentId');
      
      final requestBody = {
        'amount': amount,
        'description': description ?? 'None',
        'returnUrl': returnUrl ?? 'string',
        'cancelUrl': cancelUrl ?? 'string',
      };
      
      debugPrint('Initializing PayOS payment for paymentId: $cleanedPaymentId, amount: $amount');
      debugPrint('Request body: $requestBody');
      
      final response = await http.post(
        Uri.parse('$baseUrl/Payments/$cleanedPaymentId/payos'),
        headers: await _getHeaders(requiresAuth: true),
        body: jsonEncode(requestBody),
      );

      final statusCode = response.statusCode;
      final body = response.body;

      debugPrint('PayOS initialization response: Status $statusCode');
      debugPrint('Response body: ${body.isNotEmpty ? (body.length > 1000 ? "${body.substring(0, 1000)}..." : body) : "empty"}');

      if (statusCode >= 200 && statusCode < 300) {
        if (body.isEmpty) {
          throw Exception('Empty response from PayOS initialization');
        }
        
        try {
          final decoded = jsonDecode(body) as Map<String, dynamic>;
          debugPrint('initializePayOSPayment: Decoded type: ${decoded.runtimeType}');
          debugPrint('initializePayOSPayment: Decoded keys: ${decoded.keys.toList()}');
          
          // Backend returns: { "paymentId": "id", "redirectUrl": "url" }
          final result = <String, dynamic>{};
          
          // Extract paymentId
          final returnedPaymentId = decoded['paymentId']?.toString() ?? 
                                   decoded['id']?.toString() ?? 
                                   cleanedPaymentId;
          result['paymentId'] = returnedPaymentId.replaceAll('"', '').replaceAll("'", '').trim();
          
          // Extract redirectUrl
          final redirectUrl = decoded['redirectUrl']?.toString() ?? 
                             decoded['url']?.toString() ??
                             decoded['paymentUrl']?.toString() ??
                             decoded['payosUrl']?.toString() ??
                             decoded['checkoutUrl']?.toString();
          
          if (redirectUrl != null && redirectUrl.isNotEmpty) {
            result['redirectUrl'] = redirectUrl.replaceAll('"', '').replaceAll("'", '').trim();
          } else {
            throw Exception('redirectUrl not found in response');
          }
          
          debugPrint('initializePayOSPayment: Extracted paymentId: ${result['paymentId']}');
          debugPrint('initializePayOSPayment: Extracted redirectUrl: ${result['redirectUrl']}');
          
          return result;
        } catch (e) {
          debugPrint('initializePayOSPayment: JSON decode error: $e');
          throw Exception('Không thể đọc phản hồi từ server: ${e.toString()}');
        }
      }

      final errorMsg = _extractErrorMessage(body);
      debugPrint('PayOS initialization failed: $errorMsg');
      
      // Check if payment already exists
      if (statusCode == 500 && errorMsg != null && 
          (errorMsg.contains('Đơn thanh toán đã tồn tại') || 
           errorMsg.contains('đã tồn tại') ||
           errorMsg.toLowerCase().contains('already exists'))) {
        debugPrint('initializePayOSPayment: Payment already exists for paymentId: $cleanedPaymentId');
        debugPrint('initializePayOSPayment: Attempting to get existing payment URL...');
        
        // Try to get existing payment URL from payment details
        try {
          final paymentResponse = await http.get(
            Uri.parse('$baseUrl/Payments/$cleanedPaymentId'),
            headers: await _getHeaders(requiresAuth: true),
          );
          
          debugPrint('initializePayOSPayment: GET payment response status: ${paymentResponse.statusCode}');
          
          if (paymentResponse.statusCode >= 200 && paymentResponse.statusCode < 300) {
            final paymentData = jsonDecode(paymentResponse.body);
            debugPrint('initializePayOSPayment: Payment data keys: ${paymentData is Map<String, dynamic> ? paymentData.keys.toList() : "not a map"}');
            
            if (paymentData is Map<String, dynamic>) {
              // Try to find payment URL in various possible fields
              final existingUrl = paymentData['url']?.toString() ?? 
                                 paymentData['paymentUrl']?.toString() ?? 
                                 paymentData['payosUrl']?.toString() ??
                                 paymentData['checkoutUrl']?.toString() ??
                                 paymentData['payosCheckoutUrl']?.toString() ??
                                 paymentData['link']?.toString() ??
                                 paymentData['paymentLink']?.toString();
              
              if (existingUrl != null && existingUrl.isNotEmpty) {
                final cleanedUrl = existingUrl.replaceAll('"', '').replaceAll("'", '').trim();
                debugPrint('initializePayOSPayment: Found existing payment URL: $cleanedUrl');
                // Return Map format
                return {
                  'paymentId': cleanedPaymentId,
                  'redirectUrl': cleanedUrl,
                };
              } else {
                debugPrint('initializePayOSPayment: No URL found in payment data');
                debugPrint('initializePayOSPayment: Payment data sample: ${paymentData.toString().substring(0, paymentData.toString().length > 500 ? 500 : paymentData.toString().length)}');
              }
            }
          } else {
            debugPrint('initializePayOSPayment: Failed to get payment info, status: ${paymentResponse.statusCode}');
            debugPrint('initializePayOSPayment: Response body: ${paymentResponse.body.substring(0, paymentResponse.body.length > 200 ? 200 : paymentResponse.body.length)}');
          }
        } catch (e) {
          debugPrint('initializePayOSPayment: Error getting existing payment: $e');
        }
        
        // If we can't get URL, throw a specific error
        throw Exception('Đơn thanh toán đã tồn tại. Vui lòng kiểm tra email hoặc liên hệ hỗ trợ để lấy liên kết thanh toán.');
      }
      
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

  /// Lấy trạng thái thanh toán theo paymentId
  /// 
  /// Endpoint: GET /api/Payments/{id}/status
  /// 
  /// Returns: Map với thông tin:
  ///   - paymentId: ID của payment
  ///   - paymentStatus: Trạng thái thanh toán
  ///   - bookingId: ID của booking
  ///   - bookingStatus: Trạng thái booking
  ///   - authorizedAmount: Số tiền đã ủy quyền
  ///   - capturedAmount: Số tiền đã thu
  ///   - isPaid: Đã thanh toán hay chưa
  static Future<Map<String, dynamic>> getPaymentStatus({
    required String paymentId,
  }) async {
    try {
      final token = await _getToken();
      if (token == null || token.isEmpty) {
        throw Exception('Vui lòng đăng nhập để xem trạng thái thanh toán');
      }

      // Clean payment ID: remove surrounding quotes
      final cleanedPaymentId = paymentId.replaceAll('"', '').replaceAll("'", '').trim();
      
      final endpoint = '$baseUrl/Payments/$cleanedPaymentId/status';
      debugPrint('getPaymentStatus: Calling endpoint: $endpoint');
      debugPrint('getPaymentStatus: paymentId: $cleanedPaymentId');

      final response = await http.get(
        Uri.parse(endpoint),
        headers: await _getHeaders(requiresAuth: true),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Kết nối quá lâu. Vui lòng thử lại');
        },
      );

      final statusCode = response.statusCode;
      debugPrint('getPaymentStatus: Response status: $statusCode');

      if (statusCode == 401) {
        throw Exception('Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại');
      }

      if (statusCode == 404) {
        throw Exception('Không tìm thấy thông tin thanh toán');
      }

      if (statusCode >= 200 && statusCode < 300) {
        final data = _handleResponse(response);
        debugPrint('getPaymentStatus: Successfully retrieved payment status');
        debugPrint('getPaymentStatus: Payment status: ${data['paymentStatus']}');
        debugPrint('getPaymentStatus: Is paid: ${data['isPaid']}');
        return data;
      }

      final errorMsg = _extractErrorMessage(response.body);
      throw Exception(errorMsg ?? 'Không thể lấy trạng thái thanh toán (Lỗi: $statusCode)');
    } catch (e) {
      debugPrint('getPaymentStatus: Exception - ${e.toString()}');
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Không thể lấy trạng thái thanh toán: ${e.toString()}');
    }
  }

  // Staff Booking APIs
  // Get booking statuses
  static Future<List<Map<String, dynamic>>> getBookingStatuses() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/Bookings/GetBookingStatus'),
        headers: await _getHeaders(requiresAuth: true, includeContentType: false),
      );

      final statusCode = response.statusCode;
      final body = response.body;

      debugPrint('getBookingStatuses: Response status: $statusCode');
      debugPrint('getBookingStatuses: Response body: ${body.length > 500 ? "${body.substring(0, 500)}..." : body}');

      if (statusCode >= 200 && statusCode < 300) {
        final decoded = jsonDecode(body);
        if (decoded is List) {
          return decoded.cast<Map<String, dynamic>>();
        } else if (decoded is Map<String, dynamic>) {
          // Try to extract list from common keys
          const keys = ['items', 'data', 'results', 'value', 'statuses'];
          for (final key in keys) {
            if (decoded.containsKey(key) && decoded[key] is List) {
              return (decoded[key] as List).cast<Map<String, dynamic>>();
            }
          }
        }
        throw Exception('Invalid response format from getBookingStatuses');
      }

      final errorMsg = _extractErrorMessage(body);
      throw Exception(errorMsg ?? 'Failed to get booking statuses (Status: $statusCode)');
    } catch (e) {
      debugPrint('Error fetching booking statuses: $e');
      throw Exception('Failed to fetch booking statuses: ${e.toString()}');
    }
  }

  // Get staff bookings
  static Future<List<dynamic>> getStaffBookings() async {
    try {
      final token = await _getToken();
      if (token == null || token.isEmpty) {
        debugPrint('getStaffBookings: No token found, user not authenticated');
        throw Exception('Chưa đăng nhập. Vui lòng đăng nhập lại.');
      }

      final endpoint = '$baseUrl/Bookings/staffbookings';
      debugPrint('getStaffBookings: Calling endpoint: $endpoint');

      final response = await http.get(
        Uri.parse(endpoint),
        headers: await _getHeaders(requiresAuth: true, includeContentType: false),
      );

      final statusCode = response.statusCode;
      final body = response.body;

      debugPrint('getStaffBookings response - Status: $statusCode');
      debugPrint('getStaffBookings response body (first 500 chars): ${body.length > 500 ? "${body.substring(0, 500)}..." : body}');

      if (statusCode == 401) {
        debugPrint('getStaffBookings: 401 Unauthorized - token may be invalid or expired');
        throw Exception('Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.');
      }

      if (statusCode >= 200 && statusCode < 300) {
        if (body.isEmpty || body.trim() == '[]') {
          debugPrint('getStaffBookings: Empty response body');
          return [];
        }

        try {
          final decoded = jsonDecode(body);
          debugPrint('getStaffBookings: Decoded type: ${decoded.runtimeType}');

          if (decoded is List) {
            final bookingsList = decoded;
            debugPrint('getStaffBookings: Found ${bookingsList.length} bookings');
            if (bookingsList.isNotEmpty) {
              debugPrint('getStaffBookings: First item type: ${bookingsList.first.runtimeType}');
              debugPrint('getStaffBookings: First item keys: ${bookingsList.first is Map ? (bookingsList.first as Map).keys.toList() : "Not a Map"}');
            }
            return bookingsList;
          } else if (decoded is Map<String, dynamic>) {
            // Try to extract list from common keys
            const keys = ['items', 'data', 'results', 'value', 'bookings'];
            for (final key in keys) {
              if (decoded.containsKey(key) && decoded[key] is List) {
                return decoded[key] as List;
              }
            }
          }

          debugPrint('getStaffBookings: No bookings found in decoded response. Full decoded: $decoded');
          return [];
        } catch (e, stackTrace) {
          debugPrint('getStaffBookings: JSON decode error: $e');
          debugPrint('getStaffBookings: StackTrace: $stackTrace');
          debugPrint('getStaffBookings: Response body that failed to parse: ${body.substring(0, body.length > 1000 ? 1000 : body.length)}');
          throw Exception('Lỗi phân tích dữ liệu từ server');
        }
      }

      final errorMsg = _extractErrorMessage(body);
      debugPrint('getStaffBookings: Error $statusCode - $errorMsg');
      throw Exception(errorMsg ?? 'Failed to load staff bookings (Status: $statusCode)');
    } catch (e) {
      debugPrint('getStaffBookings: Exception - ${e.toString()}');
      if (e.toString().contains('Exception:')) {
        rethrow;
      }
      throw Exception('Failed to fetch staff bookings: ${e.toString()}');
    }
  }

  // Get booking by QR code (booking ID)
  static Future<Map<String, dynamic>> getBookingByQr(String bookingId) async {
    try {
      // Extract booking ID from format "booking:xxx" or just "xxx"
      String cleanedId = bookingId.replaceAll('"', '').replaceAll("'", '').trim();
      if (cleanedId.startsWith('booking:')) {
        cleanedId = cleanedId.substring('booking:'.length);
      }
      debugPrint('getBookingByQr: Getting booking with ID: $cleanedId');

      final response = await http.get(
        Uri.parse('$baseUrl/Bookings/$cleanedId'),
        headers: await _getHeaders(requiresAuth: true, includeContentType: false),
      );

      final statusCode = response.statusCode;
      final body = response.body;

      debugPrint('getBookingByQr: Response status: $statusCode');
      debugPrint('getBookingByQr: Response body (first 500 chars): ${body.length > 500 ? "${body.substring(0, 500)}..." : body}');

      if (statusCode == 404) {
        throw Exception('Không tìm thấy đơn đặt lịch với mã: $cleanedId');
      }

      if (statusCode == 401) {
        throw Exception('Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.');
      }

      if (statusCode >= 200 && statusCode < 300) {
        return _handleResponse(response);
      }

      final errorMsg = _extractErrorMessage(body);
      throw Exception(errorMsg ?? 'Failed to get booking (Status: $statusCode)');
    } catch (e) {
      debugPrint('Error fetching booking by QR: $e');
      if (e.toString().contains('Exception:')) {
        rethrow;
      }
      throw Exception('Failed to fetch booking: ${e.toString()}');
    }
  }

  // Update booking status (isConfirm)
  static Future<Map<String, dynamic>> updateBookingStatus({
    required String bookingId,
    required bool isConfirm,
    String? status,
  }) async {
    try {
      final cleanedId = bookingId.replaceAll('"', '').replaceAll("'", '').trim();
      debugPrint('updateBookingStatus: Updating booking $cleanedId with isConfirm: $isConfirm, status: $status');

      final requestBody = <String, dynamic>{
        'isConfirm': isConfirm,
      };
      
      if (status != null && status.isNotEmpty) {
        requestBody['status'] = status;
      }

      debugPrint('updateBookingStatus: Request body: $requestBody');

      final response = await http.put(
        Uri.parse('$baseUrl/Bookings/$cleanedId/update-status'),
        headers: await _getHeaders(requiresAuth: true),
        body: jsonEncode(requestBody),
      );

      final statusCode = response.statusCode;
      final body = response.body;

      debugPrint('updateBookingStatus: Response status: $statusCode');
      debugPrint('updateBookingStatus: Response body: ${body.length > 500 ? "${body.substring(0, 500)}..." : body}');

      if (statusCode >= 200 && statusCode < 300) {
        if (body.isEmpty) {
          return {'success': true, 'message': 'Cập nhật trạng thái thành công'};
        }
        try {
          return _handleResponse(response);
        } catch (e) {
          return {'success': true, 'message': 'Cập nhật trạng thái thành công'};
        }
      }

      final errorMsg = _extractErrorMessage(body);
      throw Exception(errorMsg ?? 'Failed to update booking status (Status: $statusCode)');
    } catch (e) {
      debugPrint('Error updating booking status: $e');
      if (e.toString().contains('Exception:')) {
        rethrow;
      }
      throw Exception('Failed to update booking status: ${e.toString()}');
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
  /// Lấy danh sách lịch sử đặt lịch của renter (người thuê)
  /// 
  /// Endpoint: GET /api/Bookings/renterbookings
  /// 
  /// Yêu cầu: User phải đã đăng nhập (cần token)
  /// 
  /// Returns: List<dynamic> - Danh sách các booking objects với các thông tin:
  ///   - id: ID của booking
  ///   - type: Loại booking
  ///   - status: Trạng thái booking (0: Chờ xử lý, 1: Đã xác nhận, 2: Đang thuê, 3: Đã trả, 4: Đã hủy)
  ///   - items: Danh sách các items trong booking
  ///   - pickupAt: Ngày nhận
  ///   - returnAt: Ngày trả
  ///   - totalPrice: Tổng giá trị
  ///   - customerName: Tên khách hàng
  ///   - cameraName: Tên máy ảnh
  ///   - branchName: Tên chi nhánh
  ///   - và các thông tin khác
  static Future<List<dynamic>> getBookings() async {
    try {
      // Check if user is authenticated
      final token = await _getToken();
      if (token == null || token.isEmpty) {
        debugPrint('getBookings: No token found, user not authenticated');
        throw Exception('Vui lòng đăng nhập để xem lịch sử đặt lịch');
      }

      final endpoint = '$baseUrl/Bookings/renterbookings';
      debugPrint('getBookings: Calling endpoint: $endpoint');
      
      // Use /Bookings/renterbookings endpoint to get renter's booking history
      // Add timeout to prevent hanging
      http.Response response = await http.get(
        Uri.parse(endpoint),
        headers: await _getHeaders(requiresAuth: true, includeContentType: false),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          debugPrint('getBookings: Request timeout after 30 seconds');
          throw Exception('Kết nối quá lâu. Vui lòng kiểm tra kết nối mạng và thử lại');
        },
      );
      
      debugPrint('getBookings: Full URL called: ${response.request?.url}');

      // If 404, try alternative endpoint
      if (response.statusCode == 404) {
        debugPrint('getBookings: 404 error, trying alternative endpoint /Bookings');
        response = await http.get(
          Uri.parse('$baseUrl/Bookings'),
          headers: await _getHeaders(requiresAuth: true, includeContentType: false),
        ).timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            debugPrint('getBookings: Alternative endpoint timeout after 30 seconds');
            throw Exception('Kết nối quá lâu. Vui lòng kiểm tra kết nối mạng và thử lại');
          },
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
          final bookingsList = _findBookingList(decoded);

          if (bookingsList != null) {
            debugPrint('getBookings: Found ${bookingsList.length} bookings');
            if (bookingsList.isNotEmpty) {
              debugPrint('getBookings: First item type: ${bookingsList.first.runtimeType}');
              debugPrint('getBookings: First item keys: ${bookingsList.first is Map ? (bookingsList.first as Map).keys.toList() : "Not a Map"}');
            }
            return bookingsList;
          }

          debugPrint('getBookings: No bookings found in decoded response. Full decoded: $decoded');
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

  static List<dynamic>? _findBookingList(dynamic decoded) {
    if (decoded == null) return null;

    if (decoded is List) {
      return decoded;
    }

    if (decoded is Map<String, dynamic>) {
      const keysToCheck = [
        'items',
        'bookings',
        'data',
        'result',
        'payload',
        'cart',
        'bookingCart',
        'value',
      ];

      for (final key in keysToCheck) {
        final next = decoded[key];
        final candidate = _findBookingList(next);
        if (candidate != null) {
          return candidate;
        }
      }

      // Some responses wrap list inside other maps
      for (final value in decoded.values) {
        final candidate = _findBookingList(value);
        if (candidate != null) {
          return candidate;
        }
      }
    }

    if (decoded is Iterable) {
      for (final item in decoded) {
        final candidate = _findBookingList(item);
        if (candidate != null) {
          return candidate;
        }
      }
    }

    return null;
  }

  /// Lấy mã QR code của booking
  /// 
  /// Endpoint: GET /api/Bookings/{id}/qr
  /// 
  /// Returns: Map với các thông tin:
  ///   - bookingId: ID của booking
  ///   - payload: Payload của QR code (ví dụ: "booking:58be7af6f8484624a0a7e21c0be31032")
  ///   - pngImage: Base64 encoded PNG image của QR code
  static Future<Map<String, dynamic>> getBookingQrCode(String bookingId) async {
    try {
      final token = await _getToken();
      if (token == null || token.isEmpty) {
        throw Exception('Vui lòng đăng nhập để xem mã QR');
      }

      final endpoint = '$baseUrl/Bookings/$bookingId/qr';
      debugPrint('getBookingQrCode: Calling endpoint: $endpoint');

      final response = await http.get(
        Uri.parse(endpoint),
        headers: await _getHeaders(requiresAuth: true, includeContentType: false),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          debugPrint('getBookingQrCode: Request timeout');
          throw Exception('Kết nối quá lâu. Vui lòng thử lại');
        },
      );

      final statusCode = response.statusCode;
      final body = response.body;

      debugPrint('getBookingQrCode: Response status: $statusCode');

      if (statusCode == 401) {
        throw Exception('Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại');
      }

      if (statusCode == 404) {
        throw Exception('Không tìm thấy mã QR cho booking này');
      }

      if (statusCode >= 200 && statusCode < 300) {
        try {
          final decoded = jsonDecode(body) as Map<String, dynamic>;
          debugPrint('getBookingQrCode: Successfully retrieved QR code');
          return decoded;
        } catch (e) {
          debugPrint('getBookingQrCode: JSON decode error: $e');
          throw Exception('Không thể đọc dữ liệu QR code từ server');
        }
      }

      final errorMsg = _extractErrorMessage(body);
      throw Exception(errorMsg ?? 'Không thể lấy mã QR code (Lỗi: $statusCode)');
    } catch (e) {
      debugPrint('getBookingQrCode: Exception - ${e.toString()}');
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Không thể lấy mã QR code: ${e.toString()}');
    }
  }

  // Get bookings for a specific item (camera or accessory) to check availability
  static Future<List<Map<String, dynamic>>> getItemBookings(String itemId) async {
    try {
      // Try to get all bookings (both renter and staff if available)
      List<dynamic> allBookings = [];
      try {
        allBookings = await getBookings();
      } catch (e) {
        debugPrint('getItemBookings: Error getting renter bookings: $e');
      }
      
      // Try to get staff bookings if available (for more comprehensive availability check)
      try {
        final staffBookings = await getStaffBookings();
        allBookings.addAll(staffBookings);
      } catch (e) {
        debugPrint('getItemBookings: Error getting staff bookings (may not be staff): $e');
      }

      final itemBookings = <Map<String, dynamic>>[];

      for (final booking in allBookings) {
        if (booking is! Map<String, dynamic>) continue;
        
        // Skip cancelled bookings
        final status = booking['status']?.toString().toLowerCase();
        if (status == 'cancelled' || status == 'cancelled') {
          continue;
        }
        
        // Check if booking contains this item
        final items = booking['items'] as List<dynamic>?;
        if (items != null) {
          for (final item in items) {
            if (item is Map<String, dynamic>) {
              final itemIdFromBooking = item['cameraId']?.toString() ?? 
                                        item['itemId']?.toString() ??
                                        item['accessoryId']?.toString() ??
                                        item['id']?.toString();
              if (itemIdFromBooking == itemId) {
                itemBookings.add(booking);
                break;
              }
            }
          }
        }
      }

      // Sort by pickup date
      itemBookings.sort((a, b) {
        final pickupA = _parseDateTime(a['pickupAt']);
        final pickupB = _parseDateTime(b['pickupAt']);
        if (pickupA == null && pickupB == null) return 0;
        if (pickupA == null) return 1;
        if (pickupB == null) return -1;
        return pickupA.compareTo(pickupB);
      });

      return itemBookings;
    } catch (e) {
      debugPrint('Error fetching item bookings: $e');
      return [];
    }
  }

  // Helper to parse DateTime from various formats
  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  // Legacy method name for backward compatibility
  static Future<List<Map<String, dynamic>>> getCameraBookings(String cameraId) async {
    return getItemBookings(cameraId);
  }

  /// Lấy danh sách các khoảng thời gian không khả dụng (đã được booking) của một item
  /// 
  /// Endpoint: GET /api/Bookings/items/{itemId}/unavailable-ranges?type={type}
  /// 
  /// Parameters:
  ///   - itemId: ID của item (camera, accessory, hoặc combo)
  ///   - type: Loại item (BookingItemType.camera = 1, accessory = 2, combo = 3)
  /// 
  /// Returns: List<Map<String, dynamic>> với mỗi item chứa:
  ///   - startDate: DateTime bắt đầu
  ///   - endDate: DateTime kết thúc
  static Future<List<Map<String, dynamic>>> getUnavailableRanges(
    String itemId,
    BookingItemType type,
  ) async {
    try {
      final uri = Uri.parse('$baseUrl/Bookings/items/$itemId/unavailable-ranges')
          .replace(queryParameters: {
        'type': type.value.toString(),
      });
      
      debugPrint('getUnavailableRanges: Calling endpoint: $uri');
      debugPrint('getUnavailableRanges: itemId=$itemId, type=${type.value}');

      final response = await http.get(
        uri,
        headers: await _getHeaders(requiresAuth: true, includeContentType: false),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          debugPrint('getUnavailableRanges: Request timeout');
          throw Exception('Kết nối quá lâu. Vui lòng thử lại');
        },
      );

      final statusCode = response.statusCode;
      final body = response.body;

      debugPrint('getUnavailableRanges: Response status: $statusCode');

      // Handle authentication errors gracefully
      if (statusCode == 401) {
        debugPrint('getUnavailableRanges: 401 Unauthorized - user may not be logged in');
        return [];
      }

      if (statusCode == 404) {
        debugPrint('getUnavailableRanges: 404 Not Found - item may not exist');
        return [];
      }

      if (statusCode >= 200 && statusCode < 300) {
        if (body.isEmpty) {
          debugPrint('getUnavailableRanges: Empty response body');
          return [];
        }
        try {
          final decoded = jsonDecode(body);
          debugPrint('getUnavailableRanges: Decoded type: ${decoded.runtimeType}');
          
          // Handle different response formats
          List<dynamic> rangesList;
          if (decoded is List) {
            rangesList = decoded;
          } else if (decoded is Map<String, dynamic>) {
            // Try common keys
            const keys = ['items', 'ranges', 'unavailableRanges', 'data', 'results', 'value'];
            rangesList = [];
            for (final key in keys) {
              if (decoded.containsKey(key) && decoded[key] is List) {
                rangesList = decoded[key] as List;
                break;
              }
            }
            if (rangesList.isEmpty) {
              debugPrint('getUnavailableRanges: No list found in response map');
              return [];
            }
          } else {
            debugPrint('getUnavailableRanges: Unexpected response type');
            return [];
          }

          // Convert to List<Map<String, dynamic>>
          final result = <Map<String, dynamic>>[];
          for (final item in rangesList) {
            if (item is Map<String, dynamic>) {
              result.add(item);
            }
          }

          debugPrint('getUnavailableRanges: Found ${result.length} unavailable ranges');
          return result;
        } catch (e) {
          debugPrint('getUnavailableRanges: JSON decode error: $e');
          debugPrint('getUnavailableRanges: Response body: ${body.length > 500 ? "${body.substring(0, 500)}..." : body}');
          return [];
        }
      }

      final errorMsg = _extractErrorMessage(body);
      debugPrint('getUnavailableRanges: Error $statusCode - $errorMsg');
      
      // For errors, return empty list instead of throwing (to not break UI)
      if (statusCode >= 500) {
        debugPrint('getUnavailableRanges: Server error, returning empty list');
        return [];
      }
      
      // For client errors, also return empty list
      return [];
    } catch (e) {
      debugPrint('getUnavailableRanges: Exception - ${e.toString()}');
      // Return empty list instead of throwing to not break UI
      return [];
    }
  }

  static Future<Map<String, dynamic>> getBookingById(String id) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/Bookings/$id'),
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
        rethrow;
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

  /// Lấy hợp đồng PDF preview theo contractId
  /// 
  /// Endpoint: GET /api/Contracts/{contractId}/preview
  /// 
  /// Returns: Uint8List - PDF file bytes
  static Future<Uint8List> getContractPreview({
    required String contractId,
  }) async {
    try {
      final token = await _getToken();
      if (token == null || token.isEmpty) {
        throw Exception('Vui lòng đăng nhập để xem hợp đồng');
      }

      final endpoint = '$baseUrl/Contracts/$contractId/preview';
      debugPrint('getContractPreview: Calling endpoint: $endpoint');

      final response = await http.get(
        Uri.parse(endpoint),
        headers: await _getHeaders(requiresAuth: true),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Kết nối quá lâu. Vui lòng thử lại');
        },
      );

      final statusCode = response.statusCode;
      debugPrint('getContractPreview: Response status: $statusCode');

      if (statusCode == 401) {
        throw Exception('Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại');
      }

      if (statusCode == 404) {
        throw Exception('Không tìm thấy hợp đồng');
      }

      if (statusCode >= 200 && statusCode < 300) {
        final contentType = response.headers['content-type'] ?? '';
        final contentDisposition = response.headers['content-disposition'] ?? '';
        debugPrint('getContractPreview: Content-Type: $contentType');
        debugPrint('getContractPreview: Content-Disposition: $contentDisposition');
        
        // Backend returns PDF bytes directly via File(pdfBytes, MediaTypeNames.Application.Pdf, fileName)
        // This sets Content-Type: application/pdf and may include Content-Disposition header
        
        // Check if response is PDF file (most common case)
        if (contentType.contains('application/pdf')) {
          if (response.bodyBytes.isEmpty) {
            throw Exception('File PDF rỗng. Vui lòng thử lại.');
          }
          debugPrint('getContractPreview: Successfully retrieved PDF (${response.bodyBytes.length} bytes)');
          if (contentDisposition.isNotEmpty) {
            debugPrint('getContractPreview: PDF file with Content-Disposition: $contentDisposition');
          }
          return response.bodyBytes;
        }
        
        // Fallback: Check for octet-stream or Content-Disposition header
        if (contentType.contains('application/octet-stream') ||
            contentDisposition.toLowerCase().contains('filename') ||
            contentDisposition.toLowerCase().contains('attachment')) {
          if (response.bodyBytes.isEmpty) {
            throw Exception('File rỗng. Vui lòng thử lại.');
          }
          debugPrint('getContractPreview: Successfully retrieved file as octet-stream (${response.bodyBytes.length} bytes)');
          return response.bodyBytes;
        }
        
        // Check if response is JSON (might contain download URL - for backward compatibility)
        if (contentType.contains('application/json')) {
          try {
            final jsonData = jsonDecode(response.body);
            debugPrint('getContractPreview: Response is JSON: $jsonData');
            
            // Check for download URL in response
            String? downloadUrl;
            if (jsonData is Map<String, dynamic>) {
              downloadUrl = jsonData['downloadUrl']?.toString() ?? 
                           jsonData['url']?.toString() ?? 
                           jsonData['fileUrl']?.toString() ??
                           jsonData['previewUrl']?.toString();
            }
            
            if (downloadUrl != null && downloadUrl.isNotEmpty) {
              debugPrint('getContractPreview: Found download URL: $downloadUrl');
              // Download file from URL
              final downloadResponse = await http.get(
                Uri.parse(downloadUrl),
                headers: await _getHeaders(requiresAuth: true),
              ).timeout(
                const Duration(seconds: 60),
                onTimeout: () {
                  throw Exception('Tải file quá lâu. Vui lòng thử lại');
                },
              );
              
              if (downloadResponse.statusCode >= 200 && downloadResponse.statusCode < 300) {
                debugPrint('getContractPreview: Successfully downloaded PDF from URL (${downloadResponse.bodyBytes.length} bytes)');
                return downloadResponse.bodyBytes;
              } else {
                throw Exception('Không thể tải file từ URL: ${downloadResponse.statusCode}');
              }
            } else {
              throw Exception('Không tìm thấy URL download trong response');
            }
          } catch (e) {
            debugPrint('getContractPreview: Error parsing JSON or downloading: $e');
            throw Exception('Không thể xử lý response từ server: ${e.toString()}');
          }
        }
        
        // Final fallback: if we have bytes, try to use them
        if (response.bodyBytes.isNotEmpty) {
          debugPrint('getContractPreview: Using response bytes as PDF (${response.bodyBytes.length} bytes)');
          return response.bodyBytes;
        }
        
        throw Exception('Định dạng file không hợp lệ. Content-Type: $contentType');
      }

      final errorMsg = _extractErrorMessage(response.body);
      throw Exception(errorMsg ?? 'Không thể tải hợp đồng (Lỗi: $statusCode)');
    } catch (e) {
      debugPrint('getContractPreview: Exception - ${e.toString()}');
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Không thể tải hợp đồng: ${e.toString()}');
    }
  }

  /// Lấy thông tin hợp đồng theo contractId
  /// 
  /// Endpoint: GET /api/Contracts/{contractId}
  /// 
  /// Returns: Map với thông tin hợp đồng (bao gồm trạng thái đã ký)
  static Future<Map<String, dynamic>> getContractInfo({
    required String contractId,
  }) async {
    try {
      final token = await _getToken();
      if (token == null || token.isEmpty) {
        throw Exception('Vui lòng đăng nhập để xem hợp đồng');
      }

      final endpoint = '$baseUrl/Contracts/$contractId';
      debugPrint('getContractInfo: Calling endpoint: $endpoint');

      final response = await http.get(
        Uri.parse(endpoint),
        headers: await _getHeaders(requiresAuth: true),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Kết nối quá lâu. Vui lòng thử lại');
        },
      );

      final statusCode = response.statusCode;
      debugPrint('getContractInfo: Response status: $statusCode');

      if (statusCode == 401) {
        throw Exception('Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại');
      }

      if (statusCode == 404) {
        throw Exception('Không tìm thấy hợp đồng');
      }

      if (statusCode >= 200 && statusCode < 300) {
        final data = _handleResponse(response);
        debugPrint('getContractInfo: Successfully retrieved contract info');
        return data;
      }

      final errorMsg = _extractErrorMessage(response.body);
      throw Exception(errorMsg ?? 'Không thể lấy thông tin hợp đồng (Lỗi: $statusCode)');
    } catch (e) {
      debugPrint('getContractInfo: Exception - ${e.toString()}');
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Không thể lấy thông tin hợp đồng: ${e.toString()}');
    }
  }

  /// Lấy hợp đồng PDF đã ký theo contractId
  /// 
  /// Endpoint: GET /api/Contracts/{contractId} với Accept: application/pdf
  /// 
  /// Returns: Uint8List - PDF file bytes (có chữ ký nếu đã ký)
  static Future<Uint8List> getContractPdf({
    required String contractId,
  }) async {
    try {
      final token = await _getToken();
      if (token == null || token.isEmpty) {
        throw Exception('Vui lòng đăng nhập để xem hợp đồng');
      }

      final endpoint = '$baseUrl/Contracts/$contractId';
      debugPrint('getContractPdf: Calling endpoint: $endpoint');

      // Get headers and add Accept header for PDF
      final headers = await _getHeaders(requiresAuth: true);
      headers['Accept'] = 'application/pdf';

      final response = await http.get(
        Uri.parse(endpoint),
        headers: headers,
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Kết nối quá lâu. Vui lòng thử lại');
        },
      );

      final statusCode = response.statusCode;
      debugPrint('getContractPdf: Response status: $statusCode');

      if (statusCode == 401) {
        throw Exception('Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại');
      }

      if (statusCode == 404) {
        throw Exception('Không tìm thấy hợp đồng');
      }

      if (statusCode >= 200 && statusCode < 300) {
        final contentType = response.headers['content-type'] ?? '';
        debugPrint('getContractPdf: Content-Type: $contentType');
        debugPrint('getContractPdf: Response body length: ${response.bodyBytes.length}');
        
        // Check if response is JSON (contract info) or PDF
        if (contentType.contains('application/json')) {
          // If JSON, try to get signedFileUrl or use preview endpoint
          try {
            final contractData = jsonDecode(response.body) as Map<String, dynamic>;
            final signedFileUrl = contractData['signedFileUrl']?.toString();
            
            if (signedFileUrl != null && signedFileUrl.isNotEmpty) {
              debugPrint('getContractPdf: Found signedFileUrl, downloading: $signedFileUrl');
              // Download PDF from signedFileUrl
              final pdfResponse = await http.get(
                Uri.parse(signedFileUrl),
              ).timeout(
                const Duration(seconds: 30),
                onTimeout: () {
                  throw Exception('Kết nối quá lâu. Vui lòng thử lại');
                },
              );
              
              if (pdfResponse.statusCode >= 200 && pdfResponse.statusCode < 300) {
                debugPrint('getContractPdf: Successfully downloaded signed PDF (${pdfResponse.bodyBytes.length} bytes)');
                return pdfResponse.bodyBytes;
              }
            }
            
            // If no signedFileUrl, use preview endpoint
            debugPrint('getContractPdf: No signedFileUrl found, using preview endpoint');
            return await getContractPreview(contractId: contractId);
          } catch (e) {
            debugPrint('getContractPdf: Error parsing contract info: $e');
            // Fallback to preview
            return await getContractPreview(contractId: contractId);
          }
        }
        
        // If response is PDF
        if (contentType.contains('application/pdf') || 
            contentType.contains('application/octet-stream') ||
            response.bodyBytes.isNotEmpty) {
          debugPrint('getContractPdf: Successfully retrieved PDF (${response.bodyBytes.length} bytes)');
          return response.bodyBytes;
        } else {
          throw Exception('Định dạng file không hợp lệ. Vui lòng thử lại.');
        }
      }

      final errorMsg = _extractErrorMessage(response.body);
      throw Exception(errorMsg ?? 'Không thể tải hợp đồng (Lỗi: $statusCode)');
    } catch (e) {
      debugPrint('getContractPdf: Exception - ${e.toString()}');
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Không thể tải hợp đồng: ${e.toString()}');
    }
  }

  /// Ký hợp đồng (contract)
  /// 
  /// Endpoint: POST /api/Contracts/{contractId}/sign
  /// 
  /// Body: { "signatureBase64": "string" }
  /// 
  /// Returns: Map với thông tin hợp đồng đã ký
  static Future<Map<String, dynamic>> signContract({
    required String contractId,
    required String signatureBase64,
  }) async {
    try {
      final token = await _getToken();
      if (token == null || token.isEmpty) {
        throw Exception('Vui lòng đăng nhập để ký hợp đồng');
      }

      final endpoint = '$baseUrl/Contracts/$contractId/sign';
      debugPrint('signContract: Calling endpoint: $endpoint');

      final body = jsonEncode({
        'signatureBase64': signatureBase64,
      });

      final response = await http.post(
        Uri.parse(endpoint),
        headers: await _getHeaders(requiresAuth: true),
        body: body,
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Kết nối quá lâu. Vui lòng thử lại');
        },
      );

      final statusCode = response.statusCode;
      final responseBody = response.body;

      debugPrint('signContract: Response status: $statusCode');

      if (statusCode == 401) {
        throw Exception('Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại');
      }

      if (statusCode == 404) {
        throw Exception('Không tìm thấy hợp đồng');
      }

      if (statusCode >= 200 && statusCode < 300) {
        try {
          final decoded = jsonDecode(responseBody) as Map<String, dynamic>;
          debugPrint('signContract: Successfully signed contract');
          return decoded;
        } catch (e) {
          debugPrint('signContract: JSON decode error: $e');
          throw Exception('Không thể đọc phản hồi từ server');
        }
      }

      final errorMsg = _extractErrorMessage(responseBody);
      throw Exception(errorMsg ?? 'Không thể ký hợp đồng (Lỗi: $statusCode)');
    } catch (e) {
      debugPrint('signContract: Exception - ${e.toString()}');
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Không thể ký hợp đồng: ${e.toString()}');
    }
  }

  /// Lấy thông tin ví của người dùng hiện tại
  /// 
  /// Endpoint: GET /api/Wallets/me
  /// 
  /// Returns: Map với thông tin ví (balance, etc.)
  static Future<Map<String, dynamic>> getWalletInfo() async {
    try {
      final token = await _getToken();
      if (token == null || token.isEmpty) {
        throw Exception('Vui lòng đăng nhập để xem ví');
      }

      final endpoint = '$baseUrl/Wallets/me';
      debugPrint('getWalletInfo: Calling endpoint: $endpoint');

      final response = await http.get(
        Uri.parse(endpoint),
        headers: await _getHeaders(requiresAuth: true),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Kết nối quá lâu. Vui lòng thử lại');
        },
      );

      final statusCode = response.statusCode;
      debugPrint('getWalletInfo: Response status: $statusCode');

      if (statusCode == 401) {
        throw Exception('Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại');
      }

      if (statusCode == 404) {
        throw Exception('Không tìm thấy ví');
      }

      if (statusCode >= 200 && statusCode < 300) {
        final data = _handleResponse(response);
        debugPrint('getWalletInfo: Successfully retrieved wallet info');
        return data;
      }

      final errorMsg = _extractErrorMessage(response.body);
      throw Exception(errorMsg ?? 'Không thể lấy thông tin ví (Lỗi: $statusCode)');
    } catch (e) {
      debugPrint('getWalletInfo: Exception - ${e.toString()}');
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Không thể lấy thông tin ví: ${e.toString()}');
    }
  }

  /// Nạp tiền vào ví qua PayOS
  /// 
  /// Endpoint: POST /api/Wallets/topup
  /// 
  /// Body: { "amount": number }
  /// 
  /// Returns: String - PayOS payment URL
  static Future<String> topupWallet({
    required double amount,
  }) async {
    try {
      final token = await _getToken();
      if (token == null || token.isEmpty) {
        throw Exception('Vui lòng đăng nhập để nạp tiền');
      }

      if (amount <= 0) {
        throw Exception('Số tiền nạp phải lớn hơn 0');
      }

      final endpoint = '$baseUrl/Wallets/topup';
      debugPrint('topupWallet: Calling endpoint: $endpoint');
      debugPrint('topupWallet: Amount: $amount');

      final requestBody = jsonEncode({
        'amount': amount,
      });

      final response = await http.post(
        Uri.parse(endpoint),
        headers: await _getHeaders(requiresAuth: true),
        body: requestBody,
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Kết nối quá lâu. Vui lòng thử lại');
        },
      );

      final statusCode = response.statusCode;
      final body = response.body;
      debugPrint('topupWallet: Response status: $statusCode');
      debugPrint('topupWallet: Response body: ${body.isNotEmpty ? (body.length > 500 ? "${body.substring(0, 500)}..." : body) : "empty"}');

      if (statusCode == 401) {
        throw Exception('Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại');
      }

      if (statusCode >= 200 && statusCode < 300) {
        if (body.isEmpty) {
          throw Exception('Không nhận được URL thanh toán từ server');
        }

        try {
          // API may return payment URL string directly (as JSON string)
          final decoded = jsonDecode(body);
          String? paymentUrl;

          if (decoded is String) {
            paymentUrl = decoded.replaceAll('"', '').replaceAll("'", '').trim();
          } else if (decoded is Map<String, dynamic>) {
            // Try multiple possible field names for payment URL
            paymentUrl = decoded['url']?.toString() ??
                        decoded['paymentUrl']?.toString() ??
                        decoded['payosUrl']?.toString() ??
                        decoded['checkoutUrl']?.toString() ??
                        decoded['payosCheckoutUrl']?.toString() ??
                        decoded['link']?.toString() ??
                        decoded['paymentLink']?.toString();
          }

          if (paymentUrl != null && paymentUrl.isNotEmpty) {
            final cleanedUrl = paymentUrl.replaceAll('"', '').replaceAll("'", '').trim();
            debugPrint('topupWallet: Payment URL received: $cleanedUrl');
            return cleanedUrl;
          } else {
            throw Exception('Không tìm thấy URL thanh toán trong phản hồi');
          }
        } catch (e) {
          debugPrint('topupWallet: Error parsing response: $e');
          // Try using body as string directly
          final trimmedBody = body.trim();
          if (trimmedBody.startsWith('"') && trimmedBody.endsWith('"')) {
            return trimmedBody.substring(1, trimmedBody.length - 1);
          }
          return trimmedBody;
        }
      }

      final errorMsg = _extractErrorMessage(body);
      throw Exception(errorMsg ?? 'Không thể nạp tiền (Lỗi: $statusCode)');
    } catch (e) {
      debugPrint('topupWallet: Exception - ${e.toString()}');
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Không thể nạp tiền: ${e.toString()}');
    }
  }
}
