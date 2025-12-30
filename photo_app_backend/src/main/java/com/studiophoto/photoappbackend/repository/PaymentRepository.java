package com.studiophoto.photoappbackend.repository;

import com.studiophoto.photoappbackend.model.Payment;
import org.springframework.data.jpa.repository.JpaRepository;

public interface PaymentRepository extends JpaRepository<Payment, Integer> {
}
