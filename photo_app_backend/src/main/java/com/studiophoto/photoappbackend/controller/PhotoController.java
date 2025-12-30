package com.studiophoto.photoappbackend.controller;

import com.studiophoto.photoappbackend.model.Photo;
import com.studiophoto.photoappbackend.model.User;
import com.studiophoto.photoappbackend.service.PhotoService;
import com.studiophoto.photoappbackend.service.UserService;
import com.studiophoto.photoappbackend.storage.StorageService; // Import StorageService
import lombok.RequiredArgsConstructor;
import org.springframework.core.io.Resource;
import org.springframework.http.HttpHeaders;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

@RestController
@RequestMapping("/api/photos")
@RequiredArgsConstructor
public class PhotoController {

    private final PhotoService photoService;
    private final UserService userService;
    private final StorageService storageService; // Inject StorageService

    @GetMapping
    public ResponseEntity<List<Photo>> getAllPhotos() {
        return ResponseEntity.ok(photoService.findAllPhotos());
    }

    @GetMapping("/{id}")
    public ResponseEntity<Photo> getPhotoById(@PathVariable Integer id) {
        Optional<Photo> photo = photoService.findPhotoById(id);
        return photo.map(ResponseEntity::ok).orElseGet(() -> ResponseEntity.notFound().build());
    }

    @GetMapping("/client/{clientId}")
    public ResponseEntity<List<Photo>> getPhotosByClientId(@PathVariable Integer clientId) {
        Optional<User> client = userService.findUserById(clientId);
        if (client.isEmpty()) {
            return ResponseEntity.notFound().build();
        }
        return ResponseEntity.ok(photoService.findPhotosByClient(client.get()));
    }

    @PostMapping("/upload")
    public ResponseEntity<Photo> uploadPhoto(
            @RequestParam("file") MultipartFile file,
            @RequestParam(value = "description", required = false) String description
    ) {
        storageService.store(file);
        
        Photo photo = new Photo();
        photo.setFilename(file.getOriginalFilename());
        photo.setFilepath(file.getOriginalFilename()); // For local storage, filepath is filename
        photo.setDescription(description);
        photo.setUploadDate(LocalDateTime.now());

        Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
        String currentPrincipalName = authentication.getName();
        Optional<User> currentUser = userService.findUserByEmail(currentPrincipalName);
        currentUser.ifPresent(photo::setClient);

        return ResponseEntity.ok(photoService.savePhoto(photo));
    }

    @GetMapping("/files/{filename:.+}")
    @ResponseBody
    public ResponseEntity<Resource> serveFile(@PathVariable String filename) {
        Resource file = storageService.loadAsResource(filename);
        return ResponseEntity.ok().header(HttpHeaders.CONTENT_DISPOSITION,
                "attachment; filename=\"" + file.getFilename() + "\"").body(file);
    }

    @PutMapping("/{id}")
    public ResponseEntity<Photo> updatePhoto(@PathVariable Integer id, @RequestBody Photo photo) {
        if (!photoService.findPhotoById(id).isPresent()) {
            return ResponseEntity.notFound().build();
        }
        photo.setId(id); // Ensure the ID matches the path variable
        return ResponseEntity.ok(photoService.savePhoto(photo));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deletePhoto(@PathVariable Integer id) {
        if (!photoService.findPhotoById(id).isPresent()) {
            return ResponseEntity.notFound().build();
        }
        photoService.deletePhoto(id);
        // Also delete from storage if needed
        // storageService.delete(photoService.findPhotoById(id).get().getFilename());
        return ResponseEntity.noContent().build();
    }
}
