import 'package:flutter/material.dart';
import 'package:photo_app/utils/colors.dart';
import 'package:photo_app/api_service.dart';
import 'package:photo_app/models/booking.dart';


class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedService;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  final _commentsController = TextEditingController();

  final List<String> _services = [
    'Shooting Photo Basique',
    'Forfait Événementiel',
    'Forfait Mariage',
    'Photos d\'identité',
    'Tirage Photos',
  ];

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  void _submitBooking() async {
    if (_formKey.currentState!.validate()) {
      if (ApiService.userId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur: Utilisateur non authentifié.'), backgroundColor: Colors.red),
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

      final Booking newBooking = Booking.fromId(
        title: _selectedService!,
        description: _commentsController.text,
        userId: ApiService.userId!, // Use authenticated userId
        startTime: scheduledTime,
        endTime: scheduledTime.add(const Duration(hours: 1)),
      );

      try {
        final createdBooking = await ApiService.createBooking(newBooking);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Réservation confirmée avec l\'ID: ${createdBooking.id}'), backgroundColor: Colors.green),
        );
        Navigator.of(context).pop();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la réservation: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Faire une réservation'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                value: _selectedService,
                decoration: const InputDecoration(labelText: 'Type de service'),
                items: _services.map((String service) {
                  return DropdownMenuItem<String>(
                    value: service,
                    child: Text(service),
                  );
                }).toList(),
                onChanged: (newValue) {
                  setState(() {
                    _selectedService = newValue;
                  });
                },
                validator: (value) => value == null ? 'Veuillez choisir un service' : null,
              ),
              const SizedBox(height: 24),
              TextFormField(
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Date de la séance',
                  suffixIcon: const Icon(Icons.calendar_today),
                  hintText: _selectedDate == null ? 'Sélectionnez une date' : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                ),
                onTap: _selectDate,
                validator: (value) => _selectedDate == null ? 'Veuillez choisir une date' : null,
              ),
              const SizedBox(height: 24),
               TextFormField(
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Heure de la séance',
                  suffixIcon: const Icon(Icons.access_time),
                  hintText: _selectedTime == null ? 'Sélectionnez une heure' : _selectedTime!.format(context),
                ),
                onTap: _selectTime,
                validator: (value) => _selectedTime == null ? 'Veuillez choisir une heure' : null,
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _commentsController,
                decoration: const InputDecoration(
                  labelText: 'Commentaires additionnels (facultatif)',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
                maxLines: 4,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _submitBooking,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                ),
                child: const Text('Confirmer la réservation'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
