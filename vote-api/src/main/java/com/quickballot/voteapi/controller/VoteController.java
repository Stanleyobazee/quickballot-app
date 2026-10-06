package com.quickballot.voteapi.controller;

import com.quickballot.voteapi.dto.CastVoteRequest;
import com.quickballot.voteapi.entity.Poll;
import com.quickballot.voteapi.entity.PollOption;
import com.quickballot.voteapi.entity.Vote;
import com.quickballot.voteapi.repository.PollOptionRepository;
import com.quickballot.voteapi.repository.PollRepository;
import com.quickballot.voteapi.repository.VoteRepository;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/polls")
public class VoteController {

    private final PollRepository pollRepository;
    private final PollOptionRepository optionRepository;
    private final VoteRepository voteRepository;

    public VoteController(PollRepository pollRepository,
                          PollOptionRepository optionRepository,
                          VoteRepository voteRepository) {
        this.pollRepository = pollRepository;
        this.optionRepository = optionRepository;
        this.voteRepository = voteRepository;
    }

    // POST /api/polls/{pollId}/votes — cast a vote
    @PostMapping("/{pollId}/votes")
    public ResponseEntity<Map<String, String>> castVote(
            @PathVariable UUID pollId,
            @Valid @RequestBody CastVoteRequest request) {

        Poll poll = pollRepository.findById(pollId)
                .orElse(null);

        if (poll == null) {
            return ResponseEntity.notFound().build();
        }

        if ("closed".equals(poll.getStatus())) {
            return ResponseEntity.status(HttpStatus.GONE)
                    .body(Map.of("error", "This poll is closed"));
        }

        if (voteRepository.existsByPollIdAndVoterToken(pollId, request.getVoterToken())) {
            return ResponseEntity.status(HttpStatus.CONFLICT)
                    .body(Map.of("error", "You have already voted in this poll"));
        }

        PollOption option = optionRepository.findById(request.getOptionId())
                .orElse(null);

        if (option == null || !option.getPoll().getId().equals(pollId)) {
            return ResponseEntity.badRequest()
                    .body(Map.of("error", "Invalid option for this poll"));
        }

        Vote vote = new Vote();
        vote.setPoll(poll);
        vote.setOption(option);
        vote.setVoterToken(request.getVoterToken());
        voteRepository.save(vote);

        return ResponseEntity.status(HttpStatus.CREATED)
                .body(Map.of("message", "Vote recorded successfully"));
    }
}