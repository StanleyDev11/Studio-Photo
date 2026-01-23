import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:photo_app/models/photo_order.dart';
import 'package:photo_app/order_detail_screen.dart';
import 'package:photo_app/utils/colors.dart';
import 'package:photo_app/utils/geometric_background.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  // --- Mock Data ---
  final List<PhotoOrder> _allOrders = [
    PhotoOrder(
      id: 'CMD-2407-001',
      date: DateTime.now().subtract(const Duration(days: 2)),
      status: OrderStatus.completed,
      totalPrice: 2500,
      paymentMethod: 'Flooz',
      type: OrderType.detail,
      items: [
        OrderItem(imageUrl: 'assets/carousel/car.jpg', size: '10x15 cm', quantity: 10, price: 150),
        OrderItem(imageUrl: 'assets/carousel/car1.jpg', size: '15x20 cm', quantity: 2, price: 500),
      ],
    ),
    PhotoOrder(
      id: 'CMD-2407-002',
      date: DateTime.now().subtract(const Duration(days: 5)),
      status: OrderStatus.processing,
      totalPrice: 4500,
      paymentMethod: 'MasterCard',
      type: OrderType.batch,
      items: List.generate(15, (i) => OrderItem(imageUrl: 'assets/images/pro.png', size: '10x15 cm', quantity: 1, price: 300)),
    ),
    PhotoOrder(
      id: 'CMD-2406-005',
      date: DateTime.now().subtract(const Duration(days: 15)),
      status: OrderStatus.cancelled,
      totalPrice: 1200,
      paymentMethod: 'Mix by Yass',
      type: OrderType.detail,
      items: [
        OrderItem(imageUrl: 'assets/carousel/mxx.jpeg', size: '10x15 cm', quantity: 8, price: 150),
      ],
    ),
    PhotoOrder(
      id: 'CMD-2406-004',
      date: DateTime.now().subtract(const Duration(days: 28)),
      status: OrderStatus.completed,
      totalPrice: 9000,
      paymentMethod: 'Flooz',
      type: OrderType.batch,
      items: List.generate(30, (i) => OrderItem(imageUrl: 'assets/carousel/pflex.jpeg', size: '15x20 cm', quantity: 1, price: 300)),
    ),
  ];

  late List<PhotoOrder> _filteredOrders;
  OrderType? _selectedFilter;

  @override
  void initState() {
    super.initState();
    _filteredOrders = _allOrders;
    _selectedFilter = null; // Show all by default
  }

  void _filterOrders(OrderType? newFilter) {
    setState(() {
      _selectedFilter = newFilter;
      if (newFilter == null) {
        _filteredOrders = _allOrders;
      } else {
        _filteredOrders = _allOrders.where((order) => order.type == newFilter).toList();
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
                child: SegmentedButton<OrderType?>(
                  segments: const [
                    ButtonSegment(value: null, label: Text('Toutes')),
                    ButtonSegment(value: OrderType.detail, label: Text('Par Détail')),
                    ButtonSegment(value: OrderType.batch, label: Text('Par Lot')),
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
                child: _filteredOrders.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        itemCount: _filteredOrders.length,
                        itemBuilder: (context, index) {
                          final order = _filteredOrders[index];
                          return _buildHistoryCard(order);
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

  Widget _buildHistoryCard(PhotoOrder order) {
    final statusInfo = _getStatusInfo(order.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OrderDetailScreen(order: order),
            ),
          );
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
                    order.id,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                  Text(
                    DateFormat('dd MMMM yyyy').format(order.date),
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  // Image Preview
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      order.items.first.imageUrl,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      errorBuilder: (ctx, err, st) => const Icon(Icons.photo, size: 60, color: AppColors.textSecondary),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Order Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${order.items.length} article${order.items.length > 1 ? 's' : ''}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${order.totalPrice.toStringAsFixed(0)} FCFA',
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                  // Status Chip
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

  Map<String, dynamic> _getStatusInfo(OrderStatus status) {
    switch (status) {
      case OrderStatus.completed:
        return {'text': 'Terminée', 'color': Colors.green.shade700, 'icon': Icons.check_circle};
      case OrderStatus.processing:
        return {'text': 'En cours', 'color': Colors.blue.shade700, 'icon': Icons.sync};
      case OrderStatus.cancelled:
        return {'text': 'Annulée', 'color': Colors.red.shade700, 'icon': Icons.cancel};
      case OrderStatus.pending:
      default:
        return {'text': 'En attente', 'color': Colors.orange.shade700, 'icon': Icons.hourglass_top};
    }
  }
}