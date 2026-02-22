package com.studiophoto.photoappbackend.admin;

import com.studiophoto.photoappbackend.admin.dto.DashboardStatsDTO;
import com.studiophoto.photoappbackend.order.OrderItemRepository;
import com.studiophoto.photoappbackend.order.OrderRepository;
import com.studiophoto.photoappbackend.order.OrderStatus;
import com.studiophoto.photoappbackend.repository.UserRepository;
import com.studiophoto.photoappbackend.booking.BookingRepository;
import com.studiophoto.photoappbackend.booking.BookingStatus;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.YearMonth;
import java.util.Arrays;
import java.util.List;

@Service
@RequiredArgsConstructor
public class DashboardService {

    private final UserRepository userRepository;
    private final OrderItemRepository orderItemRepository;
    private final OrderRepository orderRepository;
    private final BookingRepository bookingRepository;

    public DashboardStatsDTO getDashboardStats() {
        long totalUsers = userRepository.count();
        Long totalPhotos = orderItemRepository.sumTotalQuantity();
        if (totalPhotos == null) {
            totalPhotos = 0L;
        }
        long totalPendingOrders = orderRepository.countByStatus(OrderStatus.PENDING);

        YearMonth currentMonth = YearMonth.now();
        LocalDateTime startOfMonth = currentMonth.atDay(1).atStartOfDay();
        LocalDateTime endOfMonth = currentMonth.atEndOfMonth().atTime(23, 59, 59);

        List<OrderStatus> revenueStatuses = Arrays.asList(OrderStatus.COMPLETED, OrderStatus.PROCESSING);
        BigDecimal totalRevenue = orderRepository.sumTotalAmountByStatusInAndCreatedAtBetween(
                revenueStatuses, startOfMonth, endOfMonth);

        if (totalRevenue == null) {
            totalRevenue = BigDecimal.ZERO;
        }

        return DashboardStatsDTO.builder()
                .totalUsers(totalUsers)
                .totalPhotos(totalPhotos)
                .totalPendingOrders(totalPendingOrders)
                .totalRevenue(totalRevenue)
                .build();
    }

    public com.studiophoto.photoappbackend.admin.dto.ChartDataDTO getChartData() {
        final int days = 30;
        LocalDate endDate = LocalDate.now();
        LocalDate startDate = endDate.minusDays(days - 1);

        List<String> labels = java.util.stream.Stream.iterate(startDate, date -> date.plusDays(1))
                .limit(days)
                .map(LocalDate::toString)
                .collect(java.util.stream.Collectors.toList());

        List<Long> newUsers = new java.util.ArrayList<>();
        List<Long> uploadedPhotos = new java.util.ArrayList<>();

        for (LocalDate date = startDate; !date.isAfter(endDate); date = date.plusDays(1)) {
            LocalDateTime startOfDay = date.atStartOfDay();
            LocalDateTime endOfDay = date.atTime(23, 59, 59);

            long users = userRepository.countByCreatedAtBetween(startOfDay, endOfDay);
            newUsers.add(users);

            Long photos = orderItemRepository.sumQuantityByOrderCreatedAtBetween(startOfDay, endOfDay);
            uploadedPhotos.add(photos != null ? photos : 0L);
        }

        return com.studiophoto.photoappbackend.admin.dto.ChartDataDTO.builder()
                .labels(labels)
                .newUsers(newUsers)
                .uploadedPhotos(uploadedPhotos)
                .build();
    }

