import 'package:flutter/material.dart';
import 'payment_selection_screen.dart'; // Assurez-vous d'importer la page PaymentSelectionScreen.

class OrderSummaryScreen extends StatelessWidget {
  final Map<String, Map<String, dynamic>> orderDetails;

  const OrderSummaryScreen({Key? key, required this.orderDetails})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Récapitulatif de la commande',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        backgroundColor: Colors.deepPurple, // Couleur de fond de la barre
        elevation: 5, // Ajouter de l'ombre à la barre
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.purple.shade200, Colors.deepPurple.shade300],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ListView(
            children: orderDetails.entries.map((entry) {
              final imageUrl = entry.key;
              final details = entry.value;
              return Card(
                elevation: 5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          imageUrl,
                          height: 150,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Taille : ${details['size']}',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        'Quantité : ${details['quantity']}',
                        style:
                            const TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: Colors.deepPurple, // Couleur du texte
            elevation: 8, // Ajoute une ombre au bouton
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12), // Coins arrondis
            ),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          onPressed: () {
            // Naviguer vers PaymentSelectionScreen avec les détails de la commande
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    PaymentSelectionScreen(orderDetails: orderDetails),
              ),
            );
          },
          child: const Text(
            'Confirmer et choisir le paiement',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
