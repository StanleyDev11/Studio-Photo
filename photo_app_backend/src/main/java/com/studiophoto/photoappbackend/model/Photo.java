package com.studiophoto.photoappbackend.model;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Entity
@Table(name = "photo")
public class Photo {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;
    private String filename;
    private String filepath; // Path to storage (local or S3)
    private String description;
    private LocalDateTime uploadDate;

    @ManyToOne
    @JoinColumn(name = "client_id")
    private User client; // The user who owns this photo
}