    public List<com.studiophoto.photoappbackend.admin.dto.ActivityItemDTO> getRecentActivity() {
        List<com.studiophoto.photoappbackend.model.User> recentUsers = userRepository.findTop5ByOrderByCreatedAtDesc();
        List<com.studiophoto.photoappbackend.order.Order> recentOrders = orderRepository.findTop5ByOrderByCreatedAtDesc();

        List<com.studiophoto.photoappbackend.admin.dto.ActivityItemDTO> activities = new java.util.ArrayList<>();

        recentUsers.forEach(user -> activities.add(
                com.studiophoto.photoappbackend.admin.dto.ActivityItemDTO.builder()
                        .description("Nouvel utilisateur: " + user.getFirstname())
                        .timestamp(user.getCreatedAt())
                        .icon("fas fa-user-plus")
                        .color("var(--primary-color)")
                        .type("user")
                        .entityId(Long.valueOf(user.getId()))
                        .build()
        ));

        recentOrders.forEach(order -> activities.add(
                com.studiophoto.photoappbackend.admin.dto.ActivityItemDTO.builder()
                        .description("Nouvelle commande #" + order.getId())
                        .timestamp(order.getCreatedAt())
                        .icon("fas fa-shopping-cart")
                        .color("var(--success-color)")
                        .type("order")
                        .entityId(order.getId())
                        .build()
        ));

        activities.sort(java.util.Comparator.comparing(com.studiophoto.photoappbackend.admin.dto.ActivityItemDTO::getTimestamp).reversed());

        return activities.stream().limit(5).collect(java.util.stream.Collectors.toList());
    }

    public com.studiophoto.photoappbackend.admin.dto.OrderStatusChartDTO getOrderStatusChartData() {
        List<String> labels = new java.util.ArrayList<>();
        List<Long> data = new java.util.ArrayList<>();
        List<String> colors = new java.util.ArrayList<>();

        for (OrderStatus status : OrderStatus.values()) {
            labels.add(status.name());
            data.add(orderRepository.countByStatus(status));
            // Assign a color based on status
            switch (status) {
                case PENDING:
                    colors.add("#FFCE56"); // Warning yellow
                    break;
                case PROCESSING:
                    colors.add("#36A2EB"); // Info blue
                    break;
                case COMPLETED:
                    colors.add("#2ECC71"); // Success green
                    break;
                case CANCELLED:
                    colors.add("#FF6384"); // Danger red
                    break;
                case PENDING_PAYMENT:
                    colors.add("#95A5A6"); // Grey
                    break;
                default:
                    colors.add("#CCCCCC"); // Default light grey
                    break;
            }
        }

        return com.studiophoto.photoappbackend.admin.dto.OrderStatusChartDTO.builder()
                .labels(labels)
                .data(data)
                .backgroundColors(colors)
                .build();
    }

    public com.studiophoto.photoappbackend.admin.dto.BookingStatusChartDTO getBookingStatusChartData() {
        List<String> labels = new java.util.ArrayList<>();
        List<Long> data = new java.util.ArrayList<>();
        List<String> colors = new java.util.ArrayList<>();

        for (BookingStatus status : BookingStatus.values()) {
            labels.add(status.name());
            data.add(bookingRepository.countByStatus(status));
            // Assign a color based on status
            switch (status) {
                case PENDING:
                    colors.add("#FFCE56"); // Warning yellow
                    break;
                case CONFIRMED:
                    colors.add("#2ECC71"); // Success green
                    break;
                case CANCELLED:
                    colors.add("#FF6384"); // Danger red
                    break;
                default:
                    colors.add("#CCCCCC"); // Default light grey
                    break;
            }
        }

        return com.studiophoto.photoappbackend.admin.dto.BookingStatusChartDTO.builder()
                .labels(labels)
                .data(data)
                .backgroundColors(colors)
                .build();
    }

    public com.studiophoto.photoappbackend.admin.dto.BookingsPerDayChartDTO getBookingsPerDayChartData() {
        final int days = 30;
        LocalDate endDate = LocalDate.now();
        LocalDate startDate = endDate.minusDays(days - 1);

        List<String> labels = java.util.stream.Stream.iterate(startDate, date -> date.plusDays(1))
                .limit(days)
                .map(LocalDate::toString)
                .collect(java.util.stream.Collectors.toList());

        List<Long> dailyBookings = new java.util.ArrayList<>();

        for (LocalDate date = startDate; !date.isAfter(endDate); date = date.plusDays(1)) {
            LocalDateTime startOfDay = date.atStartOfDay();
            LocalDateTime endOfDay = date.atTime(23, 59, 59);
            dailyBookings.add(bookingRepository.countByStartTimeBetween(startOfDay, endOfDay));
        }

        return com.studiophoto.photoappbackend.admin.dto.BookingsPerDayChartDTO.builder()
                .labels(labels)
                .data(dailyBookings)
                .build();
    }
}
