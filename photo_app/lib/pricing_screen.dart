import 'package:flutter/material.dart';
import 'package:photo_app/utils/colors.dart';

class PricingScreen extends StatelessWidget {
  const PricingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nos Tarifs'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: const [
          _PricingCard(
            title: 'Shooting Photo Basique',
            price: '50,000 FCFA',
            features: [
              '1 heure de shooting',
              '10 photos retouchées en HD',
              '1 lieu au choix',
              'Galerie en ligne privée',
            ],
          ),
          SizedBox(height: 16),
          _PricingCard(
            title: 'Forfait Événementiel',
            price: '150,000 FCFA',
            features: [
              '4 heures de couverture',
              'Toutes les photos en HD',
              '50 photos retouchées',
              'Album photo inclus',
              'Déplacement inclus (zone A)',
            ],
            isPopular: true,
          ),
          SizedBox(height: 16),
          _PricingCard(
            title: 'Forfait Mariage Complet',
            price: 'Sur Devis',
            features: [
              'Journée complète (des préparatifs à la soirée)',
              'Toutes les photos en HD',
              '100+ photos retouchées',
              'Album photo de luxe',
              'Séance photo de couple pré-mariage',
              'Second photographe inclus',
            ],
          ),
        ],
      ),
    );
  }
}

class _PricingCard extends StatelessWidget {
  final String title;
  final String price;
  final List<String> features;
  final bool isPopular;

  const _PricingCard({
    required this.title,
    required this.price,
    required this.features,
    this.isPopular = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isPopular ? const BorderSide(color: AppColors.accent, width: 2) : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            if (isPopular) ...[
              const SizedBox(height: 8),
              Chip(
                label: const Text('Populaire'),
                backgroundColor: AppColors.accent.withOpacity(0.1),
                labelStyle: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold),
              )
            ],
            const SizedBox(height: 16),
            Text(
              price,
              style: Theme.of(context).textTheme.displaySmall?.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            ...features.map((feature) => Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                children: [
                  const Icon(Icons.check, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text(feature, style: const TextStyle(fontSize: 16))),
                ],
              ),
            )),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Choisir ce forfait'),
            )
          ],
        ),
      ),
    );
  }
}
