package com.quickballot.voteapi.entity;

import jakarta.persistence.*;
import java.util.UUID;

@Entity
@Table(name = "poll_options")
public class PollOption {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "poll_id", nullable = false)
    private Poll poll;

    @Column(nullable = false)
    private String label;

    @Column(name = "display_order")
    private int displayOrder;

    public UUID getId() { return id; }
    public Poll getPoll() { return poll; }
    public String getLabel() { return label; }
    public int getDisplayOrder() { return displayOrder; }

    public void setId(UUID id) { this.id = id; }
    public void setPoll(Poll poll) { this.poll = poll; }
    public void setLabel(String label) { this.label = label; }
    public void setDisplayOrder(int displayOrder) { this.displayOrder = displayOrder; }
}