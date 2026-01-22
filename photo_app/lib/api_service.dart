import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:photo_app/models/promotion.dart';
import 'package:photo_app/models/featured_content.dart'; // Nouvelle importation
 // Nouvelle importation


class ApiService {
  // Base URL de votre API Spring Boot
  // Assurez-vous que cette URL pointe vers votre instance de backend Spring Boot.
  // 10.0.2.2 est l'alias pour localhost sur un émulateur Android.
  // Le port 8080 est le port par défaut de Spring Boot.
  static const String baseUrl = 'http://109.176.197.158:8080/api';

  /// Méthode privée pour effectuer une requête GET sécurisée
  static Future<http.Response> _safeGet(String url) async {
    try {
      return await http.get(Uri.parse(url)).timeout(
            const Duration(seconds: 15), // Délai d'attente de 15 secondes
            onTimeout: () => throw Exception(
                'Délai dépassé. Impossible de joindre le serveur.'),
          );
    } catch (error) {
      throw Exception('Erreur réseau : Impossible de se connecter au serveur. Vérifiez votre connexion et l\'adresse du serveur.');
    }
  }

  /// Méthode privée pour effectuer une requête POST sécurisée avec un corps JSON.
  /// Elle gère également les timeouts et les erreurs réseau.
  static Future<http.Response> _safePost(String url, Map<String, dynamic> body) async {
    try {
      return await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json; charset=UTF-8'}, // Spécifie le type de contenu JSON
        body: jsonEncode(body), // Convertit le Map en chaîne JSON
      ).timeout(
        const Duration(seconds: 15), // Délai d'attente de 15 secondes
        onTimeout: () => throw Exception('Délai dépassé. Impossible de joindre le serveur.'),
      );
    } catch (error) {
      // Gestion améliorée des erreurs réseau pour fournir un feedback plus clair.
      throw Exception('Erreur réseau : Impossible de se connecter au serveur. Vérifiez votre connexion et l\'adresse du serveur.');
    }
  }

  /// Méthode pour gérer et interpréter les réponses de l'API.
  /// Elle vérifie le code de statut HTTP et tente de décoder les messages d'erreur JSON.
  static Map<String, dynamic> _handleResponse(http.Response response) {
    // Si le statut HTTP n'est pas 200 (OK), cela indique une erreur.
    if (response.statusCode != 200) {
      try {
        final errorBody = jsonDecode(response.body);
        // Tente d'extraire un message d'erreur du corps de la réponse JSON.
        final errorMessage = errorBody['message'] ?? 'Erreur inconnue du serveur.';
        throw Exception('Erreur ${response.statusCode}: $errorMessage');
      } catch (e) {
        // Si le corps n'est pas un JSON valide ou est vide, utilise le message de raison HTTP.
        throw Exception('Erreur serveur. Code: ${response.statusCode}, Message: ${response.reasonPhrase}');
      }
    }

    // Si la réponse est OK (200), nous supposons un succès et décodons la réponse.
    final Map<String, dynamic> responseData = jsonDecode(response.body);

    // Votre backend Spring Boot renvoie un token en cas de succès d'authentification/inscription.
    // Cette logique vérifie la présence de ce token. Ajustez si la structure de succès de votre API est différente.
    if (responseData.containsKey('token')) {
      return responseData;
    } else {
       // Cas où le statut est 200 mais le corps ne contient pas le token attendu ou a une structure inattendue.
       final errorMessage = responseData['message'] ?? 'La réponse du serveur est invalide.';
       throw Exception(errorMessage);
    }
  }

  /// Méthode pour la connexion d'un utilisateur.
  /// Elle envoie les informations d'identification au endpoint d'authentification du backend.
  static Future<Map<String, dynamic>> login(String email, String password) async {
    const url = '$baseUrl/auth/authenticate'; // Endpoint de connexion du backend
    final body = {'email': email, 'password': password};

    final response = await _safePost(url, body);
    return _handleResponse(response);
  }

  /// Méthode pour l'inscription d'un nouvel utilisateur.
  /// Elle adapte les champs d'entrée de Flutter (`name`) aux attentes du backend (`firstname`, `lastname`).
  static Future<Map<String, dynamic>> signup(String name, String email, String password) async {
    const url = '$baseUrl/auth/register'; // Endpoint d'inscription du backend
    
    // Logique pour diviser le champ 'name' en 'firstname' et 'lastname'.
    // Si le nom contient un espace, il est divisé. Sinon, le 'name' entier est utilisé comme 'firstname'.
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
    return _handleResponse(response);
  }

  /// Méthode pour récupérer les images de l'album
  static Future<List<String>> getAlbumImages(int userId) async {
    final url = '$baseUrl/album/images?user_id=$userId';
    final response = await _safeGet(url);
    final data = _handleResponse(response);
    return List<String>.from(data['images']);
  }

  /// Méthode pour récupérer toutes les promotions actives
  static Future<List<Promotion>> fetchPromotions() async {
    const url = '$baseUrl/promotions';
    try {
      final response = await _safeGet(url);
      final List<dynamic> responseData = jsonDecode(response.body);
      return responseData.map((json) => Promotion.fromJson(json)).toList();
    } catch (error) {
      throw Exception('Erreur lors de la récupération des promotions : $error');
    }
  }

  /// Méthode pour récupérer le contenu mis en avant actif
  static Future<FeaturedContent> fetchFeaturedContent() async {
    const url = '$baseUrl/featured-content/active';
    try {
      final response = await _safeGet(url);
      final Map<String, dynamic> responseData = jsonDecode(response.body);
      return FeaturedContent.fromJson(responseData);
    } catch (error) {
      throw Exception('Erreur lors de la récupération du contenu mis en avant : $error');
    }
  }
}