package com.studiophoto.photoappbackend.payment;

import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/payment")
@RequiredArgsConstructor
public class PaymentReturnController {

    @GetMapping("/callback")
    public ResponseEntity<Void> handleReturn(
            @RequestParam(value = "status", required = false) String status,
            @RequestParam(value = "id", required = false) String transactionId,
            @RequestParam(value = "orderId", required = false) String orderId
    ) {
        String st = status == null ? "pending" : status;
        StringBuilder redirect = new StringBuilder("picon://payment-callback?status=")
                .append(st);
        if (transactionId != null && !transactionId.isBlank()) {
            redirect.append("&id=").append(transactionId);
        }
        if (orderId != null && !orderId.isBlank()) {
            redirect.append("&orderId=").append(orderId);
        }
        HttpHeaders headers = new HttpHeaders();
        headers.add("Location", redirect.toString());
        return new ResponseEntity<>(headers, HttpStatus.FOUND);
    }
}
