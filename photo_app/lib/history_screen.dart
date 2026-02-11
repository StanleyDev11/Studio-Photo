import 'package:Picon/api_service.dart';
import 'package:Picon/models/order.dart';
import 'package:Picon/models/order_item.dart';
import 'package:Picon/utils/colors.dart';
import 'package:Picon/utils/geometric_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<void> _fetchDataFuture;
  List<Order> _allOrders = [];
  String? _selectedFilter;

  @override
  void initState() {
    super.initState();
    _fetchDataFuture = _fetchAllHistory();
  }

  Future<void> _fetchAllHistory() async {
    try {
      final orders = await ApiService.fetchMyOrders();
      setState(() {
        _allOrders = orders;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur de chargement: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historique des Commandes'),
        elevation: 0,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          GeometricBackground(),
          FutureBuilder<void>(
            future: _fetchDataFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final filteredOrders = _selectedFilter == null
                  ? _allOrders
                  : _allOrders.where((o) => o.status == _selectedFilter).toList();

              return Column(
                children: [
                  _buildOrderStats(),
                  _buildOrderFilters(),
                  Expanded(
                    child: filteredOrders.isEmpty
                        ? _buildEmptyState(_selectedFilter == null ? 'Aucune commande' : 'Aucune commande avec ce statut')
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 24.0),
                            itemCount: filteredOrders.length,
                            itemBuilder: (context, index) => _buildHistoryCard(filteredOrders[index]),
                          ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOrderStats() {
    final pending = _allOrders.where((o) => o.status == 'PENDING' || o.status == 'PROCESSING').length;
    final completed = _allOrders.where((o) => o.status == 'COMPLETED').length;

    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          _statItem('Total', _allOrders.length.toString(), Icons.receipt_outlined, AppColors.primary),
          const SizedBox(width: 12),
          _statItem('En cours', pending.toString(), Icons.sync, Colors.orange),
          const SizedBox(width: 12),
          _statItem('Terminées', completed.toString(), Icons.check_circle_outline, Colors.green),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.1)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
            Text(label, style: TextStyle(fontSize: 11, color: color.withOpacity(0.7), fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderFilters() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _filterChip(null, 'Toutes'),
            const SizedBox(width: 8),
            _filterChip('PENDING', 'En attente'),
            const SizedBox(width: 8),
            _filterChip('COMPLETED', 'Terminée'),
            const SizedBox(width: 8),
            _filterChip('CANCELLED', 'Annulée'),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String? value, String label) {
    final isSelected = _selectedFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = selected ? value : null;
        });
      },
      selectedColor: AppColors.primary.withOpacity(0.2),
      checkmarkColor: AppColors.primary,
    );
  }

  Widget _buildHistoryCard(Order order) {
    final orderItems = order.orderItems;

    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.shopping_bag_outlined, color: AppColors.primary),
          ),
          title: Text(
            'Commande #${order.id}',
            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          subtitle: Text(
            DateFormat('dd MMM yyyy').format(order.createdAt),
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${order.totalAmount.toStringAsFixed(0)} FCFA',
                style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.primary),
              ),
              _statusMiniBadge(order.status),
            ],
          ),
          children: [
            const Divider(indent: 20, endIndent: 20, height: 1),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Détails de la commande',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primary),
                  ),
                  const SizedBox(height: 12),
                  ...orderItems.map((item) => _buildOrderItemRow(item)),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),
                  _infoDetailRow(Icons.payments_outlined, 'Paiement', order.paymentMethod.replaceAll('_', ' ')),
                  const SizedBox(height: 8),
                  _infoDetailRow(Icons.local_shipping_outlined, 'Livraison', order.deliveryType.replaceAll('_', ' ')),
                  const SizedBox(height: 16),
                  _statusLargeView(order.status),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn().slideY(begin: 0.1, curve: Curves.easeOut);
  }

  Widget _buildOrderItemRow(OrderItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              item.imageUrl,
              width: 50,
              height: 50,
              fit: BoxFit.cover,
              errorBuilder: (ctx, err, st) => const Icon(Icons.photo, size: 50, color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Format: ${item.photoSize}',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                Text(
                  'Quantité: ${item.quantity}',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            '${(item.pricePerUnit * item.quantity).toStringAsFixed(0)} FCFA',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _infoDetailRow(IconData icon, String title, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.textSecondary),
        const SizedBox(width: 12),
        Text('$title: ', style: const TextStyle(color: AppColors.textSecondary)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.receipt_long_outlined, size: 64, color: AppColors.primary),
          ),
          const SizedBox(height: 20),
          Text(
            'Aucune commande',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
          ),
        ],
      ).animate().fadeIn().scale(delay: 200.ms),
    );
  }

  Widget _statusMiniBadge(String status) {
    final info = _getStatusInfo(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: (info['color'] as Color).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: (info['color'] as Color).withOpacity(0.2)),
      ),
      child: Text(
        info['text'].toUpperCase(),
        style: TextStyle(color: info['color'], fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5),
      ),
    );
  }

  Widget _statusLargeView(String status) {
    final info = _getStatusInfo(status);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: (info['color'] as Color).withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: (info['color'] as Color).withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (info['color'] as Color).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(info['icon'], color: info['color'], size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Statut actuel', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(
                  info['text'],
                  style: TextStyle(color: info['color'], fontWeight: FontWeight.w900, fontSize: 18),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _getStatusInfo(String status) {
    switch (status) {
      case 'COMPLETED':
      case 'CONFIRMED':
        return {'text': 'Confirmée', 'color': Colors.green.shade700, 'icon': Icons.check_circle};
      case 'PROCESSING':
      case 'PENDING':
        return {'text': 'En attente', 'color': Colors.orange.shade700, 'icon': Icons.hourglass_top};
      case 'CANCELLED':
        return {'text': 'Annulée', 'color': Colors.red.shade700, 'icon': Icons.cancel};
      default:
        return {'text': status, 'color': Colors.grey.shade700, 'icon': Icons.help_outline};
    }
  }
}