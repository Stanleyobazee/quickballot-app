package com.quickballot.voteapi.dto;

import jakarta.validation.constraints.NotNull;
import java.util.UUID;

public class CastVoteRequest {

    @NotNull(message = "optionId is required")
    private UUID optionId;

    @NotNull(message = "voterToken is required")
    private String voterToken;

    public UUID getOptionId() { return optionId; }
    public String getVoterToken() { return voterToken; }

    public void setOptionId(UUID optionId) { this.optionId = optionId; }
    public void setVoterToken(String voterToken) { this.voterToken = voterToken; }
}