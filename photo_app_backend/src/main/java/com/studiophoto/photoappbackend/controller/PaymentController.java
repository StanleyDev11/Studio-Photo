package com.studiophoto.photoappbackend.controller;

import com.studiophoto.photoappbackend.dto.PaymentRequest;
import com.studiophoto.photoappbackend.model.Order;
import com.studiophoto.photoappbackend.model.Payment;
import com.studiophoto.photoappbackend.service.OrderService;
import com.studiophoto.photoappbackend.service.PaymentService;
import com.stripe.exception.StripeException;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

@RestController
@RequestMapping("/api/payments")
@RequiredArgsConstructor
public class PaymentController {

    private final PaymentService paymentService;
    private final OrderService orderService; // Inject OrderService

    @GetMapping
    public ResponseEntity<List<Payment>> getAllPayments() {
        return ResponseEntity.ok(paymentService.findAllPayments());
    }

    @GetMapping("/{id}")
    public ResponseEntity<Payment> getPaymentById(@PathVariable Integer id) {
        Optional<Payment> payment = paymentService.findPaymentById(id);
        return payment.map(ResponseEntity::ok).orElseGet(() -> ResponseEntity.notFound().build());
    }

    @PostMapping
    public ResponseEntity<Payment> createPayment(@RequestBody Payment payment) {
        payment.setPaymentDate(LocalDateTime.now());
        // For now, this is just saving payment metadata.
        // Actual processing will be done via /process endpoint
        return ResponseEntity.ok(paymentService.savePayment(payment));
    }

    @PostMapping("/process")
    public ResponseEntity<Payment> processPayment(@RequestBody PaymentRequest paymentRequest) {
        Optional<Order> orderOptional = orderService.findOrderById(paymentRequest.getOrderId());
        if (orderOptional.isEmpty()) {
            return ResponseEntity.notFound().build();
        }
        Order order = orderOptional.get();

        try {
            Payment processedPayment = paymentService.processPayment(order, paymentRequest.getPaymentToken());
            return ResponseEntity.ok(processedPayment);
        } catch (StripeException e) {
            // Log the exception and return appropriate error response
            return ResponseEntity.status(HttpStatus.BAD_REQUEST).build();
        }
    }

    @PutMapping("/{id}")
    public ResponseEntity<Payment> updatePayment(@PathVariable Integer id, @RequestBody Payment payment) {
        if (!paymentService.findPaymentById(id).isPresent()) {
            return ResponseEntity.notFound().build();
        }
        payment.setId(id); // Ensure the ID matches the path variable
        return ResponseEntity.ok(paymentService.savePayment(payment));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deletePayment(@PathVariable Integer id) {
        if (!paymentService.findPaymentById(id).isPresent()) {
            return ResponseEntity.notFound().build();
        }
        paymentService.deletePayment(id);
        return ResponseEntity.noContent().build();
    }
}
