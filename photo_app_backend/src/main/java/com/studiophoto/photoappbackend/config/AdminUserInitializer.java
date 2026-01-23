package com.studiophoto.photoappbackend.config;

import com.studiophoto.photoappbackend.model.Role;
import com.studiophoto.photoappbackend.model.Status; // Import Status enum
import com.studiophoto.photoappbackend.model.User;
import com.studiophoto.photoappbackend.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.boot.CommandLineRunner;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;

@Component
@RequiredArgsConstructor
public class AdminUserInitializer implements CommandLineRunner {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;

    @Override
    public void run(String... args) throws Exception {
        // Find user by email to check if it already exists
        userRepository.findByEmail("admin@example.com").ifPresentOrElse(
            // If user exists, ensure status is ACTIVE
            existingAdmin -> {
                if (existingAdmin.getStatus() != Status.ACTIVE) {
                    existingAdmin.setStatus(Status.ACTIVE);
                    userRepository.save(existingAdmin);
                    System.out.println("Existing admin user updated to ACTIVE status: " + existingAdmin.getEmail());
                }
            },
            // If user does not exist, create a new one with ACTIVE status
            () -> {
                var admin = User.builder()
                        .firstname("Admin")
                        .lastname("User")
                        .email("admin@example.com")
                        .password(passwordEncoder.encode("adminpassword")) // Choose a strong default password
                        .role(Role.ADMIN)
                        .status(Status.ACTIVE) // Explicitly set status to ACTIVE
                        .build();
                userRepository.save(admin);
                System.out.println("Default admin user created: admin@example.com");
            }
        );
    }
}
