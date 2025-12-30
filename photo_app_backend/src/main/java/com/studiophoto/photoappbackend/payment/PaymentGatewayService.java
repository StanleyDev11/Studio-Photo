package com.studiophoto.photoappbackend.payment;

import com.studiophoto.photoappbackend.model.Order;
import com.stripe.exception.StripeException;

public interface PaymentGatewayService {
    String createCharge(Order order, String token) throws StripeException;
    // Potentially add methods for refunds, subscriptions, etc.
}
