package com.quickballot.voteapi.entity;

import jakarta.persistence.*;
import java.time.OffsetDateTime;
import java.util.UUID;

@Entity
@Table(name = "votes")
public class Vote {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "poll_id", nullable = false)
    private Poll poll;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "option_id", nullable = false)
    private PollOption option;

    @Column(name = "voter_token", nullable = false)
    private String voterToken;

    @Column(name = "cast_at", nullable = false, updatable = false)
    private OffsetDateTime castAt = OffsetDateTime.now();

    public UUID getId() { return id; }
    public Poll getPoll() { return poll; }
    public PollOption getOption() { return option; }
    public String getVoterToken() { return voterToken; }
    public OffsetDateTime getCastAt() { return castAt; }

    public void setId(UUID id) { this.id = id; }
    public void setPoll(Poll poll) { this.poll = poll; }
    public void setOption(PollOption option) { this.option = option; }
    public void setVoterToken(String voterToken) { this.voterToken = voterToken; }
}