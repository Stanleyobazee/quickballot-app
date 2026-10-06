package com.quickballot.voteapi.repository;

import com.quickballot.voteapi.entity.PollOption;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.UUID;

public interface PollOptionRepository extends JpaRepository<PollOption, UUID> {
}