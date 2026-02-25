package com.studiophoto.photoappbackend.admin.dto;

import lombok.Builder;
import lombok.Data;

import java.math.BigDecimal;
import java.util.List;

@Data
@Builder
public class RevenueChartDTO {
    private List<String> labels;
    private List<BigDecimal> data;
}
