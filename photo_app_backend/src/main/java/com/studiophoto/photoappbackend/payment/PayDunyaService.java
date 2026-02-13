package com.studiophoto.photoappbackend.payment;

import com.studiophoto.photoappbackend.order.Order;
import com.studiophoto.photoappbackend.order.OrderService;
import com.studiophoto.photoappbackend.order.OrderStatus;
import com.studiophoto.photoappbackend.repository.UserRepository;
import com.studiophoto.photoappbackend.model.User;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

import java.util.HashMap;
import java.util.Map;
import java.util.stream.Collectors;
import java.util.List;

@Service
@RequiredArgsConstructor
public class PayDunyaService {

    private final OrderService orderService;
    private final UserRepository userRepository;

    @Value("${paydunya.master-key}")
    private String masterKey;

    @Value("${paydunya.private-key}")
    private String privateKey;

    @Value("${paydunya.token}")
    private String token;

    @Value("${paydunya.checkout-base-url}")
    private String baseUrl;

    public String initiatePayment(Map<String, Object> orderData) {
        // 1. Retrieve User
        Long userId = Long.valueOf(orderData.get("userId").toString());
        User user = userRepository.findById(userId.intValue())
                .orElseThrow(() -> new IllegalArgumentException("Utilisateur non trouvé avec l'ID: " + userId));

        // 2. Create a pending order (reusing Fedapay logic or adapting)
        // Convert Map to FedapayInitiateRequest for reuse
        FedapayInitiateRequest initiateRequest = FedapayInitiateRequest.builder()
                .userId(userId)
                .isExpress((Boolean) orderData.get("isExpress"))
                .totalAmount(new java.math.BigDecimal(orderData.get("totalAmount").toString()))
                .items(((List<Map<String, Object>>) orderData.get("items")).stream()
                        .map(item -> FedapayInitiateRequest.OrderItemDto.builder()
                                .imageUrl((String) item.get("imageUrl"))
                                .size((String) item.get("size"))
                                .quantity((Integer) item.get("quantity"))
                                .price(new java.math.BigDecimal(item.get("price").toString()))
                                .build())
                        .collect(Collectors.toList()))
                .build();

        Order pendingOrder = orderService.createPendingOrderForFedapay(initiateRequest, user);
        Long orderId = pendingOrder.getId();

        RestTemplate restTemplate = new RestTemplate();
        HttpHeaders headers = new HttpHeaders();
        headers.set("PAYDUNYA-MASTER-KEY", masterKey);
        headers.set("PAYDUNYA-PRIVATE-KEY", privateKey);
        headers.set("PAYDUNYA-TOKEN", token);
        headers.set("Content-Type", "application/json");

        Map<String, Object> invoice = new HashMap<>();
        invoice.put("total_amount", String.valueOf(orderData.get("totalAmount")));
        invoice.put("description", "Paiement pour la commande Photo #" + orderId);

        // Add custom data for IPN tracking
        Map<String, String> customData = new HashMap<>();
        customData.put("order_id", String.valueOf(orderId));
        invoice.put("custom_data", customData);

        Map<String, String> store = new HashMap<>();
        store.put("name", "Picon");
        store.put("website_url", "http://www.piconstudio.com");
        invoice.put("store", store);

        // Actions: Redirection after payment
        Map<String, String> actions = new HashMap<>();
        actions.put("cancel_url", "picon://payment-callback?status=cancel&orderId=" + orderId);
        actions.put("return_url", "picon://payment-callback?status=success&orderId=" + orderId);
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
                throw new RuntimeException("Erreur PayDunya : " + response.getBody());
            }
        } catch (Exception e) {
            throw new RuntimeException("Échec de l'initialisation du paiement PayDunya : " + e.getMessage(), e);
        }
    }
}
