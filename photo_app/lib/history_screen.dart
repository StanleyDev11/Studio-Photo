import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:photo_app/home_screen.dart'; // Reusing the model class
import 'package:photo_app/utils/colors.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Using a larger mock data list for the full history screen
    final List<RecentRequest> fullHistory = [
      RecentRequest(title: "Commande de 15 photos", date: DateTime.now().subtract(const Duration(days: 1)), icon: Icons.photo_camera),
      RecentRequest(title: "Photos d'identité", date: DateTime.now().subtract(const Duration(days: 4)), icon: Icons.person),
      RecentRequest(title: "Tirage 20x30", date: DateTime.now().subtract(const Duration(days: 6)), icon: Icons.print),
      RecentRequest(title: "Commande Album", date: DateTime.now().subtract(const Duration(days: 10)), icon: Icons.book),
      RecentRequest(title: "Réservation - Mariage", date: DateTime.now().subtract(const Duration(days: 15)), icon: Icons.calendar_today),
      RecentRequest(title: "Shooting Famille", date: DateTime.now().subtract(const Duration(days: 22)), icon: Icons.family_restroom),
      RecentRequest(title: "Tirage 10x15", date: DateTime.now().subtract(const Duration(days: 31)), icon: Icons.print),
      RecentRequest(title: "Photos CV", date: DateTime.now().subtract(const Duration(days: 45)), icon: Icons.work),
      RecentRequest(title: "Commande Agrandissement", date: DateTime.now().subtract(const Duration(days: 50)), icon: Icons.photo_size_select_large),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historique complet'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        itemCount: fullHistory.length,
        itemBuilder: (context, index) {
          final item = fullHistory[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.primary.withOpacity(0.1),
              child: Icon(item.icon, color: AppColors.primary),
            ),
            title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w500)),
            subtitle: Text(DateFormat('dd MMMM yyyy').format(item.date), style: const TextStyle(color: AppColors.textSecondary)),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textSecondary),
            onTap: () {
              // Navigate to order details screen
            },
          );
        },
      ),
    );
  }
}
