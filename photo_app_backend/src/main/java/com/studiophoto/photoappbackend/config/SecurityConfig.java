package com.studiophoto.photoappbackend.config;

import com.studiophoto.photoappbackend.security.JwtAuthenticationFilter;
import lombok.RequiredArgsConstructor;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.authentication.AuthenticationProvider;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;
import jakarta.servlet.http.HttpServletResponse; // Added import
import org.springframework.http.MediaType; // Added import

@Configuration
@EnableWebSecurity
@EnableMethodSecurity
@RequiredArgsConstructor
public class SecurityConfig {

    private final JwtAuthenticationFilter jwtAuthFilter;
    private final AuthenticationProvider authenticationProvider;

    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
        http
                .csrf(csrf -> csrf.disable())
                                 .authorizeHttpRequests(auth -> auth
                                        // Public access for static resources
                                        .requestMatchers("/static/**", "/css/**", "/js/**", "/images/**", "/uploads/**").permitAll()
                                        // Public access for new public endpoints
                                        .requestMatchers("/api/public/**", "/api/promotions/**").permitAll()
                                        // Public access for authentication and admin login page
                                        .requestMatchers("/api/auth/**").permitAll() // API authentication should be permitted
                                        .requestMatchers("/admin/login").permitAll() // Admin login page
                                        // Admin paths should be authenticated and role-based
                                        .requestMatchers("/admin/**").hasRole("ADMIN")
                                        .anyRequest()
                                        .authenticated()
                                )
                                                                 .exceptionHandling(exception -> exception
                                                                        .authenticationEntryPoint((request, response, authException) -> {
                                                                            response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
                                                                            response.setContentType(MediaType.APPLICATION_JSON_VALUE);
                                                                            // Provide a more user-friendly message for authentication failures
                                                                            response.getWriter().write("{ \"message\": \"Email ou mot de passe incorrect.\" }");
                                                                        })
                                                                )                                .formLogin(form -> form
                                        .loginPage("/admin/login")
                                        .defaultSuccessUrl("/admin/dashboard", true) // Redirect to admin dashboard on success
                                        .failureUrl("/admin/login?error")
                                        .permitAll() // Allow everyone to access the login form
                                )
                                .logout(logout -> logout
                                        .logoutUrl("/admin/logout")
                                        .logoutSuccessUrl("/admin/login?logout")
                                        .permitAll()
                                )
                                .sessionManagement(session -> session.sessionCreationPolicy(SessionCreationPolicy.IF_REQUIRED)) // Change to IF_REQUIRED for session-based login
                                .authenticationProvider(authenticationProvider)
                                .addFilterBefore(jwtAuthFilter, UsernamePasswordAuthenticationFilter.class);
                
                        return http.build();
                    }}
