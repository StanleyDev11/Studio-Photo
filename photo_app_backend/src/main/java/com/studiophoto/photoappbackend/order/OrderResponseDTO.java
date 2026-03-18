package com.studiophoto.photoappbackend.order;

import com.fasterxml.jackson.annotation.JsonFormat;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;
import java.util.stream.Collectors;

/**
 * DTO de réponse pour les commandes.
 * Garantit que tous les champs renvoyés au client Flutter sont non-null
 * avec des valeurs par défaut appropriées.
 */
public class OrderResponseDTO {

    private Long id;
    private List<OrderItemDTO> orderItems;
    private String status;
    private BigDecimal totalAmount;
    private String paymentMethod;
    private String deliveryType;
    private String deliveryAddress;

    @JsonFormat(pattern = "yyyy-MM-dd'T'HH:mm:ss")
    private LocalDateTime createdAt;

    // ── Constructeur de mapping depuis l'entité ─────────────────────────────
    public static OrderResponseDTO from(Order order) {
        OrderResponseDTO dto = new OrderResponseDTO();
        dto.id = order.getId();
        dto.status = order.getStatus() != null ? order.getStatus().name() : "UNKNOWN";
        dto.totalAmount = order.getTotalAmount() != null ? order.getTotalAmount() : BigDecimal.ZERO;
        // Valeurs par défaut garanties
        dto.paymentMethod = order.getPaymentMethod() != null ? order.getPaymentMethod() : "NON_RENSEIGNE";
        dto.deliveryType = order.getDeliveryType() != null ? order.getDeliveryType() : "Standard";
        dto.deliveryAddress = order.getDeliveryAddress();
        dto.createdAt = order.getCreatedAt() != null ? order.getCreatedAt() : LocalDateTime.now();
        dto.orderItems = order.getOrderItems() != null
                ? order.getOrderItems().stream()
                        .map(OrderItemDTO::from)
                        .collect(Collectors.toList())
                : List.of();
        return dto;
    }

    // ── Getters ────────────────────────────────────────────────────────────
    public Long getId() {
        return id;
    }

    public List<OrderItemDTO> getOrderItems() {
        return orderItems;
    }

    public String getStatus() {
        return status;
    }

    public BigDecimal getTotalAmount() {
        return totalAmount;
    }

    public String getPaymentMethod() {
        return paymentMethod;
    }

    public String getDeliveryType() {
        return deliveryType;
    }

    public String getDeliveryAddress() {
        return deliveryAddress;
    }

    public LocalDateTime getCreatedAt() {
        return createdAt;
    }

    // ── DTO imbriqué pour OrderItem ────────────────────────────────────────
    public static class OrderItemDTO {
        private Long id;
        private String imageUrl;
        private String photoSize;
        private int quantity;
        private BigDecimal pricePerUnit;

        public static OrderItemDTO from(OrderItem item) {
            OrderItemDTO dto = new OrderItemDTO();
            dto.id = item.getId();
            dto.imageUrl = item.getImageUrl() != null ? item.getImageUrl() : "";
            dto.photoSize = item.getPhotoSize() != null ? item.getPhotoSize() : "—";
            dto.quantity = item.getQuantity();
            dto.pricePerUnit = item.getPricePerUnit() != null ? item.getPricePerUnit() : BigDecimal.ZERO;
            return dto;
        }

        public Long getId() {
            return id;
        }

        public String getImageUrl() {
            return imageUrl;
        }

        public String getPhotoSize() {
            return photoSize;
        }

        public int getQuantity() {
            return quantity;
        }

        public BigDecimal getPricePerUnit() {
            return pricePerUnit;
        }
    }
}
