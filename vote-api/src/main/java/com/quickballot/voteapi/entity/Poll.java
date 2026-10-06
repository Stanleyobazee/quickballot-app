package com.quickballot.voteapi.entity;

import jakarta.persistence.*;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Entity
@Table(name = "polls")
public class Poll {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(nullable = false)
    private String question;

    @Column(nullable = false)
    private String status = "active";

    @Column(name = "created_at", nullable = false, updatable = false)
    private OffsetDateTime createdAt = OffsetDateTime.now();

    @Column(name = "closed_at")
    private OffsetDateTime closedAt;

    @OneToMany(mappedBy = "poll", cascade = CascadeType.ALL, fetch = FetchType.EAGER)
    @OrderBy("displayOrder ASC")
    private List<PollOption> options = new ArrayList<>();

    public UUID getId() { return id; }
    public String getQuestion() { return question; }
    public String getStatus() { return status; }
    public OffsetDateTime getCreatedAt() { return createdAt; }
    public OffsetDateTime getClosedAt() { return closedAt; }
    public List<PollOption> getOptions() { return options; }

    public void setId(UUID id) { this.id = id; }
    public void setQuestion(String question) { this.question = question; }
    public void setStatus(String status) { this.status = status; }
    public void setClosedAt(OffsetDateTime closedAt) { this.closedAt = closedAt; }
    public void setOptions(List<PollOption> options) { this.options = options; }
}