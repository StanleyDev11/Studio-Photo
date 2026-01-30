import 'package:Picon/api_service.dart';
import 'package:Picon/models/order.dart';
import 'package:Picon/order_detail_screen.dart';
import 'package:Picon/utils/colors.dart';
import 'package:Picon/utils/geometric_background.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// The old OrderType enum, can be removed or adapted if the backend provides this info
enum OrderType { detail, batch }

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<List<Order>> _ordersFuture;
  List<Order> _allOrders = [];
  List<Order> _filteredOrders = [];
  String? _selectedFilter; // Using String to match OrderStatus enum values

  @override
  void initState() {
    super.initState();
    _ordersFuture = _fetchOrders();
  }

  Future<List<Order>> _fetchOrders() async {
    try {
      final orders = await ApiService.fetchMyOrders();
      setState(() {
        _allOrders = orders;
        _filteredOrders = orders;
      });
      return orders;
    } catch (e) {
      // Handle error appropriately
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur de chargement de l'historique: $e"), backgroundColor: Colors.red),
      );
      return [];
    }
  }

  void _filterOrders(String? newFilter) {
    setState(() {
      _selectedFilter = newFilter;
      if (newFilter == null) {
        _filteredOrders = _allOrders;
      } else {
        _filteredOrders = _allOrders.where((order) => order.status == newFilter).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historique des commandes'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          const GeometricBackground(),
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: SegmentedButton<String?>(
                  segments: const [
                    ButtonSegment(value: null, label: Text('Toutes')),
                    ButtonSegment(value: "PENDING", label: Text('En attente')),
                    ButtonSegment(value: "COMPLETED", label: Text('Terminée')),
                  ],
                  selected: {_selectedFilter},
                  onSelectionChanged: (newSelection) {
                    _filterOrders(newSelection.first);
                  },
                  style: SegmentedButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.5),
                    foregroundColor: AppColors.primary,
                    selectedForegroundColor: Colors.white,
                    selectedBackgroundColor: AppColors.primary,
                  ),
                ),
              ),
              Expanded(
                child: FutureBuilder<List<Order>>(
                  future: _ordersFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text("Erreur: ${snapshot.error}"));
                    }
                    if (_filteredOrders.isEmpty) {
                      return _buildEmptyState();
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      itemCount: _filteredOrders.length,
                      itemBuilder: (context, index) {
                        final order = _filteredOrders[index];
                        return _buildHistoryCard(order);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long, size: 80, color: AppColors.textSecondary),
          SizedBox(height: 16),
          Text(
            'Aucune commande ne correspond à ce filtre.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(Order order) {
    final statusInfo = _getStatusInfo(order.status);
    final orderItems = order.orderItems;

    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          // Navigator.push(
          //   context,
          //   MaterialPageRoute(
          //     builder: (context) => OrderDetailScreen(order: order),
          //   ),
          // );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              color: AppColors.primary.withOpacity(0.05),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'CMD-${order.id}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                  Text(
                    DateFormat('dd MMMM yyyy').format(order.createdAt),
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  if (orderItems.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network( // Use Image.network for URLs
                        orderItems.first.imageUrl,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        errorBuilder: (ctx, err, st) => const Icon(Icons.photo, size: 60, color: AppColors.textSecondary),
                      ),
                    ),
                  if (orderItems.isEmpty)
                    const Icon(Icons.photo, size: 60, color: AppColors.textSecondary),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${orderItems.length} article${orderItems.length > 1 ? 's' : ''}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${order.totalAmount.toStringAsFixed(0)} FCFA',
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      Chip(
                        avatar: Icon(statusInfo['icon'], color: statusInfo['color'], size: 18),
                        label: Text(statusInfo['text'], style: TextStyle(color: statusInfo['color'], fontWeight: FontWeight.bold)),
                        backgroundColor: statusInfo['color'].withOpacity(0.1),
                        side: BorderSide(color: statusInfo['color'].withOpacity(0.2)),
                      ),
                       const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textSecondary),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _getStatusInfo(String status) {
    switch (status) {
      case 'COMPLETED':
        return {'text': 'Terminée', 'color': Colors.green.shade700, 'icon': Icons.check_circle};
      case 'PROCESSING':
        return {'text': 'En cours', 'color': Colors.blue.shade700, 'icon': Icons.sync};
      case 'CANCELLED':
        return {'text': 'Annulée', 'color': Colors.red.shade700, 'icon': Icons.cancel};
      case 'PENDING':
      default:
        return {'text': 'En attente', 'color': Colors.orange.shade700, 'icon': Icons.hourglass_top};
    }
  }
}