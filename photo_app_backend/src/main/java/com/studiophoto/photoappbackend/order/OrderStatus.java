package com.studiophoto.photoappbackend.order;

public enum OrderStatus {
    PENDING,      // Commande créée, en attente de paiement ou de traitement
    PROCESSING,   // Paiement reçu, en cours de préparation
    COMPLETED,    // Commande terminée et livrée/récupérée
    CANCELLED     // Commande annulée
}
