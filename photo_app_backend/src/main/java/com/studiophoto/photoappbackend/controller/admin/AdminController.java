package com.studiophoto.photoappbackend.controller.admin;

import com.studiophoto.photoappbackend.model.Photo;
import com.studiophoto.photoappbackend.model.User;
import com.studiophoto.photoappbackend.service.PhotoService;
import com.studiophoto.photoappbackend.service.UserService;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;

import java.util.List;

@Controller
@RequestMapping("/admin")
@RequiredArgsConstructor
@PreAuthorize("hasRole('ADMIN')") // Only accessible by ADMIN role
public class AdminController {

    private final UserService userService;
    private final PhotoService photoService;

    @GetMapping("/dashboard")
    public String adminDashboard(Model model) {
        model.addAttribute("users", userService.findAllUsers());
        model.addAttribute("photos", photoService.findAllPhotos());
        // Add more data for dashboard
        return "admin/dashboard";
    }

    @GetMapping("/users")
    public String manageUsers(Model model) {
        List<User> users = userService.findAllUsers();
        model.addAttribute("users", users);
        return "admin/users";
    }

    @GetMapping("/photos")
    public String managePhotos(Model model) {
        List<Photo> photos = photoService.findAllPhotos();
        model.addAttribute("photos", photos);
        return "admin/photos";
    }

    // You can add more mappings for order management, payment tracking etc.
}
