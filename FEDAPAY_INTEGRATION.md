# Intégration de Fedapay pour la Commande de Photos

Ce document résume les modifications apportées pour intégrer Fedapay comme méthode de paiement dans l'application mobile et le backend, ainsi que pour gérer les webhooks Fedapay.

## Application Mobile (Flutter - `photo_app`)

### `pubspec.yaml`
*   **Modification:** Ajout de la dépendance `fedapay_flutter`.
    ```yaml
    dependencies:
      # ...
      fedapay_flutter: ^0.0.1 # Version à vérifier pour la dernière stable
    ```

### `photo_app/lib/api_service.dart`
*   **Modification:** Ajout de la méthode statique `initiateFedapayPayment`.
*   **Rôle:** Cette méthode est responsable d'envoyer les détails de la commande au backend pour initier un paiement Fedapay et de récupérer l'URL de paiement.
    ```dart
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
    ```

### `photo_app/lib/payment_selection_screen.dart`
*   **Modification:**
    *   Ajout de "Fedapay Sandbox" à la liste `_paymentMethods` avec un logo et une description appropriés.
    *   Initialisation de `FedaFlutter` dans `initState()` avec les clés publiques et secrètes fournies par l'utilisateur.
    *   Mise à jour du constructeur pour accepter `totalAmount` et `isExpress` comme paramètres requis.
    *   Modification de la fonction `_processPayment()` pour gérer le flux Fedapay:
        *   Si `_selectedMethodName` est "Fedapay Sandbox", l'application appelle `ApiService.initiateFedapayPayment()` et lance l'URL de paiement reçue via `url_launcher`.
        *   L' `orderPayload` passé au backend inclut maintenant `widget.totalAmount` et `widget.isExpress`.
    *   L'import `package:fedapay_flutter/fedapay_flutter.dart` a été ajouté.

### `photo_app/lib/order_summary_screen.dart`
*   **Modification:** Mise à jour de la navigation vers `PaymentSelectionScreen` pour passer les valeurs calculées `_totalPrice` et `widget.isExpress`.
    ```dart
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            PaymentSelectionScreen(
              orderDetails: _editableOrderDetails,
              totalAmount: _totalPrice, // Pass total price
              isExpress: widget.isExpress, // Pass express delivery status
            ),
      ),
    );
    ```

## Backend (Spring Boot - `photo_app_backend`)

### Structure du projet
*   **Nouveau package:** Création du package `com.studiophoto.photoappbackend.payment`.

### `photo_app_backend/src/main/java/com/studiophoto/photoappbackend/payment/FedapayInitiateRequest.java`
*   **Nouveau fichier / Modification:** Ajout du champ `totalAmount` de type `BigDecimal`.
*   **Rôle:** DTO pour recevoir les détails de la commande (y compris le montant total calculé par le mobile) pour l'initiation du paiement Fedapay.

### `photo_app_backend/src/main/java/com/studiophoto/photoappbackend/payment/FedapayInitiateResponse.java`
*   **Nouveau fichier:** DTO pour renvoyer l'URL de paiement Fedapay au mobile.

### `photo_app_backend/src/main/java/com/studiophoto/photoappbackend/payment/FedapayService.java`
*   **Nouveau fichier / Modification:**
    *   **Injection:** `RestTemplate` et `UserRepository` ont été injectés.
    *   **Clés API:** Les clés publiques et secrètes Fedapay sont définies (actuellement en dur, **TODO: à sécuriser**).
    *   **`initiatePayment()`:**
        *   Récupère l'utilisateur à partir de l'`userId` de la requête.
        *   Crée une commande "en attente de paiement" (`OrderStatus.PENDING_PAYMENT`) dans la base de données via `orderService.createPendingOrderForFedapay()`.
        *   Construit la charge utile (`transactionPayload`) pour l'API Fedapay, incluant :
            *   Le montant total (`request.getTotalAmount().intValue()`).
            *   La devise ("XOF").
            *   Une description incluant l'ID de la commande interne (`"Payment for Photo Order #<orderId>"`), essentielle pour le webhook.
            *   Des informations client extraites de l'objet `User`.
            *   `callback_url` et `cancel_url` (actuellement des placeholders, **TODO: à remplacer**).
        *   Effectue un appel HTTP `POST` réel à l'API Fedapay (`https://sandbox-api.fedapay.com/v1/transactions`) avec Basic Authentication (clé secrète).
        *   Parse la réponse de Fedapay pour extraire et retourner l'`payment_url`.

