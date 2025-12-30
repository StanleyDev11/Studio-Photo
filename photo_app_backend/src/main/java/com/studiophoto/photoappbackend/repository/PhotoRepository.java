package com.studiophoto.photoappbackend.repository;

import com.studiophoto.photoappbackend.model.Photo;
import com.studiophoto.photoappbackend.model.User;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface PhotoRepository extends JpaRepository<Photo, Integer> {
    List<Photo> findByClient(User client);
}
