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

@freezed
class Booking with _$Booking {
  const factory Booking({
    required int id,
    required String title,
    String? description,
    required int userId, // User ID linked to the booking
    required DateTime startTime,
    required DateTime endTime,
    required BookingStatus status,
    String? notes,
    required DateTime createdAt,
    DateTime? updatedAt,
  }) = _Booking;

  factory Booking.fromJson(Map<String, Object?> json) => _$BookingFromJson(json);
  factory Booking.fromId({ // Factory to create a booking without ID for creation
    required String title,
    String? description,
    required int userId,
    required DateTime startTime,
    required DateTime endTime,
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
    notes: notes,
    createdAt: DateTime.now(),
    updatedAt: null,
  );
}
