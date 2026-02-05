# Fedapay Intégration - Prochaines Étapes pour la Production (TODOs)

Ce document liste les étapes critiques et les tâches restantes nécessaires pour rendre l'intégration de Fedapay robuste, sécurisée et prête pour un environnement de production.

## 1. Sécurité des Clés API Fedapay

*   **Problème actuel:** Les clés publiques (`PUBLIC_KEY`) et secrètes (`SECRET_KEY`) de Fedapay sont actuellement encodées en dur dans le fichier `FedapayService.java` du backend.
*   **Action requise:** Ces clés doivent être extraites du code source et stockées de manière sécurisée.
    *   **Options:**
        *   Utiliser des variables d'environnement (recommandé pour la production).
        *   Les placer dans le fichier `application.properties` ou `application.yml` du Spring Boot backend, en s'assurant que ces fichiers ne sont pas exposés publiquement et sont gérés en dehors du contrôle de version si les clés sont sensibles.
        *   Utiliser un système de gestion de secrets (comme HashiCorp Vault ou AWS Secrets Manager) pour les environnements de production.

## 2. Vérification de Signature du Webhook Fedapay

*   **Problème actuel:** La logique de vérification de la signature du webhook dans `FedapayWebhookController.java` est présente mais est actuellement désactivée ou sous forme de placeholder (`// TODO: Implement actual signature verification`).
*   **Action requise:** Implémenter la vérification cryptographique de la signature (`X-FedaPay-Signature`) envoyée par Fedapay.
    *   **Rôle:** Cette vérification est cruciale pour s'assurer que les requêtes reçues par votre endpoint de webhook proviennent réellement de Fedapay et n'ont pas été falsifiées par un tiers malveillant.
    *   **Détails:** La documentation de Fedapay fournit généralement des instructions sur la manière de vérifier cette signature à l'aide de la clé secrète de votre compte.

## 3. URLs de Callback et d'Annulation Dynamiques

*   **Problème actuel:** Les URLs (`callback_url` et `cancel_url`) envoyées à l'API Fedapay lors de l'initiation du paiement sont actuellement des valeurs statiques et des placeholders (`https://your_backend_domain.com/api/payments/fedapay/webhook`, `https://your_app_domain.com/payment_cancel`).
*   **Action requise:** Remplacer ces URLs par des valeurs dynamiques et configurables qui correspondent aux environnements de déploiement (développement, staging, production).
    *   **`callback_url`:** Doit pointer vers l'URL publique accessible de votre endpoint de webhook Fedapay (`/api/payments/fedapay/webhook`).
    *   **`cancel_url`:** Doit pointer vers une page ou un écran de votre application mobile/web où l'utilisateur est redirigé en cas d'annulation du paiement.
    *   **Implémentation:** Ces URLs devraient être lues à partir de `application.properties` ou de variables d'environnement.

## 4. Gestion des Erreurs et Loggings

*   **Problème actuel:** La gestion des erreurs et les messages de journalisation sont basiques.
*   **Action requise:** Améliorer la gestion des erreurs et les messages de journalisation dans `FedapayService` et `FedapayWebhookController`.
    *   **Détails:** Fournir des messages d'erreur plus explicites pour le débogage. Utiliser des niveaux de journalisation appropriés (DEBUG, INFO, WARN, ERROR) pour surveiller le comportement de l'intégration en production.

## 5. Gestion des Doublons (Webhook)

*   **Problème actuel:** Le webhook Fedapay pourrait potentiellement envoyer plusieurs fois le même événement en cas de problèmes réseau ou de timeouts.
*   **Action requise:** Mettre en place une logique pour gérer les webhooks Fedapay en double afin d'éviter de traiter plusieurs fois le même événement de paiement.
    *   **Implémentation:** Stocker un identifiant unique du webhook reçu (par exemple, l'ID de la transaction Fedapay) dans votre base de données et vérifier si cet identifiant a déjà été traité avant de mettre à jour le statut d'une commande.

## 6. Expérience Utilisateur Mobile après Redirection

*   **Problème actuel:** Après avoir effectué un paiement sur la page Fedapay, l'utilisateur est redirigé vers une `ReceiptScreen` générique avec un statut "FEDAPAY_PENDING". L'application mobile ne reçoit pas de confirmation directe du statut final du paiement.
*   **Action requise:** Implémenter un mécanisme pour que l'application mobile puisse confirmer le statut réel du paiement après la redirection depuis Fedapay.
    *   **Options:**
        *   **Deep Linking:** Configurer des liens profonds (deep links) pour que Fedapay puisse rediriger l'utilisateur vers un écran spécifique de votre application avec les paramètres de statut de paiement.
        *   **Polling du Backend:** L'application mobile pourrait périodiquement interroger votre backend pour le statut de la commande en attente après la redirection de Fedapay.
        *   **Notifications Push:** Le backend pourrait envoyer une notification push à l'utilisateur une fois le statut de la commande mis à jour par le webhook.

Ce sont les points essentiels à considérer pour une intégration Fedapay complète et fiable en production.