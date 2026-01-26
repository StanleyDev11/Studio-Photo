package com.studiophoto.photoappbackend.auth;

import com.studiophoto.photoappbackend.model.Role;
import com.studiophoto.photoappbackend.model.Status; // Import Status enum
import com.studiophoto.photoappbackend.model.User;
import com.studiophoto.photoappbackend.repository.UserRepository;
import com.studiophoto.photoappbackend.security.JwtService;
import lombok.RequiredArgsConstructor;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.HashMap;
import java.util.Map;
import java.util.Optional;

@Service
@RequiredArgsConstructor
public class AuthenticationService {

    private final UserRepository repository;
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwtService;
    private final AuthenticationManager authenticationManager;
    // private final EmailService emailService; // EmailService will be added later

    public AuthenticationResponse register(RegisterRequest request) {
        var user = User.builder()
                .firstname(request.getFirstname())
                .lastname(request.getLastname())
                .email(request.getEmail())
                .phone(request.getPhone())
                .pin(request.getPin())
                .password(passwordEncoder.encode(request.getPassword()))
                .role(Role.USER) // Default role for new users
                .status(Status.ACTIVE) // Set status to ACTIVE by default
                .build();
        repository.save(user);
        var jwtToken = jwtService.generateToken(user);

        // Send welcome email - uncomment when EmailService is implemented
        // emailService.sendSimpleEmail(
        //         user.getEmail(),
        //         "Welcome to Photo Studio App!",
        //         "Hello " + user.getFirstname() + "\n\nWelcome to our Photo Studio Application. We are glad to have you!"
        // );

        return AuthenticationResponse.builder()
                .token(jwtToken)
                .build();
    }

    public AuthenticationResponse authenticate(LoginRequest request) {
        String identifier; // This will be email or phone
        User user;

        if (request.getEmail() != null && !request.getEmail().isEmpty()) {
            identifier = request.getEmail();
            user = repository.findByEmail(identifier)
                    .orElseThrow(() -> new BadCredentialsException("Email ou mot de passe incorrect."));
        } else if (request.getPhone() != null && !request.getPhone().isEmpty()) {
            identifier = request.getPhone();
            user = repository.findByPhone(identifier)
                    .orElseThrow(() -> new BadCredentialsException("Email ou mot de passe incorrect."));
        } else {
            throw new IllegalArgumentException("L'email ou le numéro de téléphone doit être fourni.");
        }

        authenticationManager.authenticate(
                new UsernamePasswordAuthenticationToken(
                        identifier,
                        request.getPassword()
                )
        );
        // user should exist if authentication is successful

        var jwtToken = jwtService.generateToken(user);
        return AuthenticationResponse.builder()
                .token(jwtToken)
                .build();
    }

    // Method to verify PIN for password reset and generate a reset token
    public String verifyPinForPasswordReset(String identifier, String pin) {
        User user;
        if (identifier.contains("@")) { // Assuming it's an email
            user = repository.findByEmail(identifier)
                    .orElseThrow(() -> new BadCredentialsException("Email ou numéro de téléphone introuvable."));
        } else { // Assuming it's a phone number
            user = repository.findByPhone(identifier)
                    .orElseThrow(() -> new BadCredentialsException("Email ou numéro de téléphone introuvable."));
        }

        if (!user.getPin().equals(pin)) {
            throw new BadCredentialsException("Code PIN incorrect.");
        }

        // Generate a short-lived token for password reset purpose
        Map<String, Object> extraClaims = new HashMap<>();
        extraClaims.put("purpose", "password_reset");
        extraClaims.put("userId", user.getId()); // Include user ID in the token

        // Token valid for, e.g., 5 minutes
        return jwtService.generateToken(extraClaims, user, Instant.now().plus(5, ChronoUnit.MINUTES));
    }

    // Method to reset password using a reset token
    public void resetPassword(String resetToken, String newPassword) {
        // Validate the token and extract user details
        if (!jwtService.isTokenValid(resetToken, null) || !jwtService.extractClaim(resetToken, claims -> claims.get("purpose", String.class)).equals("password_reset")) {
            throw new BadCredentialsException("Jeton de réinitialisation invalide ou expiré.");
        }

        Integer userId = jwtService.extractClaim(resetToken, claims -> claims.get("userId", Integer.class));
        User user = repository.findById(userId)
                .orElseThrow(() -> new BadCredentialsException("Utilisateur introuvable pour la réinitialisation du mot de passe."));

        user.setPassword(passwordEncoder.encode(newPassword));
        repository.save(user);
    }

    // New DTO for password reset with token (will be defined in AuthenticationController)
    public static class ResetPasswordRequest {
        private String token;
        private String newPassword;

        public String getToken() { return token; }
        public void setToken(String token) { this.token = token; }
        public String getNewPassword() { return newPassword; }
        public void setNewPassword(String newPassword) { this.newPassword = newPassword; }
    }
}
