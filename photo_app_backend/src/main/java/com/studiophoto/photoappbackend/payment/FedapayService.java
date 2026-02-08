package com.studiophoto.photoappbackend.payment;

import com.studiophoto.photoappbackend.dimension.Dimension;
import com.studiophoto.photoappbackend.dimension.DimensionRepository;
import com.studiophoto.photoappbackend.model.User; // Added import
import com.studiophoto.photoappbackend.order.CreateOrderRequest;
import com.studiophoto.photoappbackend.order.Order; // Added import
import com.studiophoto.photoappbackend.order.OrderService;
import com.studiophoto.photoappbackend.order.OrderStatus;
import com.studiophoto.photoappbackend.repository.UserRepository; // Added import
import lombok.RequiredArgsConstructor;
import org.springframework.http.*;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;
import org.springframework.web.util.UriComponentsBuilder;
import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.security.InvalidKeyException;
import java.security.NoSuchAlgorithmException;
import java.util.Objects;

import java.math.BigDecimal;
import java.nio.charset.StandardCharsets;
import java.util.Base64;
import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.UUID;
import java.util.stream.Collectors;

import org.springframework.beans.factory.annotation.Value;

@Service
@RequiredArgsConstructor
public class FedapayService {

    private final OrderService orderService;
    private final DimensionRepository dimensionRepository;
    private final RestTemplate restTemplate;
    private final UserRepository userRepository; // Injected UserRepository

    @Value("${fedapay.public-key}")
    private String publicKey;

    @Value("${fedapay.secret-key}")
    private String secretKey;

    @Value("${fedapay.api-base-url}")
    private String fedapayApiBaseUrl;

    @Value("${backend.base-url}")
    private String backendBaseUrl;

    @Value("${fedapay.webhook-secret}")
    private String webhookSecret;

    public boolean verifySignature(String payload, String signature) {
        try {
            Mac sha256_HMAC = Mac.getInstance("HmacSHA256");
            SecretKeySpec secret_key = new SecretKeySpec(webhookSecret.getBytes(), "HmacSHA256");
            sha256_HMAC.init(secret_key);
            String hash = bytesToHex(sha256_HMAC.doFinal(payload.getBytes()));
            return Objects.equals(hash, signature);
        } catch (NoSuchAlgorithmException | InvalidKeyException e) {
            // It is recommended to log the exception
            return false;
        }
    }

    private String bytesToHex(byte[] bytes) {
        final char[] hexArray = "0123456789abcdef".toCharArray();
        char[] hexChars = new char[bytes.length * 2];
        for (int j = 0; j < bytes.length; j++) {
            int v = bytes[j] & 0xFF;
            hexChars[j * 2] = hexArray[v >>> 4];
            hexChars[j * 2 + 1] = hexArray[v & 0x0F];
        }
        return new String(hexChars);
    }

    public FedapayInitiateResponse initiatePayment(FedapayInitiateRequest request) {
        // 1. Retrieve User
        User user = userRepository.findById(request.getUserId().intValue())
                .orElseThrow(() -> new IllegalArgumentException("Utilisateur non trouvé avec l'ID: " + request.getUserId()));

        // 2. Create a pending order in our database
        // The totalAmount is already calculated by the mobile app, so we use it directly.
        // The items in the request should already have their price per unit if passed from mobile.
        Order pendingOrder = orderService.createPendingOrderForFedapay(request, user);
        Long orderId = pendingOrder.getId();

        // 3. Prepare Fedapay API request
        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_JSON);
        headers.setAccept(Collections.singletonList(MediaType.APPLICATION_JSON));
        
        // Set Authorization header for Fedapay API
        headers.set("Authorization", "Bearer " + secretKey);

        Map<String, Object> transactionPayload = new LinkedHashMap<>();
        transactionPayload.put("amount", request.getTotalAmount().intValue());
        
        Map<String, String> currencyPayload = new LinkedHashMap<>();
        currencyPayload.put("iso", "XOF");
        transactionPayload.put("currency", currencyPayload);

        // Use orderId in description for webhook to retrieve later
        transactionPayload.put("description", "Payment for Photo Order #" + orderId);
        transactionPayload.put("callback_url", backendBaseUrl + "/api/payments/fedapay/webhook"); // Our webhook endpoint
        transactionPayload.put("cancel_url", backendBaseUrl + "/payment_cancel"); // TODO: Define a proper cancel URL

        // Customer details
        Map<String, String> customerPayload = new LinkedHashMap<>();
        customerPayload.put("firstname", user.getFirstname());
        customerPayload.put("lastname", user.getLastname());
        customerPayload.put("email", user.getEmail());
        customerPayload.put("phone_number", user.getPhone());
        customerPayload.put("country", "TG"); // Assuming Togo, TODO: Make dynamic or configurable
        transactionPayload.put("customer", customerPayload);

        HttpEntity<Map<String, Object>> entity = new HttpEntity<>(transactionPayload, headers);

        try {
            ResponseEntity<Map> response = restTemplate.exchange(
                    fedapayApiBaseUrl + "/transactions",
                    HttpMethod.POST,
                    entity,
                    Map.class
            );

            if (response.getStatusCode().is2xxSuccessful() && response.getBody() != null) {
                Map<String, Object> responseBody = response.getBody();
                if (responseBody.containsKey("transaction")) {
                    Map<String, Object> transaction = (Map<String, Object>) responseBody.get("transaction");
                    if (transaction.containsKey("payment_url")) {
                        return FedapayInitiateResponse.builder()
                                .paymentUrl(transaction.get("payment_url").toString())
                                .build();
                    }
                }
            }
            throw new RuntimeException("Fedapay API did not return a valid payment URL.");

        } catch (Exception e) {
            throw new RuntimeException("Error communicating with Fedapay API: " + e.getMessage(), e);
        }
    }
}
