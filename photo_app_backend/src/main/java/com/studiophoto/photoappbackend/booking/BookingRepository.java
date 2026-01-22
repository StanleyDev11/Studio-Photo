package com.studiophoto.photoappbackend.booking;

import com.studiophoto.photoappbackend.model.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.List;

@Repository
public interface BookingRepository extends JpaRepository<Booking, Long>, JpaSpecificationExecutor<Booking> {
    List<Booking> findByUser(User user);
    List<Booking> findByStatus(BookingStatus status);
    List<Booking> findByStartTimeBetween(LocalDateTime start, LocalDateTime end);
    List<Booking> findByUserAndStatus(User user, BookingStatus status);

    long countByStatus(BookingStatus status);
    long countByStartTimeBetween(LocalDateTime start, LocalDateTime end);
}
