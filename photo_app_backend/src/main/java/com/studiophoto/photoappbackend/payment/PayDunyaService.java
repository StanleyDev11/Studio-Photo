package com.studiophoto.photoappbackend.payment;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

import java.util.HashMap;
import java.util.Map;

@Service
public class PayDunyaService {

    @Value("${paydunya.master-key}")
    private String masterKey;

    @Value("${paydunya.private-key}")
    private String privateKey;

    @Value("${paydunya.token}")
    private String token;

    @Value("${paydunya.checkout-base-url}")
    private String baseUrl;

    public String initiatePayment(Map<String, Object> orderData) {
        RestTemplate restTemplate = new RestTemplate();
        HttpHeaders headers = new HttpHeaders();
        headers.set("PAYDUNYA-MASTER-KEY", masterKey);
        headers.set("PAYDUNYA-PRIVATE-KEY", privateKey);
        headers.set("PAYDUNYA-TOKEN", token);
        headers.set("Content-Type", "application/json");

        Map<String, Object> invoice = new HashMap<>();
        // Ensure totalAmount is handled correctly even if it comes as Integer or Double
        invoice.put("total_amount", String.valueOf(orderData.get("totalAmount")));
        invoice.put("description", "Commande Picon");

        Map<String, String> store = new HashMap<>();
        store.put("name", "Picon");
        store.put("website_url", "http://www.exemple.com");
        invoice.put("store", store);

        // Actions: Redirection after payment
        // Deep Links for Flutter app
        Map<String, String> actions = new HashMap<>();
        actions.put("cancel_url", "picon://payment-callback?status=cancel");
        actions.put("return_url", "picon://payment-callback?status=success");
        invoice.put("actions", actions);

        Map<String, Object> payload = new HashMap<>();
        payload.put("invoice", invoice);

        HttpEntity<Map<String, Object>> request = new HttpEntity<>(payload, headers);

        // Correct endpoint for invoice creation
        String createUrl = baseUrl + "/checkout-invoice/create";

        try {
            ResponseEntity<Map> response = restTemplate.postForEntity(createUrl, request, Map.class);
            if (response.getBody() != null && "00".equals(response.getBody().get("response_code"))) {
                return (String) response.getBody().get("response_text"); // PayDunya returns the payment URL in
                                                                         // 'response_text'
            } else {
                throw new RuntimeException("PayDunya Error: " + response.getBody());
            }
        } catch (Exception e) {
            throw new RuntimeException("Failed to initiate PayDunya payment: " + e.getMessage());
        }
    }
}
