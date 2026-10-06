package com.quickballot.voteapi.repository;

import com.quickballot.voteapi.entity.Vote;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.UUID;

public interface VoteRepository extends JpaRepository<Vote, UUID> {
    boolean existsByPollIdAndVoterToken(UUID pollId, String voterToken);
}