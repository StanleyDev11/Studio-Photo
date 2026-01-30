package com.studiophoto.photoappbackend.order;

import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;

@Controller
@RequestMapping("/admin/orders")
@RequiredArgsConstructor
public class AdminOrderController {

    private final OrderService orderService;

    @GetMapping
    public String listOrders(Model model) {
        model.addAttribute("orders", orderService.findAll()); // Assurez-vous que orderService.findAll() existe
        return "admin/orders/list"; // Vue à créer : templates/admin/orders/list.html
    }

    // TODO: Ajouter des méthodes pour afficher les détails, modifier le statut, etc.
}