### `photo_app_backend/src/main/java/com/studiophoto/photoappbackend/payment/PaymentController.java`
*   **Nouveau fichier:**
    *   **Endpoint:** Expose un point de terminaison `@PostMapping("/api/payments/fedapay/initiate")`.
    *   **Rôle:** Reçoit le `FedapayInitiateRequest` du mobile, appelle `fedapayService.initiatePayment()`, et renvoie le `FedapayInitiateResponse`.

### `photo_app_backend/src/main/java/com/studiophoto/photoappbackend/payment/FedapayWebhookController.java`
*   **Nouveau fichier:**
    *   **Endpoint:** Expose un point de terminaison `@PostMapping("/api/payments/fedapay/webhook")`.
    *   **Rôle:** Reçoit les notifications de webhook de Fedapay.
    *   **Vérification de signature:** Comprend un placeholder pour la vérification de la signature du webhook (**TODO: à implémenter**).
    *   **Traitement du payload:** Parse le JSON du webhook pour extraire le statut de la transaction Fedapay et l'ID de commande interne (à partir de la description).
    *   **Mise à jour de la commande:** Utilise `orderService.updateOrderStatusAndPaymentMethod()` pour mettre à jour le statut de la commande dans la base de données (`PROCESSING`, `CANCELLED`, etc.) et définir le mode de paiement sur "Fedapay".

### `photo_app_backend/src/main/java/com/studiophoto/photoappbackend/order/Order.java`
*   **Modification:** Le champ `paymentMethod` est rendu nullable (`@Column` sans `nullable = false`).
    *   **Raison:** Le mode de paiement n'est pas connu au moment de la création initiale de la commande "en attente de paiement" pour Fedapay.

### `photo_app_backend/src/main/java/com/studiophoto/photoappbackend/order/OrderStatus.java`
*   **Modification:** Ajout de la nouvelle valeur d'énumération `PENDING_PAYMENT`.
    *   **Rôle:** Représente l'état d'une commande pour laquelle un paiement Fedapay a été initié mais n'est pas encore confirmé.

### `photo_app_backend/src/main/java/com/studiophoto/photoappbackend/order/OrderService.java`
*   **Modification:** Ajout de deux nouvelles méthodes:
    *   **`createPendingOrderForFedapay()`:** Crée une commande avec le statut `PENDING_PAYMENT`, utilise `request.getTotalAmount()` et `request.isExpress()`, et associe les `OrderItem`s du `FedapayInitiateRequest`.
    *   **`updateOrderStatusAndPaymentMethod()`:** Met à jour le statut et la méthode de paiement d'une commande existante.

### `photo_app_backend/src/main/java/com/studiophoto/photoappbackend/config/ApplicationConfig.java`
*   **Modification:** Ajout d'un bean `RestTemplate` pour permettre l'exécution des requêtes HTTP vers l'API Fedapay.

## Prochaines Étapes / TODOs Importants (Pour la Production)

1.  **Sécurité des Clés API Fedapay:**
    *   Stocker `PUBLIC_KEY` et `SECRET_KEY` de Fedapay de manière sécurisée (par exemple, dans les variables d'environnement du serveur, HashiCorp Vault, ou `application.properties` si le système est sécurisé).

2.  **Vérification de Signature du Webhook Fedapay:**
    *   Implémenter la vérification cryptographique de la signature (`X-FedaPay-Signature`) dans `FedapayWebhookController` pour s'assurer que les notifications proviennent bien de Fedapay et n'ont pas été altérées.

3.  **URLs de Callback et d'Annulation Dynamiques:**
    *   Remplacer les URLs de `callback_url` et `cancel_url` dans `FedapayService` par des valeurs dynamiques et configurables qui pointent vers les URL publiques réelles de votre backend/frontend en production.

4.  **Gestion des Erreurs et Loggings:**
    *   Améliorer la gestion des erreurs et les messages de journalisation dans `FedapayService` et `FedapayWebhookController` pour faciliter le débogage en production.

5.  **Gestion des Doublons (Webhook):**
    *   Mettre en place une logique pour gérer les webhooks Fedapay en double, afin d'éviter de traiter plusieurs fois le même événement de paiement.

6.  **Expérience Utilisateur Mobile après Redirection:**
    *   Implémenter une logique côté mobile pour gérer la redirection après le paiement Fedapay (par exemple, via des "deep links" ou en interrogeant le statut de la commande côté backend) pour une expérience utilisateur fluide.

Ce document fournit un aperçu complet des modifications et des points à considérer.