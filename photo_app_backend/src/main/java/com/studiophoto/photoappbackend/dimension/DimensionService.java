package com.studiophoto.photoappbackend.dimension;

import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.Arrays;
import java.util.List;
import java.util.stream.Collectors;


import java.util.Optional;

@Service
@RequiredArgsConstructor
public class DimensionService {

    private final DimensionRepository dimensionRepository;

    public List<DimensionDto> getAllDimensions() {
        return dimensionRepository.findAll().stream()
                .map(this::mapToDto)
                .collect(Collectors.toList());
    }

    // --- Méthodes pour l'administration ---

    public List<Dimension> findAll() {
        return dimensionRepository.findAll();
    }

    public Optional<Dimension> findById(Long id) {
        return dimensionRepository.findById(id);
    }

    public Dimension save(Dimension dimension) {
        return dimensionRepository.save(dimension);
    }

    public void deleteById(Long id) {
        dimensionRepository.deleteById(id);
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
