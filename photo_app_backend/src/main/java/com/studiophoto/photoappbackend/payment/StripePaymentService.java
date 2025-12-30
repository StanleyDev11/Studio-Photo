package com.studiophoto.photoappbackend.payment;

import com.studiophoto.photoappbackend.model.Order;
import com.stripe.Stripe;
import com.stripe.exception.StripeException;
import com.stripe.model.Charge;
import com.stripe.param.ChargeCreateParams;
import jakarta.annotation.PostConstruct;
import lombok.NoArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

@Service
@NoArgsConstructor
public class StripePaymentService implements PaymentGatewayService {

    @Value("${stripe.api.secret-key}")
    private String secretKey;

    @PostConstruct
    public void init() {
        Stripe.apiKey = secretKey;
    }

    @Override
    public String createCharge(Order order, String token) throws StripeException {
        ChargeCreateParams params = ChargeCreateParams.builder()
                .setAmount((long) (order.getTotalAmount() * 100)) // amount in cents
                .setCurrency("usd") // TODO: Make currency configurable
                .setDescription("Charge for Order " + order.getId())
                .setSource(token) // obtained with Stripe.js
                .build();
        Charge charge = Charge.create(params);
        return charge.getId();
    }
}
