# VotingDAO - Decentralized Autonomous Organization

A comprehensive blockchain-based governance system enabling token-weighted voting, proposal management, delegation, and decentralized treasury control.

## Overview

VotingDAO implements a complete decentralized governance framework where token holders collectively make decisions about fund allocation, protocol changes, and organizational direction through transparent on-chain voting.

## Features

### Core Functionality
- **Token-Based Governance**: Voting power proportional to token holdings
- **Proposal System**: Create and vote on organizational proposals
- **Vote Delegation**: Delegate voting power to trusted representatives
- **Treasury Management**: Community-controlled fund allocation
- **Quorum Requirements**: Minimum participation threshold for validity
- **Approval Threshold**: Super-majority requirement (60%) for passage
- **Time-Bounded Voting**: Fixed voting periods (~10 days)
- **Proposal Execution**: Automatic execution of passed proposals

### Key Features
- ✅ One token = one vote (proportional representation)
- ✅ Delegation system for liquid democracy
- ✅ Multiple proposal types (treasury, governance, technical)
- ✅ Transparent voting records
- ✅ Anti-double-voting protection
- ✅ Quorum-based legitimacy
- ✅ Treasury fund tracking
- ✅ Complete proposal lifecycle management

## Contract Architecture

### Data Structures

#### Proposals
Core governance proposal information:
- Proposer principal
- Title and description
- Proposal type (treasury, governance, technical, social)
- Amount requested (for treasury proposals)
- Optional recipient principal
- Vote tallies (for, against, abstain)
- Status (active, passed, rejected, executed)
- Creation and voting end timestamps
- Execution timestamp (if executed)

#### Votes
Individual voting records:
- Composite key: (proposal-id, voter)
- Vote type (for, against, abstain)
- Voting power used
- Timestamp

#### Governance Tokens
Token holder information:
- Token balance
- Delegation status (optional delegate principal)
- Proposals created count
- Votes cast count

#### Delegation Power
Aggregated delegated voting power:
- Maps delegate principal to total delegated power
- Enables representatives to vote with combined weight

## Governance Parameters

### Voting Period
```clarity
(define-constant voting-period u1440)  ;; ~10 days in blocks
```
**Duration**: Approximately 10 days (1,440 blocks at ~10 min/block)  
**Rationale**: Provides adequate time for deliberation and voting

### Quorum Threshold
```clarity
(define-constant quorum-threshold u1000000)  ;; Minimum tokens
```
**Requirement**: 1,000,000 total tokens must participate  
**Purpose**: Ensures proposals have sufficient community engagement  
**Calculation**: Total votes (for + against + abstain) ≥ quorum

### Approval Threshold
```clarity
(define-constant approval-threshold u60)  ;; 60% approval
```
**Requirement**: 60% of votes must be "for"  
**Type**: Super-majority (prevents bare-majority rule)  
**Calculation**: (votes-for / total-votes) × 100 ≥ 60

## Public Functions

### Token Management

#### `mint-governance-tokens`
```clarity
(mint-governance-tokens 
  (recipient principal)
  (amount uint))
```
Mint new governance tokens. **Owner-only function.**

**Use Cases**:
- Initial token distribution
- Incentive programs
- New member onboarding
- Contributor rewards

**Returns**: `(ok true)`

#### `delegate-voting-power`
```clarity
(delegate-voting-power (delegate principal))
```
Delegate your voting power to another address. Enables liquid democracy where token holders can designate trusted representatives.

**Effects**:
- Sets delegated-to field in your token record
- Adds your token balance to delegate's delegation-power
- Delegate can now vote with combined power

**Returns**: `(ok true)`

### Proposal Lifecycle

#### `create-proposal`
```clarity
(create-proposal
  (title (string-ascii 128))
  (description (string-ascii 512))
  (proposal-type (string-ascii 32))
  (amount-requested uint)
  (recipient (optional principal)))
```
Create a new governance proposal.

