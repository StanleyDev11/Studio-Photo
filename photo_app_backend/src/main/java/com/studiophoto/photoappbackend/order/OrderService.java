package com.studiophoto.photoappbackend.order;

import com.studiophoto.photoappbackend.dimension.Dimension;
import com.studiophoto.photoappbackend.dimension.DimensionRepository;
import com.studiophoto.photoappbackend.model.User;
import com.studiophoto.photoappbackend.payment.FedapayInitiateRequest; // Added import
import com.studiophoto.photoappbackend.payment.FedapayInitiateRequest.OrderItemDto; // Added import
import jakarta.transaction.Transactional;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;
import java.util.Optional;
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
            if (itemRequest.getImageUrl() == null || itemRequest.getImageUrl().isBlank()) {
                throw new IllegalArgumentException("L'URL de l'image ne peut pas être nulle ou vide pour un article de commande.");
            }
            if (itemRequest.getSize() == null) {
                throw new IllegalArgumentException("Le format de photo ne peut pas être nul pour un article de commande.");
            }
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

    @Transactional
    public Order createPendingOrderForFedapay(FedapayInitiateRequest request, User user) {
        // Build the order items from the FedapayInitiateRequest
        List<OrderItem> orderItems = request.getItems().stream().map(itemDto -> {
            if (itemDto.getImageUrl() == null || itemDto.getImageUrl().isBlank()) {
                throw new IllegalArgumentException("L'URL de l'image ne peut pas être nulle ou vide pour un article de commande.");
            }
            return OrderItem.builder()
                    .imageUrl(itemDto.getImageUrl())
                    .photoSize(itemDto.getSize())
                    .quantity(itemDto.getQuantity())
                    .pricePerUnit(itemDto.getPrice()) // Assuming price is passed or calculated in FedapayInitiateRequest.OrderItemDto
                    .build();
        }).collect(Collectors.toList());

        if (request.getTotalAmount() == null) {
            throw new IllegalArgumentException("Le montant total ne peut pas être nul pour une commande Fedapay.");
        }
        Order newOrder = Order.builder()
                .user(user)
                .paymentMethod(null) // Payment method will be set after confirmation by webhook
                .deliveryType(request.isExpress() ? "Xpress" : "Standard")
                .status(OrderStatus.PENDING_PAYMENT) // Initial status for Fedapay
                .totalAmount(request.getTotalAmount()) // Use total amount from request
                .orderItems(orderItems)
                .build();

        // Set bidirectional relationship for order items
        newOrder.getOrderItems().forEach(item -> item.setOrder(newOrder));

        return orderRepository.save(newOrder);
    }

    @Transactional
    public Order updateOrderStatusAndPaymentMethod(Long orderId, OrderStatus status, String paymentMethod) {
        Order order = orderRepository.findById(orderId)
                .orElseThrow(() -> new IllegalArgumentException("Commande non trouvée avec l'ID: " + orderId));
        order.setStatus(status);
        order.setPaymentMethod(paymentMethod);
        return orderRepository.save(order);
    }

    public List<Order> findOrdersByUser(Integer userId) {
        return orderRepository.findByUserIdOrderByCreatedAtDesc(userId);
    }

    public List<Order> findAll() {
        return orderRepository.findAll();
    }

    public Optional<Order> findById(Long id) {
        return orderRepository.findById(id);
    }
}
