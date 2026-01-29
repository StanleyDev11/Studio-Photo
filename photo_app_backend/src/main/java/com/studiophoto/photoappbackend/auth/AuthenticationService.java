package com.studiophoto.photoappbackend.auth;

import com.studiophoto.photoappbackend.model.Role;
import com.studiophoto.photoappbackend.model.Status;
import com.studiophoto.photoappbackend.model.User;
import com.studiophoto.photoappbackend.repository.UserRepository;
import com.studiophoto.photoappbackend.security.JwtService;
import io.jsonwebtoken.Claims;
import lombok.RequiredArgsConstructor;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

import java.util.HashMap;
import java.util.Map;

@Service
@RequiredArgsConstructor
public class AuthenticationService {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwtService;
    private final AuthenticationManager authenticationManager;

    public AuthenticationResponse register(RegisterRequest request) {
        if (userRepository.existsByEmail(request.getEmail())) {
            throw new IllegalStateException("Email already in use");
        }
        var user = User.builder()
                .firstname(request.getFirstname())
                .lastname(request.getLastname())
                .email(request.getEmail())
                .password(passwordEncoder.encode(request.getPassword()))
                .phone(request.getPhone())
                .pin(request.getPin()) // Note: PIN should be hashed in a real-world scenario
                .role(Role.USER)
                .status(Status.ACTIVE) // Default to ACTIVE to allow immediate login
                .build();

        var savedUser = userRepository.save(user);

        String jwtToken = jwtService.generateToken(savedUser);

        return AuthenticationResponse.builder()
                .token(jwtToken)
                .id(savedUser.getId())
                .firstname(savedUser.getFirstname())
                .lastname(savedUser.getLastname())
                .email(savedUser.getEmail())
                .phone(savedUser.getPhone())
                .role(savedUser.getRole())
                .build();
    }

    public AuthenticationResponse authenticate(LoginRequest request) {
        String identifier = request.getEmail() != null && !request.getEmail().isEmpty()
                ? request.getEmail()
                : request.getPhone();

        if (identifier == null || identifier.isEmpty()) {
            throw new IllegalArgumentException("Email or phone number must be provided for authentication.");
        }

        authenticationManager.authenticate(
                new UsernamePasswordAuthenticationToken(
                        identifier,
                        request.getPassword()
                )
        );

        User user = userRepository.findByEmail(identifier)
                .or(() -> userRepository.findByPhone(identifier))
                .orElseThrow(() -> new RuntimeException("User not found with identifier: " + identifier));

        String jwtToken = jwtService.generateToken(user);

        return AuthenticationResponse.builder()
                .token(jwtToken)
                .id(user.getId())
                .firstname(user.getFirstname())
                .lastname(user.getLastname())
                .email(user.getEmail())
                .phone(user.getPhone())
                .role(user.getRole())
                .build();
    }
    
    public String verifyPinForPasswordReset(String identifier, String pin) {
        User user = userRepository.findByEmail(identifier)
                .or(() -> userRepository.findByPhone(identifier))
                .orElseThrow(() -> new RuntimeException("Utilisateur non trouvé avec l'identifiant : " + identifier));

        // IMPORTANT: C'est une comparaison simple. Pour la production, le PIN devrait être hashé.
        if (!pin.equals(user.getPin())) {
            throw new RuntimeException("PIN incorrect.");
        }

        // Générer un token de réinitialisation avec une expiration courte (ex: 15 minutes)
        // Note: le JwtService doit être capable de gérer des expirations différentes.
        // On pourrait ajouter une méthode à JwtService ou passer la durée d'expiration.
        // Pour l'instant, on utilise une méthode hypothétique generatePasswordResetToken.
        // Il faudra l'ajouter au JwtService.
        Map<String, Object> extraClaims = new HashMap<>();
        extraClaims.put("type", "password-reset"); // Pour différencier d'un token d'auth
        return jwtService.generateToken(extraClaims, user); // Utilise l'expiration par défaut pour l'instant
    }

    public void resetPassword(String token, String newPassword) {
        String username = jwtService.extractUsername(token);
        Claims claims = jwtService.extractAllClaims(token); // Il faut une méthode pour extraire tous les claims

        User user = userRepository.findByEmail(username)
                .orElseThrow(() -> new RuntimeException("Utilisateur non trouvé avec l'email : " + username));

        // Valider le token (expiration, signature et type)
        if (!jwtService.isTokenValid(token, user) || !"password-reset".equals(claims.get("type"))) {
            throw new RuntimeException("Jeton de réinitialisation invalide ou expiré.");
        }

        user.setPassword(passwordEncoder.encode(newPassword));
        userRepository.save(user);
    }
}
