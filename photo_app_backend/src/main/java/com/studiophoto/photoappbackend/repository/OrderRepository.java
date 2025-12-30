package com.studiophoto.photoappbackend.repository;

import com.studiophoto.photoappbackend.model.Order;
import com.studiophoto.photoappbackend.model.User;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface OrderRepository extends JpaRepository<Order, Integer> {
    List<Order> findByClient(User client);
}
