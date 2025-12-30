package com.studiophoto.photoappbackend.service;

import com.studiophoto.photoappbackend.model.Order;
import com.studiophoto.photoappbackend.model.User;
import com.studiophoto.photoappbackend.repository.OrderRepository;
import com.studiophoto.photoappbackend.repository.OrderItemRepository; // Added for completeness
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Optional;

@Service
@RequiredArgsConstructor
public class OrderService {

    private final OrderRepository orderRepository;
    private final OrderItemRepository orderItemRepository; // Inject OrderItemRepository

    public List<Order> findAllOrders() {
        return orderRepository.findAll();
    }

    public Optional<Order> findOrderById(Integer id) {
        return orderRepository.findById(id);
    }

    public List<Order> findOrdersByClient(User client) {
        return orderRepository.findByClient(client);
    }

    public Order saveOrder(Order order) {
        return orderRepository.save(order);
    }

    public void deleteOrder(Integer id) {
        orderRepository.deleteById(id);
    }

    // You might add methods to manage order items within an order here
}
