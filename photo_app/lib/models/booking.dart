import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter/foundation.dart';

part 'booking.freezed.dart';
part 'booking.g.dart';

enum BookingStatus {
  @JsonValue('PENDING')
  pending,
  @JsonValue('CONFIRMED')
  confirmed,
  @JsonValue('CANCELLED')
  cancelled,
  @JsonValue('COMPLETED')
  completed,
}

enum BookingType {
  @JsonValue('PHOTO_SESSION')
  photoSession,
  @JsonValue('EVENT')
  event,
  @JsonValue('PORTRAIT')
  portrait,
  @JsonValue('PRODUCT')
  product,
  @JsonValue('OTHER')
  other,
}

@freezed
class Booking with _$Booking {
  const factory Booking({
    required int id,
    required String title,
    String? description,
    required int userId, // ID utilisateur lié à la réservation
    required DateTime startTime,
    required DateTime endTime,
    required BookingStatus status,
    required BookingType type, // Nouveau champ
    required double amount, // Nouveau champ (BigDecimal en Java -> double en Dart)
    String? notes,
    required DateTime createdAt,
    DateTime? updatedAt,
  }) = _Booking;

  factory Booking.fromJson(Map<String, dynamic> json) {
    // Si le backend renvoie un objet 'user', on extrait son id pour 'userId'
    if (json['userId'] == null && json['user'] != null) {
      if (json['user'] is Map) {
        json['userId'] = json['user']['id'];
      } else if (json['user'] is num) {
        json['userId'] = json['user'];
      }
    }
    // Gestion du cas où le montant pourrait être nul par erreur du backend
    if (json['amount'] == null) {
      json['amount'] = 0.0;
    }
    return _$BookingFromJson(json);
  }

  factory Booking.fromId({ // Factory pour créer une réservation sans ID
    required String title,
    String? description,
    required int userId,
    required DateTime startTime,
    required DateTime endTime,
    required BookingType type,
    required double amount,
    BookingStatus? status,
    String? notes,
  }) => _Booking(
    id: 0, // Placeholder ID
    title: title,
    description: description,
    userId: userId,
    startTime: startTime,
    endTime: endTime,
    status: status ?? BookingStatus.pending,
    type: type,
    amount: amount,
    notes: notes,
    createdAt: DateTime.now(),
    updatedAt: null,
  );
}
