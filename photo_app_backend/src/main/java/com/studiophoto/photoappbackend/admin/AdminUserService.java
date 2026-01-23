package com.studiophoto.photoappbackend.admin;

import com.studiophoto.photoappbackend.admin.dto.UserRequest;
import com.studiophoto.photoappbackend.admin.dto.UserResponse;
import com.studiophoto.photoappbackend.model.Status; // Import Status enum
import com.studiophoto.photoappbackend.model.User;
import com.studiophoto.photoappbackend.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Optional;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class AdminUserService {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;

    public List<UserResponse> getAllUsers() {
        return userRepository.findAll().stream()
                .map(this::mapToUserResponse)
                .collect(Collectors.toList());
    }

    public Optional<UserResponse> getUserById(Integer id) {
        return userRepository.findById(id)
                .map(this::mapToUserResponse);
    }


    public UserResponse createUser(UserRequest request) {
        // Check if user with the same email already exists
        if (userRepository.existsByEmail(request.getEmail())) {
            throw new IllegalStateException("Un utilisateur avec l'email " + request.getEmail() + " existe déjà.");
        }

        var user = User.builder()
                .firstname(request.getFirstname())
                .lastname(request.getLastname())
                .email(request.getEmail())
                .password(passwordEncoder.encode(request.getPassword()))
                .role(request.getRole())
                .status(request.getStatus() != null ? request.getStatus() : Status.PENDING) // Use request status or default
                .phone(request.getPhone())
                .build();
        return mapToUserResponse(userRepository.save(user));
    }

    public Optional<UserResponse> updateUser(Integer id, UserRequest request) {
        return userRepository.findById(id)
                .map(user -> {
                    user.setFirstname(request.getFirstname());
                    user.setLastname(request.getLastname());
                    user.setEmail(request.getEmail());
                    user.setRole(request.getRole());
                    user.setStatus(request.getStatus()); // Update status
                    user.setPhone(request.getPhone()); // Update phone

                    // Only update password if a new one is provided
                    if (request.getPassword() != null && !request.getPassword().isEmpty()) {
                        user.setPassword(passwordEncoder.encode(request.getPassword()));
                    }
                    return mapToUserResponse(userRepository.save(user));
                });
    }

    public boolean deleteUser(Integer id) {
        if (userRepository.existsById(id)) {
            userRepository.deleteById(id);
            return true;
        }
        return false;
    }

    public Optional<UserResponse> resetUserPassword(Integer id, String newPassword) {
        return userRepository.findById(id)
                .map(user -> {
                    // Generate a new password if null or empty, otherwise use provided
                    String passwordToEncode = (newPassword == null || newPassword.isEmpty()) ? generateRandomPassword() : newPassword;
                    user.setPassword(passwordEncoder.encode(passwordToEncode));
                    return mapToUserResponse(userRepository.save(user));
                });
    }

    public Optional<UserResponse> changeUserStatus(Integer id, Status newStatus) {
        return userRepository.findById(id)
                .map(user -> {
                    user.setStatus(newStatus);
                    return mapToUserResponse(userRepository.save(user));
                });
    }

    private UserResponse mapToUserResponse(User user) {
        return UserResponse.builder()
                .id(user.getId())
                .firstname(user.getFirstname())
                .lastname(user.getLastname())
                .email(user.getEmail())
                .role(user.getRole())
                .status(user.getStatus()) // Include status
                .phone(user.getPhone()) // Include phone
                .createdAt(user.getCreatedAt()) // Include createdAt
                .lastLogin(user.getLastLogin()) // Include lastLogin
                .build();
    }

    // A simple method to generate a random password (for auto-generation)
    private String generateRandomPassword() {
        // In a real application, consider a more robust random password generator
        return "Temp" + System.nanoTime();
    }
}
