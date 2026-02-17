package com.studiophoto.photoappbackend.payment;

import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/payments")
@RequiredArgsConstructor
public class PaymentController {

    private final FedapayService fedapayService;

    @PostMapping("/fedapay/initiate")
    public ResponseEntity<FedapayInitiateResponse> initiateFedapayPayment(@RequestBody FedapayInitiateRequest request) {
        FedapayInitiateResponse response = fedapayService.initiatePayment(request);
        return ResponseEntity.ok(response);
    }

    @GetMapping("/fedapay/verify")
    public ResponseEntity<FedapayVerifyResponse> verifyFedapayPayment(@RequestParam("id") String transactionId) {
        FedapayVerifyResponse response = fedapayService.verifyTransaction(transactionId);
        return ResponseEntity.ok(response);
    }
}
