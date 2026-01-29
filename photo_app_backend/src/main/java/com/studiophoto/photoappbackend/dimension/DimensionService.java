package com.studiophoto.photoappbackend.dimension;

import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.Arrays;
import java.util.List;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class DimensionService {

    private final DimensionRepository dimensionRepository;

    public List<DimensionDto> getAllDimensions() {
        return dimensionRepository.findAll().stream()
                .map(this::mapToDto)
                .collect(Collectors.toList());
    }

    private DimensionDto mapToDto(Dimension dimension) {
        List<String> imageList = dimension.getImages() != null ? Arrays.asList(dimension.getImages().split(",")) : List.of();
        return DimensionDto.builder()
                .dimension(dimension.getName())
                .price(dimension.getPrice())
                .images(imageList)
                .title(dimension.getTitle())
                .description(dimension.getDescription())
                .isPopular(dimension.isPopular())
                .build();
    }
}
