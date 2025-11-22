;; VotingDAO - Decentralized Autonomous Organization
;; Token-based governance with proposals, voting, and treasury management

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-already-voted (err u103))
(define-constant err-voting-closed (err u104))
(define-constant err-proposal-not-passed (err u105))
(define-constant err-already-executed (err u106))
(define-constant err-insufficient-tokens (err u107))

(define-constant voting-period u1440) ;; ~10 days in blocks
(define-constant quorum-threshold u1000000) ;; Minimum tokens needed
(define-constant approval-threshold u60) ;; 60% approval needed

(define-data-var next-proposal-id uint u1)
(define-data-var treasury-balance uint u0)
(define-data-var total-governance-tokens uint u0)

(define-map proposals
  uint
  {
    proposer: principal,
    title: (string-ascii 128),
    description: (string-ascii 512),
    proposal-type: (string-ascii 32),
    amount-requested: uint,
    recipient: (optional principal),
    votes-for: uint,
    votes-against: uint,
    votes-abstain: uint,
    status: (string-ascii 16),
    created-at: uint,
    voting-ends-at: uint,
    executed-at: (optional uint)
  }
)

(define-map votes
  {proposal-id: uint, voter: principal}
  {
    vote-type: (string-ascii 8),
    voting-power: uint,
    voted-at: uint
  }
)

(define-map governance-tokens
  principal
  {
    balance: uint,
    delegated-to: (optional principal),
    proposals-created: uint,
    votes-cast: uint
  }
)

(define-map delegation-power
  principal
  uint
)

(define-public (mint-governance-tokens (recipient principal) (amount uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)

    (let ((current-balance (default-to
          {balance: u0, delegated-to: none, proposals-created: u0, votes-cast: u0}
          (map-get? governance-tokens recipient))))
      (map-set governance-tokens recipient
        (merge current-balance {balance: (+ (get balance current-balance) amount)}))
    )

    (var-set total-governance-tokens (+ (var-get total-governance-tokens) amount))

    (print {event: "tokens-minted", recipient: recipient, amount: amount})
    (ok true)
  )
)

(define-public (create-proposal
    (title (string-ascii 128))
    (description (string-ascii 512))
    (proposal-type (string-ascii 32))
    (amount-requested uint)
    (recipient (optional principal)))
  (let (
    (proposal-id (var-get next-proposal-id))
    (token-holder (unwrap! (map-get? governance-tokens tx-sender) err-insufficient-tokens))
  )
    (asserts! (>= (get balance token-holder) u1000) err-insufficient-tokens)

    (map-set proposals proposal-id {
      proposer: tx-sender,
      title: title,
      description: description,
      proposal-type: proposal-type,
      amount-requested: amount-requested,
      recipient: recipient,
      votes-for: u0,
      votes-against: u0,
      votes-abstain: u0,
      status: "active",
      created-at: block-height,
      voting-ends-at: (+ block-height voting-period),
      executed-at: none
    })

    (map-set governance-tokens tx-sender
      (merge token-holder {proposals-created: (+ (get proposals-created token-holder) u1)}))

    (var-set next-proposal-id (+ proposal-id u1))

    (print {event: "proposal-created", proposal-id: proposal-id, proposer: tx-sender})
    (ok proposal-id)
  )
)

(define-public (vote (proposal-id uint) (vote-type (string-ascii 8)))
  (let (
    (proposal (unwrap! (map-get? proposals proposal-id) err-not-found))
    (token-holder (unwrap! (map-get? governance-tokens tx-sender) err-insufficient-tokens))
    (voting-power (get balance token-holder))
    (delegated-power (default-to u0 (map-get? delegation-power tx-sender)))
    (total-power (+ voting-power delegated-power))
  )
    (asserts! (is-eq (get status proposal) "active") err-voting-closed)
    (asserts! (<= block-height (get voting-ends-at proposal)) err-voting-closed)
    (asserts! (is-none (map-get? votes {proposal-id: proposal-id, voter: tx-sender})) err-already-voted)
    (asserts! (> total-power u0) err-insufficient-tokens)

    (map-set votes {proposal-id: proposal-id, voter: tx-sender} {
      vote-type: vote-type,
      voting-power: total-power,
      voted-at: block-height
    })

    (map-set proposals proposal-id
      (merge proposal {
        votes-for: (if (is-eq vote-type "for") (+ (get votes-for proposal) total-power) (get votes-for proposal)),
        votes-against: (if (is-eq vote-type "against") (+ (get votes-against proposal) total-power) (get votes-against proposal)),
        votes-abstain: (if (is-eq vote-type "abstain") (+ (get votes-abstain proposal) total-power) (get votes-abstain proposal))
      }))

    (map-set governance-tokens tx-sender
      (merge token-holder {votes-cast: (+ (get votes-cast token-holder) u1)}))

    (print {event: "vote-cast", proposal-id: proposal-id, voter: tx-sender, vote: vote-type})
    (ok true)
  )
)

