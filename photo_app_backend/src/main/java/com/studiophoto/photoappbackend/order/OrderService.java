package com.studiophoto.photoappbackend.order;

import com.studiophoto.photoappbackend.dimension.Dimension;
import com.studiophoto.photoappbackend.dimension.DimensionRepository;
import com.studiophoto.photoappbackend.model.User;
import jakarta.transaction.Transactional;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class OrderService {

    private final OrderRepository orderRepository;
    private final DimensionRepository dimensionRepository;

    @Transactional
    public Order createOrder(CreateOrderRequest request, User user) {
        // 1. Récupérer tous les prix de la base de données pour éviter de multiples requêtes
        Map<String, BigDecimal> priceMap = dimensionRepository.findAll().stream()
                .collect(Collectors.toMap(Dimension::getName, Dimension::getPrice));

        // 2. Créer l'objet Order principal
        Order newOrder = Order.builder()
                .user(user)
                .paymentMethod(request.getPaymentMethod())
                .deliveryType(request.isExpress() ? "Xpress" : "Standard")
                .status(OrderStatus.PENDING) // Le statut initial est en attente
                .build();

        // 3. Créer les OrderItems et calculer le sous-total
        BigDecimal subtotal = BigDecimal.ZERO;
        for (CreateOrderItemRequest itemRequest : request.getItems()) {
            BigDecimal pricePerUnit = priceMap.get(itemRequest.getSize());
            if (pricePerUnit == null) {
                throw new IllegalArgumentException("Le format de photo '" + itemRequest.getSize() + "' n'est pas valide.");
            }

            OrderItem orderItem = OrderItem.builder()
                    .imageUrl(itemRequest.getImageUrl())
                    .photoSize(itemRequest.getSize())
                    .quantity(itemRequest.getQuantity())
                    .pricePerUnit(pricePerUnit)
                    .build();

            newOrder.addOrderItem(orderItem);
            subtotal = subtotal.add(pricePerUnit.multiply(new BigDecimal(itemRequest.getQuantity())));
        }

        // 4. Ajouter les frais de livraison si nécessaire
        BigDecimal totalAmount = subtotal;
        if (request.isExpress() && request.getItems().size() <= 10) {
            totalAmount = totalAmount.add(new BigDecimal("1500"));
        }

        newOrder.setTotalAmount(totalAmount);

        // 5. Sauvegarder la commande (et les OrderItems grâce à CascadeType.ALL)
        return orderRepository.save(newOrder);
    }

    public List<Order> findOrdersByUser(Integer userId) {
        return orderRepository.findByUserIdOrderByCreatedAtDesc(userId);
    }

    public List<Order> findAll() {
        return orderRepository.findAll();
    }
}
