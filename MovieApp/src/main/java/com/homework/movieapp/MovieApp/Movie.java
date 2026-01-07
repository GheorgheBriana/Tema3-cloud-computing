package com.homework.movieapp.MovieApp;

import javax.persistence.*;
import lombok.Data;

@Data
@Entity
@Table(name = "movies")
public class Movie {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    // Câmpul text
    @Column(nullable = false)
    private String title;
}