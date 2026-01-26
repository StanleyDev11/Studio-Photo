package com.studiophoto.photoappbackend.repository;

import com.studiophoto.photoappbackend.model.User;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface UserRepository extends JpaRepository<User, Integer> {

    Optional<User> findByEmail(String email);
    Optional<User> findByPhone(String phone);

    boolean existsByEmail(String email);
}
