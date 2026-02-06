package com.studiophoto.photoappbackend.order;

import lombok.Data;

import java.util.ArrayList;
import java.util.List;

@Data
public class CreateOrderRequest {
    private boolean isExpress;
    private String paymentMethod;
    private String deliveryAddress; // Added delivery address field
    private List<CreateOrderItemRequest> items = new ArrayList<>();
}
