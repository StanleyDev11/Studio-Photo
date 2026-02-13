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
        String errorMessage = e.toString();
        if (errorMessage.startsWith('Exception: ')) {
          errorMessage = errorMessage.substring(11);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
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

              return RefreshIndicator(
                onRefresh: _fetchAllHistory,
                color: AppColors.primary,
                child: Column(
                  children: [
                    _buildOrderStats(),
                    _buildOrderFilters(),
                    Expanded(
                      child: filteredOrders.isEmpty
                          ? _buildEmptyState(_selectedFilter == null ? 'Aucune commande' : 'Aucune commande avec ce statut')
                          : ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(), // Ensures it's always scrollable for RefreshIndicator
                              padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 24.0),
                              itemCount: filteredOrders.length,
                              itemBuilder: (context, index) => _buildHistoryCard(filteredOrders[index]),
                            ),
                    ),
                  ],
                ),
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
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
        Center(
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
              const Text(
                'Aucune commande',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
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
          ),
        ),
      ],
    ).animate().fadeIn().scale(delay: 200.ms);
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

  void _showOrderDetails(Order order) {
    final now = DateTime.now();
    final difference = now.difference(order.createdAt);
    final canModify = difference.inHours < 48;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Commande #${order.id}',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
                _statusMiniBadge(order.status),
              ],
            ),
            const SizedBox(height: 24),
            const Text('Détails des articles', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: order.orderItems.length,
                itemBuilder: (context, index) {
                  final item = order.orderItems[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Format ${item.photoSize}'),
                    subtitle: Text('Quantité: ${item.quantity}'),
                    trailing: Text('${(item.pricePerUnit * item.quantity).toStringAsFixed(0)} FCFA',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  );
                },
              ),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Amount', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text('${order.totalAmount.toStringAsFixed(0)} FCFA',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.primary)),
                ],
              ),
            ),
            if (canModify && order.status.toUpperCase() == 'PENDING')
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _handleModifyOrder(order);
                      },
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Modifier'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _confirmCancelOrder(order);
                      },
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('Annuler'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              )
            else if (!canModify)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Modification et annulation impossibles (délai de 48h dépassé).',
                        style: TextStyle(color: Colors.orange, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _confirmCancelOrder(Order order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Annuler la commande ?'),
        content: const Text('Cette action est irréversible. Voulez-vous vraiment annuler cette commande ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('NON')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ApiService.cancelOrder(order.id);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Commande annulée avec succès')));
                _fetchAllHistory();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
              }
            },
            child: const Text('OUI, ANNULER', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  void _handleModifyOrder(Order order) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Fonctionnalité de modification bientôt disponible. Veuillez contacter le support pour toute urgence.'))
    );
  }
}