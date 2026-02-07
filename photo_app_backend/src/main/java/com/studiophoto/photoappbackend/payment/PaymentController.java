package com.studiophoto.photoappbackend.payment;

import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/payments")
@RequiredArgsConstructor
public class PaymentController {

    private final FedapayService fedapayService;
    private final PayDunyaService payDunyaService;

    @PostMapping("/fedapay/initiate")
    public ResponseEntity<FedapayInitiateResponse> initiateFedapayPayment(@RequestBody FedapayInitiateRequest request) {
        FedapayInitiateResponse response = fedapayService.initiatePayment(request);
        return ResponseEntity.ok(response);
    }

    @PostMapping("/paydunya/initiate")
    public ResponseEntity<java.util.Map<String, String>> initiatePaydunyaPayment(@RequestBody java.util.Map<String, Object> request) {
        String paymentUrl = payDunyaService.initiatePayment(request);
        return ResponseEntity.ok(java.util.Map.of("paymentUrl", paymentUrl));
    }
}
