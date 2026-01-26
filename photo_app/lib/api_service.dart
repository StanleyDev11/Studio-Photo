import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:photo_app/models/promotion.dart';
import 'package:photo_app/models/featured_content.dart';
import 'package:photo_app/models/booking.dart';
import 'package:shared_preferences/shared_preferences.dart';


class ApiService {
  static const String baseUrl = 'http://109.176.197.158:8080/api';
  static SharedPreferences? _preferences;
  static String? _authToken;
  static int? _userId;

  static Future<void> init() async {
    _preferences = await SharedPreferences.getInstance();
    _authToken = _preferences?.getString('authToken');
    _userId = _preferences?.getInt('userId');
  }

  static String? get authToken => _authToken;
  static int? get userId => _userId;

  static Future<void> saveAuthTokenAndUserId(String token, int userId) async {
    _authToken = token;
    _userId = userId;
    await _preferences?.setString('authToken', token);
    await _preferences?.setInt('userId', userId);
  }

  static Future<void> removeAuthTokenAndUserId() async {
    _authToken = null;
    _userId = null;
    await _preferences?.remove('authToken');
    await _preferences?.remove('userId');
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

  static Future<Map<String, dynamic>> signup(String name, String email, String password) async {
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
      'password': password
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
    final url = '$baseUrl/bookings';
    final response = await _safeGet(url);
    final List<dynamic> responseData = _handleApiResponse(response);
    return responseData.map((json) => Booking.fromJson(json)).toList();
  }
}
