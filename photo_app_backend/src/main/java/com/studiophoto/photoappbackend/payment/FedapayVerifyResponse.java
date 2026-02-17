package com.studiophoto.photoappbackend.payment;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class FedapayVerifyResponse {
    private String status;
    private Long orderId;
}
