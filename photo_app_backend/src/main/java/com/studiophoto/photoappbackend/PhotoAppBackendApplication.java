package com.studiophoto.photoappbackend;

import com.studiophoto.photoappbackend.storage.StorageProperties;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.properties.EnableConfigurationProperties;

@SpringBootApplication
@EnableConfigurationProperties(StorageProperties.class)
public class PhotoAppBackendApplication {

	public static void main(String[] args) {
		SpringApplication.run(PhotoAppBackendApplication.class, args);
	}

}
