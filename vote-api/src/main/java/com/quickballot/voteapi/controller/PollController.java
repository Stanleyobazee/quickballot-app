package com.quickballot.voteapi.controller;

import com.quickballot.voteapi.dto.PollResponse;
import com.quickballot.voteapi.repository.PollRepository;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/polls")
public class PollController {

    private final PollRepository pollRepository;

    public PollController(PollRepository pollRepository) {
        this.pollRepository = pollRepository;
    }

    // GET /api/polls — list all active polls
    @GetMapping
    public List<PollResponse> listActive() {
        return pollRepository.findByStatusOrderByCreatedAtDesc("active")
                .stream()
                .map(PollResponse::from)
                .toList();
    }

    // GET /api/polls/{id} — get a single poll by id
    @GetMapping("/{id}")
    public ResponseEntity<PollResponse> getById(@PathVariable UUID id) {
        return pollRepository.findById(id)
                .map(PollResponse::from)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }
}