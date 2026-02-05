package com.studiophoto.photoappbackend.order;

import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.servlet.mvc.support.RedirectAttributes;

import java.util.Optional;

@Controller
@RequestMapping("/admin/orders")
@RequiredArgsConstructor
public class AdminOrderController {

    private final OrderService orderService;

    @GetMapping
    public String listOrders(Model model) {
        model.addAttribute("orders", orderService.findAll());
        return "admin/orders/list";
    }

    @GetMapping("/{id}")
    public String viewOrderDetails(@PathVariable("id") Long id, Model model, RedirectAttributes redirectAttributes) {
        Optional<Order> orderOptional = orderService.findById(id); 
        if (orderOptional.isPresent()) {
            model.addAttribute("order", orderOptional.get());
            return "admin/orders/detail"; 
        } else {
            redirectAttributes.addFlashAttribute("errorMessage", "Commande non trouvée.");
            return "redirect:/admin/orders";
        }
    }
}
