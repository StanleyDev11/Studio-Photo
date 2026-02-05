package com.studiophoto.photoappbackend.auth;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@AllArgsConstructor
@NoArgsConstructor
public class VerifyPinRequest {
    private String identifier; // Can be email or phone
    private String pin;
}
