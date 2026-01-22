package com.studiophoto.photoappbackend.admin;

import com.studiophoto.photoappbackend.booking.Booking;
import com.studiophoto.photoappbackend.booking.BookingService;
import com.studiophoto.photoappbackend.booking.BookingStatus;
import com.studiophoto.photoappbackend.model.User;
import com.studiophoto.photoappbackend.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/admin/bookings/api")
@RequiredArgsConstructor
public class AdminBookingApiController {

    private final BookingService bookingService;
    private final UserRepository userRepository;

    @PostMapping
    public ResponseEntity<Booking> createBooking(@RequestBody AdminBookingRequest bookingRequest) {
        Booking newBooking = new Booking();
        User user = userRepository.findById(bookingRequest.getUserId())
                .orElseThrow(() -> new IllegalArgumentException("User not found with ID: " + bookingRequest.getUserId()));
        newBooking.setUser(user);
        newBooking.setTitle(bookingRequest.getTitle());
        newBooking.setStartTime(bookingRequest.getStartTime());
        newBooking.setEndTime(bookingRequest.getEndTime());
        newBooking.setType(bookingRequest.getType());
        newBooking.setStatus(bookingRequest.getStatus());
        newBooking.setAmount(bookingRequest.getAmount());
        newBooking.setNotes(bookingRequest.getNotes());
        return ResponseEntity.ok(bookingService.createBooking(newBooking));
    }

    @PutMapping("/{id}")
    public ResponseEntity<Booking> updateBooking(@PathVariable Long id, @RequestBody AdminBookingRequest bookingRequest) {
        User user = userRepository.findById(bookingRequest.getUserId())
                .orElseThrow(() -> new IllegalArgumentException("User not found with ID: " + bookingRequest.getUserId()));
        
        Booking booking = bookingService.getBookingById(id)
                .orElseThrow(() -> new IllegalArgumentException("Booking not found with ID: " + id));
        
        booking.setUser(user);
        booking.setTitle(bookingRequest.getTitle());
        booking.setStartTime(bookingRequest.getStartTime());
        booking.setEndTime(bookingRequest.getEndTime());
        booking.setType(bookingRequest.getType());
        booking.setStatus(bookingRequest.getStatus());
        booking.setAmount(bookingRequest.getAmount());
        booking.setNotes(bookingRequest.getNotes());
        
        return ResponseEntity.ok(bookingService.updateBooking(id, booking));
    }

    @GetMapping("/{id}")
    public ResponseEntity<Booking> getBookingById(@PathVariable Long id) {
        return bookingService.getBookingById(id)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteBooking(@PathVariable Long id) {
        bookingService.deleteBooking(id);
        return ResponseEntity.ok().build();
    }

    @PostMapping("/{id}/confirm")
    public ResponseEntity<Booking> confirmBooking(@PathVariable Long id) {
        Booking updatedBooking = bookingService.updateBookingStatus(id, BookingStatus.CONFIRMED);
        return ResponseEntity.ok(updatedBooking);
    }

    @PostMapping("/{id}/cancel")
    public ResponseEntity<Booking> cancelBooking(@PathVariable Long id) {
        Booking updatedBooking = bookingService.updateBookingStatus(id, BookingStatus.CANCELLED);
        return ResponseEntity.ok(updatedBooking);
    }

    @GetMapping("/stats")
    public ResponseEntity<BookingStats> getStats() {
        return ResponseEntity.ok(bookingService.getBookingStats());
    }

    @GetMapping("/datatable")
    public ResponseEntity<Map<String, Object>> getBookingsForDatatable(
            @RequestParam int draw,
            @RequestParam int start,
            @RequestParam int length,
            @RequestParam(name = "search[value]") String searchValue,
            @RequestParam(name = "order[0][column]") int orderColumn,
            @RequestParam(name = "order[0][dir]") String orderDir,
            @RequestParam(required = false) String status,
            @RequestParam(required = false) String dateRange,
            @RequestParam(required = false) Long userId) {

        Map<String, Object> dataTableResponse = bookingService.getBookingDataTable(
                draw, start, length, searchValue, orderColumn, orderDir, status, dateRange, userId
        );
        return ResponseEntity.ok(dataTableResponse);
    }

    @GetMapping("/calendar")
    public ResponseEntity<List<CalendarEvent>> getCalendarEvents(
            @RequestParam(required = false) String start,
            @RequestParam(required = false) String end) {

        LocalDateTime startDate = (start != null && !start.isEmpty()) ? LocalDate.parse(start).atStartOfDay() : null;
        LocalDateTime endDate = (end != null && !end.isEmpty()) ? LocalDate.parse(end).atTime(23, 59, 59) : null;

        List<Booking> bookings = bookingService.getBookingsForCalendar(startDate, endDate);
        List<CalendarEvent> events = bookings.stream()
                .map(booking -> CalendarEvent.builder()
                        .id(booking.getId())
                        .title(booking.getTitle() + " (" + booking.getUser().getFirstname() + " " + booking.getUser().getLastname() + ")")
                        .start(booking.getStartTime())
                        .end(booking.getEndTime())
                        .color(booking.getStatus().getColor())
                        .allDay(false)
                        .build())
                .collect(Collectors.toList());
        return ResponseEntity.ok(events);
    }
}

