package com.studiophoto.photoappbackend.repository;

import com.studiophoto.photoappbackend.model.Order;
import com.studiophoto.photoappbackend.model.OrderItem;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface OrderItemRepository extends JpaRepository<OrderItem, Integer> {
    List<OrderItem> findByOrder(Order order);
}
