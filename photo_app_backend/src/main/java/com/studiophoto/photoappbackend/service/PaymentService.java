package com.studiophoto.photoappbackend.service;

import com.studiophoto.photoappbackend.model.Order;
import com.studiophoto.photoappbackend.model.Payment;
import com.studiophoto.photoappbackend.model.PaymentStatus;
import com.studiophoto.photoappbackend.payment.PaymentGatewayService;
import com.studiophoto.photoappbackend.repository.PaymentRepository;
import com.stripe.exception.StripeException;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

@Service
@RequiredArgsConstructor
public class PaymentService {

    private final PaymentRepository paymentRepository;
    private final PaymentGatewayService paymentGatewayService; // Inject PaymentGatewayService

    public List<Payment> findAllPayments() {
        return paymentRepository.findAll();
    }

    public Optional<Payment> findPaymentById(Integer id) {
        return paymentRepository.findById(id);
    }

    public Payment savePayment(Payment payment) {
        return paymentRepository.save(payment);
    }

    public void deletePayment(Integer id) {
        paymentRepository.deleteById(id);
    }

    public Payment processPayment(Order order, String paymentToken) throws StripeException {
        // Create a new Payment record
        Payment payment = Payment.builder()
                .order(order)
                .paymentDate(LocalDateTime.now())
                .amount(order.getTotalAmount())
                .status(PaymentStatus.PENDING) // Set to PENDING initially
                // .paymentMethod(determinePaymentMethod(paymentToken)) // Logic to determine method
                .build();

        // Process charge with payment gateway
        String transactionId = paymentGatewayService.createCharge(order, paymentToken);
        payment.setTransactionId(transactionId);
        payment.setStatus(PaymentStatus.COMPLETED); // If charge is successful

        return paymentRepository.save(payment);
    }
}
