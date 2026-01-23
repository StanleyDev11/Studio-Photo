package com.studiophoto.photoappbackend.admin;

import com.studiophoto.photoappbackend.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseBody;

import java.util.HashMap;
import java.util.Map;

@Controller
@RequestMapping("/admin")
@RequiredArgsConstructor
public class AdminController {

    private final UserRepository userRepository;

    @GetMapping("/login")
    public String login() {
        return "admin/login";
    }

    @GetMapping("/dashboard")
    public String dashboard() {
        return "admin/dashboard";
    }

    @GetMapping("/api/dashboard-stats")
    @ResponseBody
    public Map<String, Long> getDashboardStats() {
        long totalUsers = userRepository.count();
        // Placeholder for photos and orders until repositories are implemented
        long totalPhotos = 870L; // Dummy data
        long totalPendingOrders = 12L; // Dummy data
        long totalRevenue = 4250L; // Dummy data

        Map<String, Long> stats = new HashMap<>();
        stats.put("totalUsers", totalUsers);
        stats.put("totalPhotos", totalPhotos);
        stats.put("totalPendingOrders", totalPendingOrders);
        stats.put("totalRevenue", totalRevenue);
        return stats;
    }
}
