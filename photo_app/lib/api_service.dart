import 'dart:convert';
import 'package:Picon/models/booking.dart';
import 'package:Picon/models/contact_info.dart';
import 'package:Picon/models/featured_content.dart';
import 'package:Picon/models/photo_format.dart';
import 'package:Picon/models/order.dart';
import 'package:Picon/models/promotion.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';


class ApiService {
  static const String baseUrl = 'http://109.176.197.158:8080/api';
  static const String rootUrl = 'http://109.176.197.158:8080';
  static SharedPreferences? _preferences;

  // User details
  static String? _authToken;
  static int? _userId;
  static String? _userName;
  static String? _userLastName;
  static String? _userEmail;
  static String? _userPhone;
  // Pending payment data
  static Map<String, Map<String, dynamic>>? _pendingOrderDetails;
  static Map<String, double>? _pendingPrices;
  static String? _pendingPaymentMethod;
  static String? _pendingOrderId;
  // Flag pour demander la réinitialisation du panier dans HomeScreen
  static bool shouldClearCart = false;

  static Future<void> init() async {
    _preferences = await SharedPreferences.getInstance();
    _authToken = _preferences?.getString('authToken');
    _userId = _preferences?.getInt('userId');
    _userName = _preferences?.getString('userName');
    _userLastName = _preferences?.getString('userLastName');
    _userEmail = _preferences?.getString('userEmail');
    _userPhone = _preferences?.getString('userPhone');
  }

  // Getters for user details
  static String? get authToken => _authToken;
  static int? get userId => _userId;
  static String? get userName => _userName;
  static String? get userLastName => _userLastName;
  static String? get userEmail => _userEmail;
  static String? get userPhone => _userPhone;
  static Map<String, Map<String, dynamic>>? get pendingOrderDetails =>
      _pendingOrderDetails;
  static Map<String, double>? get pendingPrices => _pendingPrices;
  static String? get pendingPaymentMethod => _pendingPaymentMethod;
  static String? get pendingOrderId => _pendingOrderId;

  static void setPendingPayment({
    required Map<String, Map<String, dynamic>> orderDetails,
    required Map<String, double> prices,
    required String paymentMethod,
    required String orderId,
  }) {
    _pendingOrderDetails = Map<String, Map<String, dynamic>>.from(orderDetails);
    _pendingPrices = Map<String, double>.from(prices);
    _pendingPaymentMethod = paymentMethod;
    _pendingOrderId = orderId;
  }

  static void clearPendingPayment() {
    _pendingOrderDetails = null;
    _pendingPrices = null;
    _pendingPaymentMethod = null;
    _pendingOrderId = null;
    shouldClearCart = true; // Signale à HomeScreen de vider le panier
  }

  static Future<void> saveAuthDetails(Map<String, dynamic> authData) async {
    _authToken = authData['token'];
    _userId = authData['id'];
    _userName = authData['firstname'];
    _userLastName = authData['lastname'];
    _userEmail = authData['email'];
    _userPhone = authData['phone'];

    await _preferences?.setString('authToken', _authToken!);
    await _preferences?.setInt('userId', _userId!);
    await _preferences?.setString('userName', _userName!);
    await _preferences?.setString('userLastName', _userLastName!);
    await _preferences?.setString('userEmail', _userEmail!);
    if (_userPhone != null) await _preferences?.setString('userPhone', _userPhone!);
  }

  static Future<void> clearAuthDetails() async {
    _authToken = null;
    _userId = null;
    _userName = null;
    _userLastName = null;
    _userEmail = null;
    _userPhone = null;
    await _preferences?.remove('authToken');
    await _preferences?.remove('userId');
    await _preferences?.remove('userName');
    await _preferences?.remove('userLastName');
    await _preferences?.remove('userEmail');
    await _preferences?.remove('userPhone');
  }

  static Map<String, String> get _headers {
    final Map<String, String> headers = {
      'Content-Type': 'application/json; charset=UTF-8',
    };
    if (_authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
    }
    return headers;
  }

