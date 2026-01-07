package com.homework.movieapp.MovieApp;

import com.microsoft.applicationinsights.TelemetryClient;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.Map;

@Controller
public class MovieController {

    @Autowired
    private MovieRepository repository;

    @Autowired(required = false)
    private TelemetryClient telemetryClient;

    // Cerința 1: Homepage accesibil public
    @GetMapping("/")
    public String index(Model model) {
        // Cerința 2c: Lista persistentă de iteme
        model.addAttribute("movies", repository.findAll());
        return "index";
    }

    // Cerința 2a/2b: Input text și buton Enter
    @PostMapping("/add")
    public String addMovie(@RequestParam String title) {
        if (title != null && !title.trim().isEmpty()) {
            Movie movie = new Movie();
            movie.setTitle(title);
            repository.save(movie);

            // Cerința 3: Business logging
            if (telemetryClient != null) {
                Map<String, String> properties = new HashMap<>();
                properties.put("MovieTitle", title);
                telemetryClient.trackEvent("Item successfully added", properties, null);
            }
        }
        return "redirect:/";
    }

    // Cerința 5: Health Endpoint
    @GetMapping("/health")
    public ResponseEntity<String> health() {
        return ResponseEntity.ok("Healthy");
    }

    // Cerința 3 (Error): Error Trigger
    @GetMapping("/error-test")
    public String triggerError() {
        throw new RuntimeException("This is a test error for Application Insights!");
    }
}