**Requirements**:
- Must hold at least 1,000 tokens
- Prevents spam proposals

**Proposal Types**:
- `"treasury"`: Request funds from treasury
- `"governance"`: Change governance parameters
- `"technical"`: Protocol upgrades or technical changes
- `"social"`: Community initiatives or partnerships

**Initial State**:
- Status: "active"
- Voting period: current block + 1,440 blocks
- All vote counts: 0

**Returns**: `(ok proposal-id)`

#### `vote`
```clarity
(vote 
  (proposal-id uint)
  (vote-type (string-ascii 8)))
```
Cast a vote on an active proposal.

**Vote Types**:
- `"for"`: Support the proposal
- `"against"`: Oppose the proposal
- `"abstain"`: Counted for quorum but neutral

**Voting Power**:
- Your token balance + any tokens delegated to you
- Prevents double voting on same proposal

**Requirements**:
- Proposal must be active
- Must be within voting period
- Cannot have already voted
- Must have voting power > 0

**Returns**: `(ok true)`

#### `finalize-proposal`
```clarity
(finalize-proposal (proposal-id uint))
```
Finalize voting and determine outcome. Can be called by anyone after voting period ends.

**Outcome Logic**:
```
IF total_votes >= quorum_threshold AND
   (votes_for / total_votes) >= 60%
THEN status = "passed"
ELSE status = "rejected"
```

**Returns**: `(ok true)` if passed, `(ok false)` if rejected

#### `execute-proposal`
```clarity
(execute-proposal (proposal-id uint))
```
Execute a passed proposal. Can be called by anyone.

**Requirements**:
- Proposal status must be "passed"
- Must not already be executed

**Execution Types**:
- **Treasury proposals**: Transfer requested amount from treasury
- **Other proposals**: Mark as executed (implementation off-chain)

**Returns**: `(ok true)`

### Treasury Management

#### `deposit-to-treasury`
```clarity
(deposit-to-treasury (amount uint))
```
Deposit funds into the DAO treasury. Anyone can deposit.

**Use Cases**:
- Protocol revenue
- Donations
- Investment returns
- Grant funding

**Returns**: `(ok true)`

## Read-Only Functions

### `get-proposal`
```clarity
(get-proposal (proposal-id uint))
```
Retrieve complete proposal details including vote tallies and status.

### `get-vote-details`
```clarity
(get-vote-details 
  (proposal-id uint)
  (voter principal))
```
Get how a specific address voted on a proposal.

### `get-token-balance`
```clarity
(get-token-balance (holder principal))
```
Get complete token holder information:
- Balance
- Delegation status
- Proposals created
- Votes cast

### `get-dao-stats`
```clarity
(get-dao-stats)
```
Get DAO-wide statistics:
- Treasury balance
- Total governance tokens
- Total proposals created

## Error Codes

| Code | Constant | Description |
|------|----------|-------------|
| u100 | `err-owner-only` | Action restricted to contract owner |
| u101 | `err-not-found` | Proposal or resource not found |
| u102 | `err-unauthorized` | Caller not authorized |
| u103 | `err-already-voted` | Already voted on this proposal |
| u104 | `err-voting-closed` | Voting period has ended |
| u105 | `err-proposal-not-passed` | Proposal did not pass |
| u106 | `err-already-executed` | Proposal already executed |
| u107 | `err-insufficient-tokens` | Not enough tokens |

## Events

The contract emits events for all major actions:
- `tokens-minted`: New tokens created
- `proposal-created`: New proposal submitted
- `vote-cast`: Vote recorded
- `proposal-passed`: Proposal succeeded
- `proposal-rejected`: Proposal failed
- `proposal-executed`: Proposal implemented
- `power-delegated`: Voting power delegated
- `treasury-deposit`: Funds added to treasury

## Usage Examples

### DAO Setup and Token Distribution

