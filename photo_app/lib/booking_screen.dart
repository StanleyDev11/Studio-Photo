import 'package:flutter/material.dart';
import 'package:photo_app/utils/colors.dart';

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

  void _submitBooking() {
    if (_formKey.currentState!.validate()) {
      // Handle booking submission logic here
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Réservation envoyée! Nous vous contacterons bientôt.'), backgroundColor: Colors.green),
      );
      Navigator.of(context).pop();
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
