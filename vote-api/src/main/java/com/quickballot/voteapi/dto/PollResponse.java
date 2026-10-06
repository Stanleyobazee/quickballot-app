package com.quickballot.voteapi.dto;

import com.quickballot.voteapi.entity.Poll;
import com.quickballot.voteapi.entity.PollOption;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

public class PollResponse {

    private UUID id;
    private String question;
    private String status;
    private OffsetDateTime createdAt;
    private List<OptionResponse> options;

    public static PollResponse from(Poll poll) {
        PollResponse r = new PollResponse();
        r.id = poll.getId();
        r.question = poll.getQuestion();
        r.status = poll.getStatus();
        r.createdAt = poll.getCreatedAt();
        r.options = poll.getOptions().stream().map(OptionResponse::from).toList();
        return r;
    }

    public UUID getId() { return id; }
    public String getQuestion() { return question; }
    public String getStatus() { return status; }
    public OffsetDateTime getCreatedAt() { return createdAt; }
    public List<OptionResponse> getOptions() { return options; }

    public static class OptionResponse {
        private UUID id;
        private String label;
        private int displayOrder;

        public static OptionResponse from(PollOption o) {
            OptionResponse r = new OptionResponse();
            r.id = o.getId();
            r.label = o.getLabel();
            r.displayOrder = o.getDisplayOrder();
            return r;
        }

        public UUID getId() { return id; }
        public String getLabel() { return label; }
        public int getDisplayOrder() { return displayOrder; }
    }
}