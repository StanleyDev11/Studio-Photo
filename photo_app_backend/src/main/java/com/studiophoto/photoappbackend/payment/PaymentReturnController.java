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
    public ResponseEntity<String> handleReturn(
            @RequestParam(value = "status", required = false) String status,
            @RequestParam(value = "id", required = false) String transactionId,
            @RequestParam(value = "orderId", required = false) String orderId
    ) {
        String st = status == null ? "pending" : status;
        StringBuilder payload = new StringBuilder("status=").append(st);
        if (transactionId != null && !transactionId.isBlank()) {
            payload.append("&id=").append(transactionId);
        }
        if (orderId != null && !orderId.isBlank()) {
            payload.append("&orderId=").append(orderId);
        }
        String body = "<html><head><title>Paiement</title></head>"
                + "<body style=\"font-family: sans-serif; text-align:center; padding:30px;\">"
                + "<h3>Paiement en cours</h3>"
                + "<p>Vous pouvez retourner dans l'application.</p>"
                + "<p>Détails: " + payload + "</p>"
                + "</body></html>";
        return ResponseEntity.ok(body);
    }
}
