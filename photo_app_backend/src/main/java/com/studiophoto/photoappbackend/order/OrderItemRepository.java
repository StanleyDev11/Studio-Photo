package com.studiophoto.photoappbackend.order;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface OrderItemRepository extends JpaRepository<OrderItem, Long> {
    // We might not need custom methods here initially, as items will be managed via Order
}