```clarity
;; Owner distributes initial governance tokens
(contract-call? .voting-dao mint-governance-tokens 
  'SP-FOUNDER-1 
  u1000000)  ;; 1M tokens to founder

(contract-call? .voting-dao mint-governance-tokens
  'SP-CONTRIBUTOR-1
  u100000)  ;; 100K tokens to contributor

(contract-call? .voting-dao mint-governance-tokens
  'SP-COMMUNITY-1
  u50000)  ;; 50K tokens to community member
```

### Treasury Funding Proposal

```clarity
;; Create proposal to fund a development project
(contract-call? .voting-dao create-proposal
  "Fund Frontend Development"
  "Requesting 50,000 STX to build and deploy the DAO's web interface. Deliverables: responsive UI, wallet integration, proposal dashboard, voting interface. Timeline: 3 months."
  "treasury"
  u50000000000  ;; 50,000 STX in micro-STX
  (some 'SP-DEVELOPMENT-TEAM))

;; Token holders vote
(contract-call? .voting-dao vote u1 "for")      ;; Support
(contract-call? .voting-dao vote u1 "against")  ;; Oppose
(contract-call? .voting-dao vote u1 "abstain")  ;; Neutral

;; After voting period ends
(contract-call? .voting-dao finalize-proposal u1)
;; If passed: "proposal-passed" event
;; If rejected: "proposal-rejected" event

;; Execute if passed
(contract-call? .voting-dao execute-proposal u1)
;; Transfers 50,000 STX from treasury to development team
```

### Governance Parameter Change

```clarity
;; Propose changing quorum requirement
(contract-call? .voting-dao create-proposal
  "Reduce Quorum Threshold"
  "Lower quorum from 1M to 500K tokens to increase governance participation. Current requirement is too high for early-stage DAO."
  "governance"
  u0  ;; No funds requested
  none)

;; Community votes and finalizes
;; If passed, parameter change implemented off-chain or via upgrade
```

### Delegation Example

```clarity
;; Community member delegates to trusted representative
(contract-call? .voting-dao delegate-voting-power 'SP-TRUSTED-DELEGATE)

;; Now SP-TRUSTED-DELEGATE can vote with:
;; - Their own token balance
;; - All delegated tokens (including yours)

;; Check delegate's total power
(contract-call? .voting-dao get-token-balance 'SP-TRUSTED-DELEGATE)
;; Returns: {balance: u100000, delegated-to: none, ...}

;; Plus delegated power from delegation-power map
```

### Social Initiative Proposal

```clarity
;; Propose community event or partnership
(contract-call? .voting-dao create-proposal
  "Sponsor Blockchain Conference"
  "Sponsor the Stacks Summit 2024 as a platinum sponsor. Benefits: booth space, speaking slot, brand visibility. Cost: 10,000 STX."
  "social"
  u10000000000  ;; 10,000 STX
  (some 'SP-EVENT-ORGANIZER))
```

### Check Proposal Status

```clarity
;; View proposal details
(contract-call? .voting-dao get-proposal u1)
;; Returns full proposal including:
;; - votes-for: u850000
;; - votes-against: u150000
;; - votes-abstain: u50000
;; - status: "passed"

;; Check if you voted
(contract-call? .voting-dao get-vote-details u1 tx-sender)
;; Returns: {vote-type: "for", voting-power: u100000, voted-at: u1234}
```

## Governance Scenarios

### Scenario 1: Successful Treasury Proposal
```
1. Alice creates proposal: "Fund Marketing Campaign - 25,000 STX"
2. Voting period: 10 days
3. Results:
   - For: 1,200,000 tokens (65%)
   - Against: 600,000 tokens (32%)
   - Abstain: 50,000 tokens (3%)
   - Total: 1,850,000 tokens

4. Check: Total ≥ quorum (1M)? ✓
5. Check: For ≥ 60%? ✓
6. Status: PASSED
7. Execute: Transfer 25,000 STX to marketing team
```

