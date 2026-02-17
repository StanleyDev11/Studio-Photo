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

import lombok.extern.slf4j.Slf4j;

@Service
@RequiredArgsConstructor
@Slf4j
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
                .orElseThrow(
                        () -> new IllegalArgumentException("Utilisateur non trouvé avec l'ID: " + request.getUserId()));

        // 2. Create a pending order in our database
        // The totalAmount is already calculated by the mobile app, so we use it
        // directly.
        // The items in the request should already have their price per unit if passed
        // from mobile.
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
        transactionPayload.put("callback_url", backendBaseUrl + "/payment/callback?orderId=" + orderId);

        // Customer details
        Map<String, Object> customerPayload = new LinkedHashMap<>();
        if (user.getFirstname() != null) customerPayload.put("firstname", user.getFirstname());
        if (user.getLastname() != null) customerPayload.put("lastname", user.getLastname());
        if (user.getEmail() != null) customerPayload.put("email", user.getEmail());
        String phone = user.getPhone();
        if (phone != null && !phone.isBlank()) {
            if (!phone.startsWith("+")) {
                phone = "+228" + phone;
            }
            Map<String, String> phonePayload = new LinkedHashMap<>();
            phonePayload.put("number", phone);
            phonePayload.put("country", "tg");
            customerPayload.put("phone_number", phonePayload);
        }
        transactionPayload.put("customer", customerPayload);

        // Custom metadata for easier reconciliation
        Map<String, Object> metadata = new LinkedHashMap<>();
        metadata.put("orderId", orderId);
        transactionPayload.put("custom_metadata", metadata);

        try {
            String transactionPayloadString = new com.fasterxml.jackson.databind.ObjectMapper()
                    .writeValueAsString(transactionPayload);
            headers.setContentLength(transactionPayloadString.getBytes().length);
            log.info("Fedapay transaction payload: {}", transactionPayloadString);

            HttpEntity<String> entity = new HttpEntity<>(transactionPayloadString, headers);

            ResponseEntity<Map> response = restTemplate.exchange(
                    fedapayApiBaseUrl + "/transactions",
                    HttpMethod.POST,
                    entity,
                    Map.class);

            if (response.getBody() != null) {
                log.info("Fedapay response status: {}", response.getStatusCode());
                log.info("Fedapay response body: {}", response.getBody());
            }

            if (response.getStatusCode().is2xxSuccessful() && response.getBody() != null) {
                Map<String, Object> responseBody = response.getBody();
                String paymentUrl = extractPaymentUrl(responseBody);
                if (paymentUrl != null && !paymentUrl.isBlank()) {
                    return FedapayInitiateResponse.builder()
                            .paymentUrl(paymentUrl)
                            .orderId(orderId)
                            .build();
                }
            }
            throw new RuntimeException("L'API Fedapay n'a pas retourné d'URL de paiement valide.");

        } catch (com.fasterxml.jackson.core.JsonProcessingException e) {
            throw new RuntimeException("Erreur de conversion des données en JSON", e);
        } catch (Exception e) {
            throw new RuntimeException("Erreur lors de la communication avec l'API Fedapay : " + e.getMessage(), e);
        }
    }

    public FedapayVerifyResponse verifyTransaction(String transactionId) {
        HttpHeaders headers = new HttpHeaders();
        headers.setAccept(Collections.singletonList(MediaType.APPLICATION_JSON));
        headers.set("Authorization", "Bearer " + secretKey);

        HttpEntity<Void> entity = new HttpEntity<>(headers);

        ResponseEntity<Map> response = restTemplate.exchange(
                fedapayApiBaseUrl + "/transactions/" + transactionId,
                HttpMethod.GET,
                entity,
                Map.class);

        if (!response.getStatusCode().is2xxSuccessful() || response.getBody() == null) {
            throw new RuntimeException("Impossible de vérifier la transaction Fedapay.");
        }

        Map<String, Object> responseBody = response.getBody();
        Map<String, Object> transaction = (Map<String, Object>) responseBody.get("transaction");
        if (transaction == null) {
            throw new RuntimeException("Réponse Fedapay invalide.");
        }

        String status = (String) transaction.get("status");
        String description = (String) transaction.get("description");
        Long orderId = null;

        if (description != null && description.startsWith("Payment for Photo Order #")) {
            try {
                orderId = Long.parseLong(description.substring("Payment for Photo Order #".length()));
            } catch (NumberFormatException e) {
                orderId = null;
            }
        }

        if (orderId != null) {
            OrderStatus newOrderStatus;
            String paymentMethod = "Fedapay";
            switch (status) {
                case "approved":
                    newOrderStatus = OrderStatus.PROCESSING;
                    break;
                case "pending":
                    newOrderStatus = OrderStatus.PENDING_PAYMENT;
                    break;
                case "canceled":
                case "failed":
                    newOrderStatus = OrderStatus.CANCELLED;
                    break;
                default:
                    newOrderStatus = OrderStatus.PENDING_PAYMENT;
            }
            orderService.updateOrderStatusAndPaymentMethod(orderId, newOrderStatus, paymentMethod);
        }

        return FedapayVerifyResponse.builder()
                .status(status == null ? "unknown" : status)
                .orderId(orderId)
                .build();
    }

    @SuppressWarnings("unchecked")
    private String extractPaymentUrl(Map<String, Object> responseBody) {
        // Common shapes: {transaction:{payment_url:..}} OR {data:{transaction:{payment_url:..}}}
        Object transaction = responseBody.get("transaction");
        if (transaction instanceof Map) {
            Object url = ((Map<String, Object>) transaction).get("payment_url");
            if (url != null) return url.toString();
        }
        Object data = responseBody.get("data");
        if (data instanceof Map) {
            Object t = ((Map<String, Object>) data).get("transaction");
            if (t instanceof Map) {
                Object url = ((Map<String, Object>) t).get("payment_url");
                if (url != null) return url.toString();
            }
        }
        // Some responses use a "v1/transaction" key
        Object v1Transaction = responseBody.get("v1/transaction");
        if (v1Transaction instanceof Map) {
            Object url = ((Map<String, Object>) v1Transaction).get("payment_url");
            if (url != null) return url.toString();
        }
        // Fallback: scan any key that contains "transaction"
        for (Map.Entry<String, Object> entry : responseBody.entrySet()) {
            if (entry.getKey() != null && entry.getKey().contains("transaction")) {
                Object val = entry.getValue();
                if (val instanceof Map) {
                    Object url = ((Map<String, Object>) val).get("payment_url");
                    if (url != null) return url.toString();
                }
            }
        }
        Object links = responseBody.get("links");
        if (links instanceof Map) {
            Object url = ((Map<String, Object>) links).get("payment_url");
            if (url != null) return url.toString();
        }
        return null;
    }
}
