package com.studiophoto.photoappbackend.admin.dto;

import com.studiophoto.photoappbackend.model.Role;
import com.studiophoto.photoappbackend.model.Status; // Import new Status enum
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class UserRequest {
    private Integer id; // For updates
    @NotBlank
    private String firstname;
    @NotBlank
    private String lastname;
    @Email
    @NotBlank
    private String email;
    // Password is only required for creation, not necessarily for update
    private String password;
    @NotNull
    private Role role;
    @NotNull // Status is now a required field for UserRequest
    private Status status; // New field
    private String phone; // New field
    private String notes; // New field
}