### Scenario 2: Failed Proposal (Insufficient Quorum)
```
1. Bob creates proposal: "Change DAO Name"
2. Voting period: 10 days
3. Results:
   - For: 600,000 tokens (75%)
   - Against: 200,000 tokens (25%)
   - Total: 800,000 tokens

4. Check: Total ≥ quorum (1M)? ✗
5. Status: REJECTED (insufficient participation)
```

### Scenario 3: Failed Proposal (Insufficient Approval)
```
1. Carol creates proposal: "Risky Investment Strategy"
2. Voting period: 10 days
3. Results:
   - For: 580,000 tokens (55%)
   - Against: 475,000 tokens (45%)
   - Total: 1,055,000 tokens

4. Check: Total ≥ quorum (1M)? ✓
5. Check: For ≥ 60%? ✗
6. Status: REJECTED (insufficient approval)
```

### Scenario 4: Delegation Power
```
1. Token holders delegate to representative:
   - Alice (100K tokens) → Delegates to Dave
   - Bob (150K tokens) → Delegates to Dave
   - Carol (80K tokens) → Delegates to Dave
   
2. Dave's voting power:
   - Own tokens: 50K
   - Delegated: 330K (Alice + Bob + Carol)
   - Total: 380K tokens

3. Dave votes "for" on proposal
   - Proposal receives 380K "for" votes
   - Alice, Bob, Carol cannot vote (already delegated)
```

## Governance Best Practices

### For Token Holders
- **Research Proposals**: Read full descriptions before voting
- **Participate Actively**: Vote on proposals to ensure quorum
- **Delegate Wisely**: Choose representatives with aligned values
- **Monitor Treasury**: Track fund usage and effectiveness
- **Create Thoughtful Proposals**: Well-researched proposals more likely to pass

### For Proposers
- **Clear Titles**: Descriptive, concise proposal titles
- **Detailed Descriptions**: Explain rationale, deliverables, timeline
- **Reasonable Requests**: Match funding to scope
- **Build Consensus**: Discuss in community channels before formal proposal
- **Provide Updates**: Keep community informed during execution

### For Delegates
- **Vote Responsibly**: Represent delegators' interests
- **Communicate Decisions**: Explain voting rationale publicly
- **Stay Active**: Participate in most proposals
- **Be Accountable**: Delegators can revoke delegation if dissatisfied

## Liquid Democracy

VotingDAO implements liquid democracy through delegation:

**Benefits**:
- Token holders can delegate to experts in specific domains
- Reduces voter fatigue while maintaining democratic control
- Enables specialization (technical expert, legal expert, etc.)
- Delegators retain ability to vote directly on important issues

**How It Works**:
```
Standard Democracy:
  Token Holder → Votes Directly

Liquid Democracy:
  Token Holder → Delegates to Expert → Expert Votes

Hybrid:
  Token Holder → Usually Delegates → Votes Directly on Key Issues
```

## Security Considerations

### Vote Protection
✅ **Anti-Double Voting**: Cannot vote twice on same proposal
✅ **Time-Bounded**: Voting only within designated period
✅ **Power Snapshot**: Voting power calculated at vote time
✅ **Immutable Votes**: Cannot change vote after casting

### Token Integrity
✅ **Owner-Only Minting**: Prevents unauthorized token creation
✅ **Delegation Tracking**: Clear record of delegation chain
✅ **Balance Verification**: All operations check sufficient balance

### Proposal Execution
✅ **Status Checks**: Only execute passed proposals
✅ **Single Execution**: Cannot execute twice
✅ **Treasury Validation**: Verify sufficient funds before transfer

### Governance Attacks

**Plutocracy Risk**: Whale token holders could dominate  
**Mitigation**: Consider quadratic voting or capped voting power

**Proposal Spam**: Malicious proposals flood governance  
**Mitigation**: 1,000 token minimum to create proposal

**Voter Apathy**: Low participation fails quorum  
**Mitigation**: Set reasonable quorum threshold, incentivize participation

