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
  static SharedPreferences? _preferences;

  // User details
  static String? _authToken;
  static int? _userId;
  static String? _userName;
  static String? _userLastName;
  static String? _userEmail;

  static Future<void> init() async {
    _preferences = await SharedPreferences.getInstance();
    _authToken = _preferences?.getString('authToken');
    _userId = _preferences?.getInt('userId');
    _userName = _preferences?.getString('userName');
    _userLastName = _preferences?.getString('userLastName');
    _userEmail = _preferences?.getString('userEmail');
  }

  // Getters for user details
  static String? get authToken => _authToken;
  static int? get userId => _userId;
  static String? get userName => _userName;
  static String? get userLastName => _userLastName;
  static String? get userEmail => _userEmail;

  static Future<void> saveAuthDetails(Map<String, dynamic> authData) async {
    _authToken = authData['token'];
    _userId = authData['id'];
    _userName = authData['firstname'];
    _userLastName = authData['lastname'];
    _userEmail = authData['email'];

    await _preferences?.setString('authToken', _authToken!);
    await _preferences?.setInt('userId', _userId!);
    await _preferences?.setString('userName', _userName!);
    await _preferences?.setString('userLastName', _userLastName!);
    await _preferences?.setString('userEmail', _userEmail!);
  }

  static Future<void> clearAuthDetails() async {
    _authToken = null;
    _userId = null;
    _userName = null;
    _userLastName = null;
    _userEmail = null;
    await _preferences?.remove('authToken');
    await _preferences?.remove('userId');
    await _preferences?.remove('userName');
    await _preferences?.remove('userLastName');
    await _preferences?.remove('userEmail');
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
        final errorMessage = errorBody['message'] ?? 'Erreur inconnue du serveur.';
        throw Exception('Erreur ${response.statusCode}: $errorMessage');
      } catch (e) {
        throw Exception('Erreur serveur. Code: ${response.statusCode}, Message: ${response.reasonPhrase}');
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
    return List<String>.from(data['images']);
  }

  static Future<List<Promotion>> fetchPromotions() async {
    const url = '$baseUrl/promotions';
    final response = await _safeGet(url);
    final List<dynamic> responseData = _handleApiResponse(response);
    return responseData.map((json) => Promotion.fromJson(json)).toList();
  }

    static Future<List<PhotoFormat>> fetchDimensions() async {
    const url = '$baseUrl/public/dimensions';
    final response = await _safeGet(url);
    final List<dynamic> responseData = _handleApiResponse(response);
    return responseData.map((json) => PhotoFormat.fromJson(json)).toList();
  }


  static Future<FeaturedContent> fetchFeaturedContent() async {
    const url = '$baseUrl/featured-content/active';
    final response = await _safeGet(url);
    final Map<String, dynamic> responseData = _handleApiResponse(response);
    return FeaturedContent.fromJson(responseData);
  }

  static Future<Booking> createBooking(Booking booking) async {
    const url = '$baseUrl/bookings';
    final response = await _safePost(url, booking.toJson());
    final Map<String, dynamic> responseData = _handleApiResponse(response);
    return Booking.fromJson(responseData);
  }

  static Future<List<Booking>> fetchUserBookings() async {
    const url = '$baseUrl/bookings';
    final response = await _safeGet(url);
    final List<dynamic> responseData = _handleApiResponse(response);
    return responseData.map((json) => Booking.fromJson(json)).toList();
  }

  static Future<ContactInfo> fetchContactInfo() async {
    const url = '$baseUrl/public/contact-info'; // Endpoint to fetch contact info
    final response = await _safeGet(url);
    final Map<String, dynamic> responseData = _handleApiResponse(response);
    return ContactInfo.fromJson(responseData);
  }

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

  static Future<void> resetPasswordWithToken({required String token, required String newPassword}) async {
    const url = '$baseUrl/auth/reset-password';
    final body = {
      'token': token,
      'newPassword': newPassword,
    };
    final response = await _safePost(url, body);
    _handleApiResponse(response); // Expects no content on success
  }

  static Future<Order> createOrder(Map<String, dynamic> orderDetails) async {
    const url = '$baseUrl/orders';
    final response = await _safePost(url, orderDetails);
    return Order.fromJson(_handleApiResponse(response));
  }

  static Future<List<Order>> fetchMyOrders() async {
    const url = '$baseUrl/orders/my-orders';
    final response = await _safeGet(url);
    final List<dynamic> responseData = _handleApiResponse(response);
    return responseData.map((json) => Order.fromJson(json)).toList();
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

  static Future<String> initiateFedapayPayment(Map<String, dynamic> orderPayload) async {
    const url = '$baseUrl/payments/fedapay/initiate';
    final response = await _safePost(url, orderPayload);
    final responseData = _handleApiResponse(response);
    if (responseData != null && responseData.containsKey('paymentUrl')) {
      return responseData['paymentUrl'];
    } else {
      throw Exception('Failed to initiate Fedapay payment: Invalid response from server.');
    }
  }

  static Future<String> initiatePaydunyaPayment(Map<String, dynamic> orderPayload) async {
    const url = '$baseUrl/payments/paydunya/initiate';
    final response = await _safePost(url, orderPayload);
    final responseData = _handleApiResponse(response);
    if (responseData != null && responseData.containsKey('paymentUrl')) {
      return responseData['paymentUrl'];
    } else {
      throw Exception('Failed to initiate PayDunya payment: Invalid response from server.');
    }
  }
}

