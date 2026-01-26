package com.studiophoto.photoappbackend.auth;

import com.studiophoto.photoappbackend.model.Role;
import com.studiophoto.photoappbackend.model.User;
import com.studiophoto.photoappbackend.repository.UserRepository;
import com.studiophoto.photoappbackend.security.JwtService;
import lombok.RequiredArgsConstructor;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

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
        String username; // This will be email or phone
        User user;

        if (request.getEmail() != null && !request.getEmail().isEmpty()) {
            username = request.getEmail();
            user = repository.findByEmail(username)
                    .orElseThrow(() -> new RuntimeException("Utilisateur non trouvé avec l'email: " + username));
        } else if (request.getPhone() != null && !request.getPhone().isEmpty()) {
            username = request.getPhone();
            user = repository.findByPhone(username)
                    .orElseThrow(() -> new RuntimeException("Utilisateur non trouvé avec le téléphone: " + username));
        } else {
            throw new IllegalArgumentException("L'email ou le numéro de téléphone doit être fourni.");
        }

        authenticationManager.authenticate(
                new UsernamePasswordAuthenticationToken(
                        username,
                        request.getPassword()
                )
        );
        // user should exist if authentication is successful

        var jwtToken = jwtService.generateToken(user);
        return AuthenticationResponse.builder()
                .token(jwtToken)
                .build();
    }
}