**Bribery**: Buying votes off-chain  
**Mitigation**: Transparent on-chain records, community monitoring

## Advanced Features & Extensions

### Potential Enhancements

**Quadratic Voting**
```clarity
;; Voting power = sqrt(tokens)
;; Reduces whale dominance
(voting-power (sqrt token-balance))
```

**Conviction Voting**
```clarity
;; Longer commitment = more weight
;; Rewards long-term alignment
(voting-power (* tokens time-locked))
```

**Proposal Categories**
```clarity
;; Different thresholds per category
treasury-proposals: 60% approval
technical-proposals: 75% approval
constitutional-changes: 80% approval
```

**Proposal Cancellation**
```clarity
;; Proposer can cancel before voting ends
(define-public (cancel-proposal (proposal-id uint))
  ;; Only proposer can cancel
  ;; Only if voting hasn't ended
)
```

**Vote Changing**
```clarity
;; Allow vote changes during voting period
(define-public (change-vote (proposal-id uint) (new-vote-type (string-ascii 8)))
  ;; Update vote record
  ;; Adjust vote tallies
)
```

**Milestone-Based Execution**
```clarity
;; Release funds in stages based on deliverables
multi-stage-treasury-releases
progress-reporting-requirements
```

## DAO Governance Models

### Potential Structures

**1. Progressive Decentralization**
```
Phase 1: Owner-controlled (bootstrap)
Phase 2: Multi-sig + community advisory
Phase 3: Full on-chain governance
```

**2. Bicameral System**
```
Token House: Token holder voting
Delegates House: Elected representatives
Both must approve major decisions
```

**3. Specialized Committees**
```
Technical Committee: Protocol changes
Treasury Committee: Financial decisions
Social Committee: Partnerships/events
Each with delegated authority
```

## Integration Examples

### Web Frontend
```javascript
// Submit proposal
async function submitProposal(title, description, type, amount, recipient) {
  const result = await dao.createProposal(
    title, description, type, amount, recipient
  );
  return result.proposalId;
}

// Vote on proposal
async function vote(proposalId, voteType) {
  await dao.vote(proposalId, voteType);
  // Update UI with new tallies
}

// Monitor proposal status
watchContract('proposal-passed', (event) => {
  notifyProposalPassed(event.proposalId);
});
```

### Governance Dashboard
```javascript
// Display all active proposals
const proposals = await dao.getActiveProposals();
proposals.forEach(p => {
  displayProposal({
    id: p.id,
    title: p.title,
    votesFor: p.votesFor,
    votesAgainst: p.votesAgainst,
    timeRemaining: p.votingEndsAt - currentBlock
  });
});
```

## Compliance & Legal

### Considerations
- DAO legal status varies by jurisdiction
- Token distribution may have securities implications
- Treasury management requires financial controls
- Voting decisions may create legal obligations
- Consider DAO LLC wrapper for legal protection

### Recommended Practices
- Consult legal counsel for DAO structure
- Implement KYC for token distribution if required
- Document governance procedures clearly
- Maintain transparent financial records
- Consider multi-sig for large treasury operations

## Development

### Prerequisites
- Clarinet CLI
- Stacks blockchain node
- Understanding of DAO governance

### Testing
```bash
clarinet test
```

### Deployment
```bash
clarinet deploy
```

## Contributing

We welcome contributions! Priority areas:
- Quadratic voting implementation
- Proposal templates and categories
- Delegation optimization
- Treasury management enhancements
- Governance analytics

## Resources

- [Aragon DAO Framework](https://aragon.org)
- [Compound Governance](https://compound.finance/governance)
- [MolochDAO](https://molochdao.com)
- [DAO Legal Frameworks](https://daos.paradigm.xyz)

## License

MIT License

---

**Contract Version**: 1.0.0  
**Network**: Stacks Blockchain  
**Language**: Clarity  
**Purpose**: Decentralized Governance & Treasury Management
