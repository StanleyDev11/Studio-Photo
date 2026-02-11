import 'package:Picon/api_service.dart';
import 'package:Picon/models/booking.dart';
import 'package:Picon/models/order.dart';
import 'package:Picon/order_detail_screen.dart';
import 'package:Picon/utils/colors.dart';
import 'package:Picon/utils/geometric_background.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<void> _fetchDataFuture;
  List<Order> _allOrders = [];
  List<Booking> _allBookings = [];
  String _selectedTab = 'COMMANDS'; // 'COMMANDS' or 'BOOKINGS'
  String? _selectedFilter;

  @override
  void initState() {
    super.initState();
    _fetchDataFuture = _fetchAllHistory();
  }

  Future<void> _fetchAllHistory() async {
    try {
      final results = await Future.wait([
        ApiService.fetchMyOrders(),
        ApiService.fetchUserBookings(),
      ]);
      setState(() {
        _allOrders = results[0] as List<Order>;
        _allBookings = results[1] as List<Booking>;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur de chargement: $e"), backgroundColor: Colors.red),
      );
    }
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
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'COMMANDS', label: Text('Commandes'), icon: Icon(Icons.shopping_bag)),
                    ButtonSegment(value: 'BOOKINGS', label: Text('Réservations'), icon: Icon(Icons.event)),
                  ],
                  selected: {_selectedTab},
                  onSelectionChanged: (newSelection) {
                    setState(() {
                      _selectedTab = newSelection.first;
                      _selectedFilter = null;
                    });
                  },
                ),
              ),
              if (_selectedTab == 'COMMANDS') _buildOrderFilters(),
              Expanded(
                child: FutureBuilder<void>(
                  future: _fetchDataFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    
                    if (_selectedTab == 'COMMANDS') {
                      final orders = _selectedFilter == null 
                          ? _allOrders 
                          : _allOrders.where((o) => o.status == _selectedFilter).toList();
                      if (orders.isEmpty) return _buildEmptyState('Aucune commande');
                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        itemCount: orders.length,
                        itemBuilder: (context, index) => _buildHistoryCard(orders[index]),
                      );
                    } else {
                      if (_allBookings.isEmpty) return _buildEmptyState('Aucune réservation');
                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        itemCount: _allBookings.length,
                        itemBuilder: (context, index) => _buildBookingCard(_allBookings[index]),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ],
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

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.receipt_long, size: 80, color: AppColors.textSecondary),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, color: AppColors.textSecondary),
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
                      child: Image.network(
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
                      _statusChip(order.status),
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

  Widget _buildBookingCard(Booking booking) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.calendar_today, color: AppColors.accent),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    booking.title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('dd MMM yyyy à HH:mm').format(booking.startTime),
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
            _statusChip(booking.status.name.toUpperCase()),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String status) {
    final info = _getStatusInfo(status);
    return Chip(
      avatar: Icon(info['icon'], color: info['color'], size: 18),
      label: Text(info['text'], style: TextStyle(color: info['color'], fontWeight: FontWeight.bold, fontSize: 12)),
      backgroundColor: info['color'].withOpacity(0.1),
      side: BorderSide(color: info['color'].withOpacity(0.2)),
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