  /// Méthode privée pour effectuer une requête GET sécurisée
  static Future<http.Response> _safeGet(String url) async {
    try {
      return await http.get(Uri.parse(url), headers: _headers).timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw Exception(
                'Délai dépassé. Impossible de joindre le serveur.'),
          );
    } catch (error) {
      throw Exception('Erreur réseau : Impossible de se connecter au serveur. Vérifiez votre connexion et l\'adresse du serveur.');
    }
  }

  /// Méthode privée pour effectuer une requête POST sécurisée avec un corps JSON.
  static Future<http.Response> _safePost(String url, Map<String, dynamic> body) async {
    try {
      return await http.post(
        Uri.parse(url),
        headers: _headers,
        body: jsonEncode(body),
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception('Délai dépassé. Impossible de joindre le serveur.'),
      );
    } catch (error) {
      throw Exception('Erreur réseau : Impossible de se connecter au serveur. Vérifiez votre connexion et l\'adresse du serveur.');
    }
  }

  /// Méthode générique pour gérer les réponses de l'API (erreurs HTTP et décodage JSON).
  static dynamic _handleApiResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isNotEmpty) {
        return jsonDecode(response.body);
      }
      return null; // No content
    } else {
      try {
        final errorBody = jsonDecode(response.body);
        final errorMessage = errorBody['message'];
        if (errorMessage != null && errorMessage.isNotEmpty) {
          throw Exception(errorMessage);
        }
        throw Exception('Erreur serveur (${response.statusCode})');
      } catch (e) {
        if (e is Exception && !e.toString().contains('jsonDecode')) {
          rethrow;
        }
        throw Exception('Erreur serveur. Code: ${response.statusCode}');
      }
    }
  }

  /// Méthode spécifique pour gérer les réponses d'authentification.
  static Map<String, dynamic> _handleAuthResponse(http.Response response) {
    final responseData = _handleApiResponse(response);
    if (responseData != null && responseData.containsKey('token')) {
      return responseData;
    } else {
      throw Exception(responseData['message'] ?? 'La réponse du serveur est invalide ou ne contient pas de jeton.');
    }
  }

  static Future<Map<String, dynamic>?> getAuthDetails() async {
    const url = '$baseUrl/auth/me'; // Most backends have a /me or /profile endpoint
    try {
      final response = await _safeGet(url);
      if (response.statusCode == 200) {
        final details = _handleApiResponse(response);
        if (details != null) {
          // Update local cache
          _userName = details['firstname'];
          _userLastName = details['lastname'];
          _userEmail = details['email'];
          _userPhone = details['phone'];
          
          await _preferences?.setString('userName', _userName ?? '');
          await _preferences?.setString('userLastName', _userLastName ?? '');
          await _preferences?.setString('userEmail', _userEmail ?? '');
          await _preferences?.setString('userPhone', _userPhone ?? '');
        }
        return details;
      }
    } catch (e) {
      // Erreur lors de la récupération des infos utilisateur — ignorée silencieusement
    }
    return null;
  }

  static Future<Map<String, dynamic>> login({String? email, String? phone, required String password}) async {
    const url = '$baseUrl/auth/authenticate';
    final Map<String, dynamic> body = {'password': password};

    if (email != null && email.isNotEmpty) {
      body['email'] = email;
    } else if (phone != null && phone.isNotEmpty) {
      body['phone'] = phone;
    } else {
      throw Exception('Email ou numéro de téléphone requis pour la connexion.');
    }

    final response = await _safePost(url, body);
    return _handleAuthResponse(response);
  }

  static Future<Map<String, dynamic>> signup(String name, String email, String phone, String password, String pin) async {
    const url = '$baseUrl/auth/register';
    
    String firstname = name;
    String lastname = '';
    if (name.contains(' ')) {
      final parts = name.split(' ');
      firstname = parts.first;
      lastname = parts.sublist(1).join(' ');
    }

    final body = {
      'firstname': firstname,
      'lastname': lastname,
      'email': email,
      'phone': phone,
      'password': password,
      'pin': pin
    };

    final response = await _safePost(url, body);
    return _handleAuthResponse(response);
  }

  static Future<void> forgotPassword(String email) async {
    const url = '$baseUrl/auth/forgot-password';
    final body = {'email': email};
    final response = await _safePost(url, body);
    _handleApiResponse(response);
  }

  static Future<List<String>> getAlbumImages(int userId) async {
    final url = '$baseUrl/album/images'; // Backend should infer user from token
    final response = await _safeGet(url);
    final data = _handleApiResponse(response);
    if (data == null || data['images'] == null) return [];
    return List<String>.from(data['images']);
  }

  static Future<List<Promotion>> fetchPromotions() async {
    const url = '$baseUrl/promotions';
    final response = await _safeGet(url);
    final responseData = _handleApiResponse(response);
    if (responseData == null) return [];
    final List<dynamic> list = responseData as List<dynamic>;
    return list.map((json) => Promotion.fromJson(json)).toList();
  }

    static Future<List<PhotoFormat>> fetchDimensions() async {
    const url = '$baseUrl/public/dimensions';
    final response = await _safeGet(url);
    final responseData = _handleApiResponse(response);
    if (responseData == null) return [];
    final List<dynamic> list = responseData as List<dynamic>;
    return list.map((json) => PhotoFormat.fromJson(json)).toList();
  }


  static Future<FeaturedContent> fetchFeaturedContent() async {
    const url = '$baseUrl/featured-content/active';
    final response = await _safeGet(url);
    final Map<String, dynamic> responseData = _handleApiResponse(response);
    return FeaturedContent.fromJson(responseData);
  }

  static Future<Booking> createBooking(Booking booking) async {
    const url = '$baseUrl/bookings';
    final body = {
      'title': booking.title,
      'description': booking.description,
      'userId': booking.userId,
      'startTime': booking.startTime.toIso8601String(),
      'endTime': booking.endTime.toIso8601String(),
      'status': booking.status.name.toUpperCase(),
      'type': _bookingTypeToJson(booking.type),
      'amount': booking.amount,
      'notes': booking.notes,
    };
    final response = await _safePost(url, body);
    final Map<String, dynamic> responseData = _handleApiResponse(response);
    return Booking.fromRawJson(responseData);
  }

  static String _bookingTypeToJson(BookingType type) {
    switch (type) {
      case BookingType.photoSession: return 'PHOTO_SESSION';
      case BookingType.event:        return 'EVENT';
      case BookingType.portrait:     return 'PORTRAIT';
      case BookingType.product:      return 'PRODUCT';
      case BookingType.other:        return 'OTHER';
    }
  }


