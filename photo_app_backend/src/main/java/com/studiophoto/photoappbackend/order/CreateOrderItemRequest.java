package com.studiophoto.photoappbackend.order;

import lombok.Data;

@Data
public class CreateOrderItemRequest {
    private String imageUrl;
    private String size; // "10x15 cm"
    private int quantity;
}
