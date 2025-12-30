package com.studiophoto.photoappbackend.service;

import com.studiophoto.photoappbackend.model.Photo;
import com.studiophoto.photoappbackend.model.User;
import com.studiophoto.photoappbackend.repository.PhotoRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Optional;

@Service
@RequiredArgsConstructor
public class PhotoService {

    private final PhotoRepository photoRepository;

    public List<Photo> findAllPhotos() {
        return photoRepository.findAll();
    }

    public Optional<Photo> findPhotoById(Integer id) {
        return photoRepository.findById(id);
    }

    public List<Photo> findPhotosByClient(User client) {
        return photoRepository.findByClient(client);
    }

    public Photo savePhoto(Photo photo) {
        return photoRepository.save(photo);
    }

    public void deletePhoto(Integer id) {
        photoRepository.deleteById(id);
    }
}