// fetch user bookings
  static Future<List<Booking>> fetchUserBookings() async {
    const url = '$baseUrl/bookings';
    final response = await _safeGet(url);
    final responseData = _handleApiResponse(response);
    if (responseData == null) return [];
    final List<dynamic> list = responseData as List<dynamic>;
    return list.map((json) => Booking.fromRawJson(json as Map<String, dynamic>)).toList();
  }

  // fetch active featured contents
  static Future<List<FeaturedContent>> fetchActiveFeaturedContents() async {
    const url = '$baseUrl/featured-content';
    final response = await _safeGet(url);
    final dynamic data = _handleApiResponse(response);
    if (data == null) return [];
    final list = data as List<dynamic>;
    return list
        .map((e) => FeaturedContent.fromJson(e as Map<String, Object?>))
        .where((fc) => fc.active)
        .toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));
  }


// fetch contact info
  static Future<ContactInfo> fetchContactInfo() async {
    const url = '$baseUrl/public/contact-info'; // Endpoint to fetch contact info
    final response = await _safeGet(url);
    final Map<String, dynamic> responseData = _handleApiResponse(response);
    return ContactInfo.fromJson(responseData);
  }


// verify pin for password reset  
  static Future<Map<String, dynamic>> verifyPinForPasswordReset({String? email, String? phone, required String pin}) async {
    const url = '$baseUrl/auth/verify-pin';
    final Map<String, dynamic> body = {'pin': pin};

    if (email != null && email.isNotEmpty) {
      body['identifier'] = email;
    } else if (phone != null && phone.isNotEmpty) {
      body['identifier'] = phone;
    } else {
      throw Exception('Email ou numéro de téléphone requis pour la vérification du code PIN.');
    }

    final response = await _safePost(url, body);
    return _handleApiResponse(response); // Expects { "resetToken": "..." }
  }

  // reset password with token  
  static Future<void> resetPasswordWithToken({required String token, required String newPassword}) async {
    const url = '$baseUrl/auth/reset-password';
    final body = {
      'token': token,
      'newPassword': newPassword,
    };
    final response = await _safePost(url, body);
    _handleApiResponse(response); // Expects no content on success
  }

  // create order
  static Future<Order> createOrder(Map<String, dynamic> orderDetails) async {
    const url = '$baseUrl/orders';
    final response = await _safePost(url, orderDetails);
    return Order.fromJson(_handleApiResponse(response));
  }

  // fetch my orders
  static Future<List<Order>> fetchMyOrders() async {
    const url = '$baseUrl/orders/my-orders';
    final response = await _safeGet(url);
    final responseData = _handleApiResponse(response);
    if (responseData == null) return [];
    final List<dynamic> list = responseData as List<dynamic>;
    return list.map((json) => Order.fromJson(json)).toList();
  }

  // fetch order by id
  static Future<Order?> fetchOrderById(String orderId) async {
    final url = '$baseUrl/orders/$orderId';
    try {
      final response = await _safeGet(url);
      if (response.statusCode == 200) {
        final responseData = _handleApiResponse(response);
        return Order.fromJson(responseData);
      }
    } catch (e) {
      return null;
    }
    return null;
  }

  // cancel order
  static Future<void> cancelOrder(int orderId) async {
    final url = '$baseUrl/orders/$orderId/cancel';
    final response = await _safePost(url, {});
    _handleApiResponse(response);
  }

  // update order
  static Future<Order> updateOrder(int orderId, Map<String, dynamic> updates) async {
    final url = '$baseUrl/orders/$orderId';
    final response = await http.put(
      Uri.parse(url),
      headers: _headers,
      body: jsonEncode(updates),
    ).timeout(const Duration(seconds: 15));
    return Order.fromJson(_handleApiResponse(response));
  }

  static Future<List<String>> uploadPhotos(List<dynamic> imageFiles) async {
    const url = '$baseUrl/orders/upload';
    final request = http.MultipartRequest('POST', Uri.parse(url));

    // Add headers, especially the authorization token
    request.headers.addAll({
      'Authorization': 'Bearer $_authToken',
    });

    // Add userId to the request fields
    if (_userId != null) {
      request.fields['userId'] = _userId.toString();
    } else {
      throw Exception('User not authenticated. Cannot upload photos.');
    }

    // Add files to the request
    for (var imageFile in imageFiles) {
      request.files.add(await http.MultipartFile.fromPath(
        'files', // This key should match the backend's @RequestParam name
        imageFile.path,
      ));
    }

    try {
      final streamedResponse = await request.send().timeout(const Duration(minutes: 2));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final responseData = jsonDecode(response.body);
        // Assuming the backend returns a JSON object with a key 'urls' which is a list of strings
        if (responseData is Map && responseData.containsKey('urls')) {
          return List<String>.from(responseData['urls']);
        } else {
          throw Exception('Invalid response format from server.');
        }
      } else {
        throw Exception('Failed to upload photos. Server responded with status code ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error uploading photos: $e');
    }
  }

  static Future<Map<String, dynamic>> initiateFedapayPayment(Map<String, dynamic> orderPayload) async {
    const url = '$baseUrl/payments/fedapay/initiate';
    final response = await _safePost(url, orderPayload);
    final responseData = _handleApiResponse(response);
    if (responseData != null && responseData.containsKey('paymentUrl')) {
      return {
        'paymentUrl': responseData['paymentUrl'],
        'orderId': responseData['orderId']?.toString() ?? '',
        'deliveryAddress': orderPayload['deliveryAddress'],
      };
    } else {
      throw Exception('Failed to initiate Fedapay payment: Invalid response from server.');
    }
  }

  static Future<Map<String, dynamic>> verifyFedapayTransaction(String transactionId) async {
    final url = '$baseUrl/payments/fedapay/verify?id=$transactionId';
    final response = await _safeGet(url);
    final responseData = _handleApiResponse(response);
    if (responseData != null) {
      return responseData as Map<String, dynamic>;
    } else {
      throw Exception('Failed to verify Fedapay transaction.');
    }
  }

}

