import 'package:Picon/api_service.dart';
import 'package:Picon/models/booking.dart';
import 'package:Picon/utils/colors.dart';
import 'package:Picon/utils/geometric_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'dart:ui';

class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final _formKey = GlobalKey<FormState>();
  BookingType? _selectedType;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  final _commentsController = TextEditingController();

  final List<Map<String, dynamic>> _serviceOptions = [
    {
      'type': BookingType.photoSession,
      'title': 'Shooting Photo Basique',
      'price': 15000.0,
      'icon': Icons.camera_alt_outlined,
      'description': 'Séance en studio (30 min), 5 photos retouchées.',
    },
    {
      'type': BookingType.portrait,
      'title': 'Portrait Professionnel',
      'price': 25000.0,
      'icon': Icons.person_outline,
      'description': 'Idéal pour LinkedIn ou CV. 10 photos HD.',
    },
    {
      'type': BookingType.event,
      'title': 'Forfait Événementiel',
      'price': 75000.0,
      'icon': Icons.celebration_outlined,
      'description': 'Couverture complète d\'un événement (2h).',
    },
    {
      'type': BookingType.product,
      'title': 'Pack Packshot Produit',
      'price': 45000.0,
      'icon': Icons.inventory_2_outlined,
      'description': '15 photos de produits sur fond blanc.',
    },
    {
      'type': BookingType.other,
      'title': 'Sur Mesure',
      'price': 0.0,
      'icon': Icons.more_horiz_outlined,
      'description': 'Besoin spécifique ? Contactez-nous pour un devis.',
    },
  ];

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? const TimeOfDay(hour: 10, minute: 0),
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  void _submitBooking() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedType == null || _selectedDate == null || _selectedTime == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Veuillez remplir tous les champs obligatoires.')),
        );
        return;
      }

      if (ApiService.userId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur: Utilisateur non authentifié.')),
        );
        return;
      }

      final DateTime scheduledTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );

      final selectedServiceData = _serviceOptions.firstWhere((s) => s['type'] == _selectedType);

      final Booking newBooking = Booking.fromId(
        title: selectedServiceData['title'],
        description: _commentsController.text,
        userId: ApiService.userId!,
        startTime: scheduledTime,
        endTime: scheduledTime.add(const Duration(hours: 1)),
        type: _selectedType!,
        amount: selectedServiceData['price'],
      );

      try {
        final createdBooking = await ApiService.createBooking(newBooking);
        _showSuccessDialog(createdBooking.id.toString());
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showSuccessDialog(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Icon(Icons.check_circle_outline, color: Colors.green, size: 60),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Réservation confirmée !',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 10),
            Text('Votre réservation #$id a été enregistrée avec succès.',
                textAlign: TextAlign.center),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Retour à l\'accueil', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const GeometricBackground(),
          CustomScrollView(
            slivers: [
              _buildAppBar(),
              SliverPadding(
                padding: const EdgeInsets.all(20),
                sliver: SliverToBoxAdapter(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader('Choisissez un service'),
                        const SizedBox(height: 15),
                        _buildServiceSelector(),
                        const SizedBox(height: 30),
                        _buildSectionHeader('Date et Heure'),
                        const SizedBox(height: 15),
                        _buildDateTimeSelectors(),
                        const SizedBox(height: 30),
                        _buildSectionHeader('Notes additionnelles'),
                        const SizedBox(height: 15),
                        _buildCommentsField(),
                        const SizedBox(height: 40),
                        _buildPriceSummary(),
                        const SizedBox(height: 30),
                        _buildSubmitButton(),
                        const SizedBox(height: 50),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 20.0,
      floating: false,
      pinned: true,
      backgroundColor: AppColors.primary,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        title: const Text('Nouvelle Réservation',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
    ).animate().fadeIn(duration: 500.ms).slideX(begin: -0.2);
  }

  Widget _buildServiceSelector() {
    return Column(
      children: _serviceOptions.map((option) {
        final isSelected = _selectedType == option['type'];
        return GestureDetector(
          onTap: () => setState(() => _selectedType = option['type']),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.white.withOpacity(0.5),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: isSelected ? AppColors.primary : Colors.white.withOpacity(0.2),
                width: 2,
              ),
            ),
            child: Row(
              children: [
                Icon(option['icon'],
                    color: isSelected ? AppColors.primary : AppColors.textSecondary, size: 30),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(option['title'],
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isSelected ? AppColors.primary : AppColors.textPrimary,
                          )),
                      Text(option['description'],
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                if (option['price'] > 0)
                  Text(
                    '${NumberFormat('#,###').format(option['price'])} F',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.accent),
                  ),
              ],
            ),
          ),
        ).animate(target: isSelected ? 1 : 0).scale(begin: const Offset(1,1), end: const Offset(1.02, 1.02));
      }).toList(),
    );
  }

  Widget _buildDateTimeSelectors() {
    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            label: _selectedDate == null ? 'Date' : DateFormat('dd/MM/yy').format(_selectedDate!),
            icon: Icons.calendar_today,
            onTap: _selectDate,
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: _buildActionButton(
            label: _selectedTime == null ? 'Heure' : _selectedTime!.format(context),
            icon: Icons.access_time,
            onTap: _selectTime,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({required String label, required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(width: 10),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentsField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.5),
        borderRadius: BorderRadius.circular(15),
      ),
      child: TextFormField(
        controller: _commentsController,
        maxLines: 3,
        decoration: InputDecoration(
          hintText: 'Précisez vos attentes...',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
          ),
          contentPadding: const EdgeInsets.all(15),
        ),
      ),
    );
  }

  Widget _buildPriceSummary() {
    if (_selectedType == null) return const SizedBox.shrink();
    final selectedService = _serviceOptions.firstWhere((s) => s['type'] == _selectedType);
    if (selectedService['price'] == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 10)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Total estimé',
              style: TextStyle(color: Colors.white, fontSize: 16)),
          Text(
            '${NumberFormat('#,###').format(selectedService['price'])} FCFA',
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    ).animate().fadeIn().scale();
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _submitBooking,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          elevation: 5,
        ),
        child: const Text('CONFIRMER MA RÉSERVATION',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
      ),
    );
  }
}
