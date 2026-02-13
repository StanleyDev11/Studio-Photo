package com.studiophoto.photoappbackend.payment;

import com.studiophoto.photoappbackend.order.OrderService;
import com.studiophoto.photoappbackend.order.OrderStatus;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@RestController
@RequestMapping("/api/payments/paydunya")
@RequiredArgsConstructor
@Slf4j
public class PayDunyaIPNController {

    private final OrderService orderService;

    @PostMapping("/ipn")
    public ResponseEntity<String> handlePayDunyaIPN(@RequestBody Map<String, Object> payload) {
        log.info("Received PayDunya IPN payload: {}", payload);

        try {
            // PayDunya IPN usually sends a JSON body with a 'data' object
            Map<String, Object> data = (Map<String, Object>) payload.get("data");
            if (data == null) {
                // Check if it's directly in the body (different versions of IPN)
                data = payload;
            }

            Map<String, Object> invoice = (Map<String, Object>) data.get("invoice");
            if (invoice == null) {
                log.warn("No invoice data found in PayDunya IPN payload");
                return ResponseEntity.ok("No invoice in data");
            }

            String status = (String) invoice.get("status");
            Map<String, Object> customData = (Map<String, Object>) invoice.get("custom_data");

            if (customData != null && customData.containsKey("order_id")) {
                Long orderId = Long.parseLong(customData.get("order_id").toString());

                log.info("Processing PayDunya IPN for orderId: {}, Status: {}", orderId, status);

                OrderStatus newOrderStatus = null;
                if ("completed".equalsIgnoreCase(status)) {
                    newOrderStatus = OrderStatus.PROCESSING;
                } else if ("cancelled".equalsIgnoreCase(status)) {
                    newOrderStatus = OrderStatus.CANCELLED;
                }

                if (newOrderStatus != null) {
                    orderService.updateOrderStatusAndPaymentMethod(orderId, newOrderStatus, "PayDunya");
                    log.info("Order {} updated to {} via PayDunya IPN", orderId, newOrderStatus);
                }
            } else {
                log.warn("No order_id found in custom_data for PayDunya IPN");
            }

            return ResponseEntity.ok("IPN Processed");
        } catch (Exception e) {
            log.error("Error processing PayDunya IPN: {}", e.getMessage(), e);
            return ResponseEntity.internalServerError().body("Error processing IPN");
        }
    }
}
