package com.quickballot.voteapi.repository;

import com.quickballot.voteapi.entity.Poll;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;
import java.util.UUID;

public interface PollRepository extends JpaRepository<Poll, UUID> {
    List<Poll> findByStatusOrderByCreatedAtDesc(String status);
}