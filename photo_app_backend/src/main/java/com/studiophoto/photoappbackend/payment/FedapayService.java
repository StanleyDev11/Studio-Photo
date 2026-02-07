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

import java.math.BigDecimal;
import java.nio.charset.StandardCharsets;
import java.util.Base64;
import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class FedapayService {

    private final OrderService orderService;
    private final DimensionRepository dimensionRepository;
    private final RestTemplate restTemplate;
    private final UserRepository userRepository; // Injected UserRepository

    // Fedapay API keys (from user prompt)
    // TODO: Store these keys securely, e.g., in application.properties or environment variables.
    private final String PUBLIC_KEY = "pk_sandbox_LNC4KNFoONbjhlBWh9kwRgSU";
    private final String SECRET_KEY = "sk_sandbox_5eglTc3hCd6lTA8agN_O32jz";

    // Fedapay Sandbox API endpoint
    private static final String FEDAPAY_API_BASE_URL = "https://sandbox-api.fedapay.com/v1";
    private static final String FEDAPAY_TRANSACTIONS_ENDPOINT = FEDAPAY_API_BASE_URL + "/transactions";
    // TODO: Make this configurable (e.g., from application.properties)
    private static final String BACKEND_BASE_URL = "http://109.176.197.158:8080";

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
        
        // Basic Authentication with Secret Key
        String auth = SECRET_KEY + ":";
        byte[] encodedAuth = Base64.getEncoder().encode(auth.getBytes(StandardCharsets.UTF_8));
        String authHeader = "Basic " + new String(encodedAuth);
        headers.set("Authorization", authHeader);

        Map<String, Object> transactionPayload = new LinkedHashMap<>();
        transactionPayload.put("amount", request.getTotalAmount().multiply(BigDecimal.valueOf(100)).intValue()); // Convert to cents for Fedapay
        transactionPayload.put("currency", "XOF");
        // Use orderId in description for webhook to retrieve later
        transactionPayload.put("description", "Payment for Photo Order #" + orderId);
        transactionPayload.put("callback_url", BACKEND_BASE_URL + "/api/payments/fedapay/webhook"); // Our webhook endpoint
        transactionPayload.put("cancel_url", BACKEND_BASE_URL + "/payment_cancel"); // TODO: Define a proper cancel URL

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
                    FEDAPAY_TRANSACTIONS_ENDPOINT,
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
