import 'package:flutter/material.dart';
import 'package:photo_app/utils/colors.dart';

// 1. Create a PortfolioItem model class
class PortfolioItem {
  final String name;
  final String description;
  final String dimensions;
  final String imageUrl;

  const PortfolioItem({
    required this.name,
    required this.description,
    required this.dimensions,
    required this.imageUrl,
  });
}

class PortfolioScreen extends StatelessWidget {
  const PortfolioScreen({super.key});

  // Sample list of portfolio items
  final List<PortfolioItem> portfolioItems = const [
    PortfolioItem(
      name: 'Mariage en Plein Air',
      description: 'Une séance photo capturant l\'amour et la joie d\'un mariage champêtre. Ambiance naturelle et spontanée.',
      dimensions: 'Tirages 20x30cm, Album 30x30cm',
      imageUrl: 'assets/carousel/car.jpg',
    ),
    PortfolioItem(
      name: 'Portrait Corporate',
      description: 'Photos professionnelles pour les profils d\'entreprise. Un éclairage de studio pour un look moderne et épuré.',
      dimensions: '10x15cm, 15x20cm',
      imageUrl: 'assets/carousel/car1.jpg',
    ),
    PortfolioItem(
      name: 'Événement Sportif',
      description: 'Capture de l\'action et de l\'émotion d\'un match de basketball local. Photos dynamiques et pleines d\'énergie.',
      dimensions: 'Impressions sur toile, Posters',
      imageUrl: 'assets/carousel/mxx.jpeg',
    ),
    PortfolioItem(
      name: 'Mode Urbaine',
      description: 'Shooting de mode dans les rues de la ville, jouant avec l\'architecture et la lumière naturelle.',
      dimensions: 'Magazine, Réseaux sociaux',
      imageUrl: 'assets/carousel/pflex.jpeg',
    ),
    PortfolioItem(
      name: 'Campagne Octobre Rose',
      description: 'Série de visuels pour une campagne de sensibilisation. Douceur et force se rencontrent.',
      dimensions: 'Affiches, Flyers',
      imageUrl: 'assets/carousel/Pink Modern Pink October Instagram Post .png',
    ),
    PortfolioItem(
      name: 'Produits Cosmétiques',
      description: 'Photographie de produits pour une marque de cosmétiques. Gros plans et textures mises en valeur.',
      dimensions: 'Catalogue, E-commerce',
      imageUrl: 'assets/carousel/Ajouter un sous-titre.png',
    ),
    PortfolioItem(
      name: 'Portrait Professionnel',
      description: 'Un portrait qui inspire confiance et professionnalisme. Idéal pour les CV et les profils en ligne.',
      dimensions: '10x15cm',
      imageUrl: 'assets/images/pro.png',
    ),
    PortfolioItem(
      name: 'Logo & Branding',
      description: 'Création d\'une identité visuelle pour une marque. Le logo est le visage de l\'entreprise.',
      dimensions: 'Numérique',
      imageUrl: 'assets/logos/mixbyyass.jpg',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Portfolio'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(8.0),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 8.0,
          mainAxisSpacing: 8.0,
          childAspectRatio: 0.75, // Adjust aspect ratio to fit text
        ),
        itemCount: portfolioItems.length,
        itemBuilder: (context, index) {
          final item = portfolioItems[index];
          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PortfolioDetailScreen(item: item),
                ),
              );
            },
            child: Card(
              clipBehavior: Clip.antiAlias,
              elevation: 4.0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Image.asset(
                      item.imageUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(child: Icon(Icons.broken_image, color: AppColors.textSecondary, size: 40));
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      item.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                    child: Text(
                      item.description,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// 2. Create a PortfolioDetailScreen widget
class PortfolioDetailScreen extends StatelessWidget {
  final PortfolioItem item;

  const PortfolioDetailScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(item.name),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Image.asset(
              item.imageUrl,
              fit: BoxFit.cover,
              width: double.infinity,
              height: 300,
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.description,
                    style: const TextStyle(fontSize: 16, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Dimensions & Formats',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.dimensions,
                    style: const TextStyle(fontSize: 16, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}