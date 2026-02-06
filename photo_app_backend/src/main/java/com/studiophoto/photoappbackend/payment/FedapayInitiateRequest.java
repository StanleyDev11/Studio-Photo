package com.studiophoto.photoappbackend.payment;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.util.List;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class FedapayInitiateRequest {
    private Long userId;
    private String paymentMethod;
    private boolean isExpress;
    private String deliveryAddress; // Added delivery address field
    private BigDecimal totalAmount; // Added totalAmount from mobile app
    private List<OrderItemDto> items;

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class OrderItemDto {
        private String imageUrl;
        private String size;
        private Integer quantity;
        private BigDecimal price; // Price per unit, might be needed for Fedapay
    }
}
