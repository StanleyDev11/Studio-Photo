package com.studiophoto.photoappbackend.order;

import com.studiophoto.photoappbackend.model.User;
import com.studiophoto.photoappbackend.storage.StorageService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/orders")
@RequiredArgsConstructor
public class OrderController {

    private final OrderService orderService;
    private final StorageService storageService;

    @PostMapping
    public ResponseEntity<Order> createOrder(
            @RequestBody CreateOrderRequest request,
            @AuthenticationPrincipal User currentUser) {
        if (currentUser == null) {
            return ResponseEntity.status(401).build(); // Non autorisé
        }
        Order newOrder = orderService.createOrder(request, currentUser);
        return ResponseEntity.ok(newOrder);
    }

    @GetMapping("/my-orders")
    public ResponseEntity<List<Order>> getMyOrders(@AuthenticationPrincipal User currentUser) {
        if (currentUser == null) {
            return ResponseEntity.status(401).build();
        }
        List<Order> orders = orderService.findOrdersByUser(currentUser.getId());
        return ResponseEntity.ok(orders);
    }

    @PostMapping("/upload")
    public ResponseEntity<?> uploadPhotos(
            @RequestParam("files") List<MultipartFile> files,
            @RequestParam("userId") Long userId) {

        if (files.isEmpty()) {
            return ResponseEntity.badRequest().body("Please select files to upload.");
        }

        // In a real application, the base URL should be retrieved dynamically
        // For example, from the request headers or a configuration file.
        String baseUrl = "http://109.176.197.158:8080";

        List<String> fileUrls = new ArrayList<>();
        String uploadId = UUID.randomUUID().toString();

        try {
            // Create a user-specific directory and a unique directory for this upload
            Path userDirectory = Paths.get("uploads", "user_" + userId, uploadId);
            Files.createDirectories(userDirectory);

            for (MultipartFile file : files) {
                if (file.isEmpty()) {
                    continue;
                }

                String originalFilename = file.getOriginalFilename();
                if (originalFilename == null) {
                    originalFilename = "unnamed-file";
                }

                // Clean the filename to prevent directory traversal issues
                String sanitizedFilename = Paths.get(originalFilename).getFileName().toString();

                Path destinationFile = userDirectory.resolve(sanitizedFilename).normalize().toAbsolutePath();

                // Double check to prevent saving files outside the intended directory
                if (!destinationFile.getParent().equals(userDirectory.toAbsolutePath())) {
                    return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                            .body("Cannot store file outside the designated directory.");
                }

                file.transferTo(destinationFile);

                String fileUrl = baseUrl + "/uploads/user_" + userId + "/" + uploadId + "/" + sanitizedFilename;
                fileUrls.add(fileUrl);
            }

            return ResponseEntity.ok(Collections.singletonMap("urls", fileUrls));

        } catch (IOException e) {
            // Log the exception for debugging purposes
            // logger.error("Failed to upload files for user {}", userId, e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body("Failed to upload files.");
        }
    }

    @PostMapping("/{id}/cancel")
    public ResponseEntity<?> cancelOrder(
            @PathVariable Long id,
            @AuthenticationPrincipal User currentUser) {
        if (currentUser == null) {
            return ResponseEntity.status(401).build();
        }
        try {
            orderService.cancelOrder(id, currentUser);
            return ResponseEntity.ok().build();
        } catch (IllegalStateException e) {
            return ResponseEntity.badRequest().body(e.getMessage());
        } catch (Exception e) {
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body("Une erreur est survenue lors de l'annulation.");
        }
    }
}
