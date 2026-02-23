package com.studiophoto.photoappbackend.order;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

@Repository
public interface OrderRepository extends JpaRepository<Order, Long> {

    // Find all orders for a specific user, ordered by creation date descending
    List<Order> findByUserIdOrderByCreatedAtDesc(Integer userId);

<<<<<<< HEAD
    // Find all orders ordered by creation date descending
    List<Order> findAllByOrderByCreatedAtDesc();
=======
    long countByStatus(OrderStatus status);

    long countByCreatedAtBetween(LocalDateTime start, LocalDateTime end);

    @Query("SELECT SUM(o.totalAmount) FROM Order o WHERE o.status IN :statuses AND o.createdAt BETWEEN :start AND :end")
    BigDecimal sumTotalAmountByStatusInAndCreatedAtBetween(
            @Param("statuses") List<OrderStatus> statuses,
            @Param("start") LocalDateTime start,
            @Param("end") LocalDateTime end);
            
    List<Order> findTop5ByOrderByCreatedAtDesc();

    List<Order> findByCreatedAtBetweenOrderByCreatedAtDesc(LocalDateTime start, LocalDateTime end);
>>>>>>> 13c0867e5e4fad9169bcb9b9eaad78c7f821be97
}
