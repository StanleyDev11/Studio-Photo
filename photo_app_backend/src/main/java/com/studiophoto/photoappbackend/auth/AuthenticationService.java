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
        boolean emailExists = userRepository.existsByEmail(request.getEmail());
        boolean phoneExists = userRepository.existsByPhone(request.getPhone());

        if (emailExists && phoneExists) {
            throw new IllegalStateException("L'adresse email et le numéro de téléphone sont déjà utilisés.");
        } else if (emailExists) {
            throw new IllegalStateException("Cette adresse email est déjà utilisée.");
        } else if (phoneExists) {
            throw new IllegalStateException("Ce numéro de téléphone est déjà utilisé.");
        }
        var user = User.builder()
                .firstname(request.getFirstname())
                .lastname(request.getLastname())
                .email(request.getEmail())
                .password(passwordEncoder.encode(request.getPassword()))
                .phone(request.getPhone())
                .pin(request.getPin()) // PIN is no longer hashed
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
            throw new IllegalArgumentException("L'email ou le numéro de téléphone doit être fourni.");
        }

        try {
            authenticationManager.authenticate(
                    new UsernamePasswordAuthenticationToken(
                            identifier,
                            request.getPassword()));
        } catch (Exception e) {
            throw new RuntimeException("Email/Téléphone ou mot de passe incorrect.");
        }

        User user = userRepository.findByEmail(identifier)
                .or(() -> userRepository.findByPhone(identifier))
                .orElseThrow(() -> new RuntimeException("Utilisateur non trouvé avec l'identifiant : " + identifier));

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
        Optional<User> userOpt = userRepository.findByEmail(identifier)
                .or(() -> userRepository.findByPhone(identifier));

        if (userOpt.isEmpty()) {
            if (identifier.contains("@")) {
                throw new RuntimeException("L'adresse email saisie est incorrecte ou n'existe pas.");
            } else {
                throw new RuntimeException("Le numéro de téléphone saisi est incorrect ou n'existe pas.");
            }
        }

        User user = userOpt.get();

        // Plain text PIN comparison as requested by the user
        if (user.getPin() == null || !user.getPin().equals(pin)) {
            // If the user wants to know if BOTH are wrong, we can only say it here if we
            // know the ID was right but PIN wrong.
            // But if they asked "clairement", we say it's the PIN.
            throw new RuntimeException("Le code secret (PIN) saisi est incorrect.");
        }

        Map<String, Object> extraClaims = new HashMap<>();
        extraClaims.put("type", "password-reset");

        // Generate a token with a 15-minute expiration
        return jwtService.generateToken(extraClaims, user, 1000 * 60 * 15);
    }

    public void resetPassword(String token, String newPassword) {
        final String username; // This could be email or phone
        try {
            username = jwtService.extractUsername(token);
        } catch (Exception e) {
            throw new RuntimeException("Lien de réinitialisation invalide ou expiré.");
        }

        User user = userRepository.findByEmail(username)
                .or(() -> userRepository.findByPhone(username))
                .orElseThrow(() -> new RuntimeException("Utilisateur non trouvé."));

        final Claims claims = jwtService.extractAllClaims(token);
        final String tokenType = claims.get("type", String.class);

        if (!"password-reset".equals(tokenType) || !jwtService.isTokenValid(token, user)) {
            throw new RuntimeException("Jeton de réinitialisation invalide ou expiré.");
        }

        user.setPassword(passwordEncoder.encode(newPassword));
        userRepository.save(user);
    }
}
