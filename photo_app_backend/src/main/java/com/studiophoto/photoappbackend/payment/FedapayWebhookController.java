package com.studiophoto.photoappbackend.payment;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.studiophoto.photoappbackend.order.OrderService;
import com.studiophoto.photoappbackend.order.OrderStatus;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@RestController
@RequestMapping("/api/payments/fedapay")
@RequiredArgsConstructor
@Slf4j // For logging
public class FedapayWebhookController {

    private final OrderService orderService;
    private final FedapayService fedapayService; // To access SECRET_KEY for signature verification
    private final ObjectMapper objectMapper; // For parsing JSON

    @PostMapping("/webhook")
    public ResponseEntity<String> handleFedapayWebhook(
            @RequestHeader("X-FedaPay-Signature") String fedapaySignature,
            @RequestBody String payloadJson) {

        log.info("Received Fedapay webhook. Signature: {}, Payload: {}", fedapaySignature, payloadJson);

        // 1. Verify webhook signature (CRITICAL SECURITY STEP)
        if (!fedapayService.verifySignature(payloadJson, fedapaySignature)) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body("Invalid webhook signature");
        }

        try {
            // Parse the payload
            Map<String, Object> payload = objectMapper.readValue(payloadJson, Map.class);

            // Extract relevant data
            String event = (String) payload.get("event");
            Map<String, Object> data = (Map<String, Object>) payload.get("data");
            Map<String, Object> transaction = (Map<String, Object>) data.get("transaction");

            if (transaction != null) {
                String transactionStatus = (String) transaction.get("status");
                String fedapayTransactionId = (String) transaction.get("id");
                String description = (String) transaction.get("description"); // We embedded orderId here

                // Extract our orderId from the description
                // Assuming format: "Payment for Photo Order #<orderId>"
                Long orderId = null;
                if (description != null && description.startsWith("Payment for Photo Order #")) {
                    try {
                        orderId = Long.parseLong(description.substring("Payment for Photo Order #".length()));
                    } catch (NumberFormatException e) {
                        log.error("Could not parse orderId from Fedapay description: {}", description, e);
                    }
                }

                if (orderId == null) {
                    log.error("Failed to extract orderId from Fedapay webhook description: {}", description);
                    return ResponseEntity.badRequest().body("Order ID not found or invalid in description.");
                }

                log.info("Processing Fedapay transaction for orderId: {}, Fedapay ID: {}, Status: {}",
                        orderId, fedapayTransactionId, transactionStatus);

                OrderStatus newOrderStatus;
                String paymentMethod = "Fedapay";

                switch (transactionStatus) {
                    case "approved":
                        newOrderStatus = OrderStatus.PROCESSING; // Payment successful, ready for processing
                        break;
                    case "pending":
                        newOrderStatus = OrderStatus.PENDING_PAYMENT; // Still pending, no change or ensure it's set
                        break;
                    case "canceled":
                    case "failed":
                        newOrderStatus = OrderStatus.CANCELLED; // Payment failed or canceled
                        break;
                    default:
                        log.warn("Unhandled Fedapay transaction status: {}", transactionStatus);
                        return ResponseEntity.ok("Unhandled status, no action taken.");
                }

                // Update the order in our database
                orderService.updateOrderStatusAndPaymentMethod(orderId, newOrderStatus, paymentMethod);
                log.info("Order {} updated to status {} with payment method {}", orderId, newOrderStatus, paymentMethod);
            }

            return ResponseEntity.ok("Webhook received and processed successfully.");

        } catch (Exception e) {
            log.error("Error processing Fedapay webhook: {}", e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body("Error processing webhook.");
        }
    }
}
