# X engagement and ranking

## What is grounded

Current X recommender help pages support directional priors around candidate sourcing, personalization signals, ranking, filtering, user controls, and engagement feedback.

Historical open-source snapshots of X's recommendation stack also support these architecture priors:

- deep conversation matters more than shallow likes
- author replies have historically been strong signals
- profile clicks and meaningful dwell are valuable
- negative feedback events are severe

Use these as directional priors, not as live immutable constants.

## Practical recommendations

- publish when the target audience is active
- stay available to reply while discussion is active, sized to the user's real capacity
- end posts with open-ended, niche-relevant questions
- build presence by leaving substantive replies on relevant accounts
- maintain topical consistency to improve reader trust and out-of-network matching
- prioritize conversation quality over volume alone

## Architecture-level inferences

Public material supports a pipeline involving:

- candidate sourcing
- ranking across multiple actions
- diversity controls
- filtering and policy layers

Reasonable advice from that:

- avoid burst posting when it creates repetitive or low-quality sessions
- favor clear topical identity
- optimize for conversation, not pure impression bait
- use controlled tests for contested tactics such as link placement, post length, or cadence

## What not to overstate

- exact live weights
- a strict global link penalty
- deterministic posting-frequency thresholds
- a complete production contract for every Phoenix or Grok-era behavior
- treating newly discovered repositories as stable production evidence without an official X-owned source link
