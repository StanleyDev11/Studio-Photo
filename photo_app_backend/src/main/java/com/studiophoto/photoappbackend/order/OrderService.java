package com.studiophoto.photoappbackend.order;

import com.studiophoto.photoappbackend.dimension.Dimension;
import com.studiophoto.photoappbackend.dimension.DimensionRepository;
import com.studiophoto.photoappbackend.model.User;
import com.studiophoto.photoappbackend.payment.FedapayInitiateRequest; // Added import
import com.studiophoto.photoappbackend.payment.FedapayInitiateRequest.OrderItemDto; // Added import
import jakarta.transaction.Transactional;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.net.URL;
import java.util.zip.ZipEntry;
import java.util.zip.ZipOutputStream;
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
        // 1. Récupérer tous les prix de la base de données pour éviter de multiples
        // requêtes
        Map<String, BigDecimal> priceMap = dimensionRepository.findAll().stream()
                .collect(Collectors.toMap(Dimension::getName, Dimension::getPrice));

        // 2. Créer l'objet Order principal
        Order newOrder = Order.builder()
                .user(user)
                .paymentMethod(request.getPaymentMethod())
                .deliveryType(request.isExpress() ? "Xpress" : "Standard")
                .deliveryAddress(request.getDeliveryAddress()) // Set delivery address
                .status(OrderStatus.PENDING) // Le statut initial est en attente
                .paymentStatus("PENDING") // Initial payment status
                .build();

        // 3. Créer les OrderItems et calculer le sous-total
        BigDecimal subtotal = BigDecimal.ZERO;
        for (CreateOrderItemRequest itemRequest : request.getItems()) {
            if (itemRequest.getImageUrl() == null || itemRequest.getImageUrl().isBlank()) {
                throw new IllegalArgumentException(
                        "L'URL de l'image ne peut pas être nulle ou vide pour un article de commande.");
            }
            if (itemRequest.getSize() == null) {
                throw new IllegalArgumentException(
                        "Le format de photo ne peut pas être nul pour un article de commande.");
            }
            BigDecimal pricePerUnit = priceMap.get(itemRequest.getSize());
            if (pricePerUnit == null) {
                throw new IllegalArgumentException(
                        "Le format de photo '" + itemRequest.getSize() + "' n'est pas valide.");
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
                throw new IllegalArgumentException(
                        "L'URL de l'image ne peut pas être nulle ou vide pour un article de commande.");
            }
            return OrderItem.builder()
                    .imageUrl(itemDto.getImageUrl())
                    .photoSize(itemDto.getSize())
                    .quantity(itemDto.getQuantity())
                    .pricePerUnit(itemDto.getPrice()) // Assuming price is passed or calculated in
                                                      // FedapayInitiateRequest.OrderItemDto
                    .build();
        }).collect(Collectors.toList());

        if (request.getTotalAmount() == null) {
            throw new IllegalArgumentException("Le montant total ne peut pas être nul pour une commande Fedapay.");
        }
        Order newOrder = Order.builder()
                .user(user)
                .paymentMethod(null) // Payment method will be set after confirmation by webhook
                .deliveryType(request.isExpress() ? "Xpress" : "Standard")
                .deliveryAddress(request.getDeliveryAddress()) // Set delivery address
                .status(OrderStatus.PENDING_PAYMENT) // Initial status for Fedapay
                .paymentStatus("PENDING_PAYMENT") // Initial payment status for Fedapay
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
        if (paymentMethod != null) {
            order.setPaymentMethod(paymentMethod);
        }
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

    public byte[] createOrderPhotosZip(Long orderId, User currentUser) throws IOException {
        Order order = orderRepository.findById(orderId)
                .orElseThrow(() -> new IllegalArgumentException("Commande non trouvée avec l'ID: " + orderId));

        // Verify that the order belongs to the current user (security check)
        if (!order.getUser().getId().equals(currentUser.getId())) {
            throw new IllegalArgumentException("Vous n'êtes pas autorisé à télécharger les photos de cette commande.");
        }

        ByteArrayOutputStream baos = new ByteArrayOutputStream();
        try (ZipOutputStream zos = new ZipOutputStream(baos)) {
            int fileCount = 0;
            for (OrderItem item : order.getOrderItems()) {
                // Generate a unique filename for each photo in the zip
                // Using a combination of order item ID, size, and quantity
                // Plus a counter to handle multiple photos of the same item
                String originalFileName = item.getImageUrl().substring(item.getImageUrl().lastIndexOf('/') + 1);
                String entryName = String.format("%s_%s_%dx_%s", 
                                                order.getOrderNumber(), // Use orderNumber for better identification
                                                item.getPhotoSize().replace(" ", "_"), 
                                                item.getQuantity(), 
                                                originalFileName);
                
                // Fetch the image from the URL
                URL url = new URL(item.getImageUrl());
                try (InputStream is = url.openStream()) {
                    zos.putNextEntry(new ZipEntry(entryName));
                    byte[] buffer = new byte[1024];
                    int len;
                    while ((len = is.read(buffer)) > 0) {
                        zos.write(buffer, 0, len);
                    }
                    zos.closeEntry();
                    fileCount++;
                } catch (IOException e) {
                    // Log the error but continue with other files
                    System.err.println("Failed to download image from " + item.getImageUrl() + ": " + e.getMessage());
                }
            }
            if (fileCount == 0) {
                throw new IOException("No photos were successfully added to the zip file.");
            }
        }
        return baos.toByteArray();
    }

    @Transactional
    public void cancelOrder(Long orderId, User user) {
        Order order = orderRepository.findById(orderId)
                .orElseThrow(() -> new IllegalArgumentException("Commande non trouvée avec l'ID: " + orderId));

        // Check if the order belongs to the user
        if (!order.getUser().getId().equals(user.getId())) {
            throw new IllegalStateException("Vous n'êtes pas autorisé à annuler cette commande.");
        }

        // Check 48h rule
        java.time.LocalDateTime now = java.time.LocalDateTime.now();
        java.time.LocalDateTime createdAt = order.getCreatedAt();
        if (createdAt.plusHours(48).isBefore(now)) {
            throw new IllegalStateException("Le délai d'annulation de 48h est dépassé.");
        }

        if (order.getStatus() == OrderStatus.CANCELLED) {
            throw new IllegalStateException("La commande est déjà annulée.");
        }

        order.setStatus(OrderStatus.CANCELLED);
        orderRepository.save(order);
    }
}
