import 'package:flutter/material.dart';
import 'confirmation_screen.dart';

class PaymentSelectionScreen extends StatelessWidget {
  final Map<String, Map<String, dynamic>> orderDetails;

  const PaymentSelectionScreen({Key? key, required this.orderDetails})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final paymentMethods = [
      {'name': 'MasterCard / VISA', 'logo': 'assets/logos/mastercard.png'},
      {'name': 'Flooz', 'logo': 'assets/logos/flooz.webp'},
      {'name': 'Mix by Yass', 'logo': 'assets/logos/mixbyyass.jpg'},
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Choisir le mode de paiement',
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
          child: ListView.builder(
            itemCount: paymentMethods.length,
            itemBuilder: (context, index) {
              final method = paymentMethods[index];
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ConfirmationScreen(
                        orderDetails: orderDetails,
                        paymentMethod: method['name'] ?? 'Mode inconnu',
                      ),
                    ),
                  );
                },
                child: Card(
                  elevation: 5,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16.0),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child:
                          method['logo'] != null && method['logo']!.isNotEmpty
                              ? Image.asset(
                                  method['logo']!,
                                  width: 50,
                                  height: 50,
                                  fit: BoxFit.cover,
                                )
                              : const Icon(Icons.error, size: 50),
                    ),
                    title: Text(
                      method['name'] ?? 'Mode de paiement inconnu',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.deepPurple,
                      ),
                    ),
                    subtitle: const Text(
                      'Cliquez pour choisir ce mode de paiement',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    trailing:
                        Icon(Icons.arrow_forward_ios, color: Colors.deepPurple),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