(define-public (finalize-proposal (proposal-id uint))
  (let ((proposal (unwrap! (map-get? proposals proposal-id) err-not-found)))
    (asserts! (is-eq (get status proposal) "active") err-already-executed)
    (asserts! (> block-height (get voting-ends-at proposal)) err-voting-closed)

    (let (
      (total-votes (+ (+ (get votes-for proposal) (get votes-against proposal)) (get votes-abstain proposal)))
      (approval-pct (if (> total-votes u0)
        (/ (* (get votes-for proposal) u100) total-votes)
        u0))
    )
      (if (and (>= total-votes quorum-threshold) (>= approval-pct approval-threshold))
        (begin
          (map-set proposals proposal-id (merge proposal {status: "passed"}))
          (print {event: "proposal-passed", proposal-id: proposal-id})
          (ok true)
        )
        (begin
          (map-set proposals proposal-id (merge proposal {status: "rejected"}))
          (print {event: "proposal-rejected", proposal-id: proposal-id})
          (ok false)
        )
      )
    )
  )
)

(define-public (execute-proposal (proposal-id uint))
  (let ((proposal (unwrap! (map-get? proposals proposal-id) err-not-found)))
    (asserts! (is-eq (get status proposal) "passed") err-proposal-not-passed)
    (asserts! (is-none (get executed-at proposal)) err-already-executed)

    (if (is-eq (get proposal-type proposal) "treasury")
      (begin
        (asserts! (>= (var-get treasury-balance) (get amount-requested proposal)) err-insufficient-tokens)
        (var-set treasury-balance (- (var-get treasury-balance) (get amount-requested proposal)))
        (map-set proposals proposal-id
          (merge proposal {
            status: "executed",
            executed-at: (some block-height)
          }))
        (print {event: "proposal-executed", proposal-id: proposal-id, amount: (get amount-requested proposal)})
        (ok true)
      )
      (begin
        (map-set proposals proposal-id
          (merge proposal {
            status: "executed",
            executed-at: (some block-height)
          }))
        (print {event: "proposal-executed", proposal-id: proposal-id})
        (ok true)
      )
    )
  )
)

(define-public (delegate-voting-power (delegate principal))
  (let ((token-holder (unwrap! (map-get? governance-tokens tx-sender) err-insufficient-tokens)))
    (map-set governance-tokens tx-sender
      (merge token-holder {delegated-to: (some delegate)}))

    (let ((current-delegation (default-to u0 (map-get? delegation-power delegate))))
      (map-set delegation-power delegate (+ current-delegation (get balance token-holder)))
    )

    (print {event: "power-delegated", delegator: tx-sender, delegate: delegate})
    (ok true)
  )
)

(define-public (deposit-to-treasury (amount uint))
  (begin
    (var-set treasury-balance (+ (var-get treasury-balance) amount))
    (print {event: "treasury-deposit", amount: amount, depositor: tx-sender})
    (ok true)
  )
)

(define-read-only (get-proposal (proposal-id uint))
  (map-get? proposals proposal-id)
)

(define-read-only (get-vote-details (proposal-id uint) (voter principal))
  (map-get? votes {proposal-id: proposal-id, voter: voter})
)

(define-read-only (get-token-balance (holder principal))
  (ok (map-get? governance-tokens holder))
)

(define-read-only (get-dao-stats)
  (ok {
    treasury-balance: (var-get treasury-balance),
    total-tokens: (var-get total-governance-tokens),
    total-proposals: (- (var-get next-proposal-id) u1)
  })
)
