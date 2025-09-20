;; StacksFlow Protocol - Community-Driven Content Validation Network
;;
;; Title: StacksFlow - Decentralized Content Quality Assurance System
;;
;; Summary: 
;; A revolutionary Bitcoin-secured protocol that harnesses collective intelligence 
;; to validate, curate, and monetize digital content through community consensus,
;; creating a self-sustaining ecosystem where quality content creators thrive.
;;
;; Description:
;; StacksFlow revolutionizes digital content discovery by implementing a trustless,
;; community-governed validation system built on Bitcoin's security model. The protocol
;; enables users to submit, evaluate, and monetarily reward exceptional content while
;; building transparent reputation systems. Through STX-powered economic incentives
;; and sophisticated consensus mechanisms, StacksFlow ensures that high-quality content
;; naturally rises to prominence while maintaining decentralized governance and
;; creator-friendly monetization pathways.
;;
;; Core Innovation:
;; - Bitcoin-secured content validation with immutable audit trails
;; - Stake-weighted community governance with reputation-based influence
;; - Direct peer-to-peer creator monetization without intermediaries  
;; - Multi-dimensional content categorization with expandable taxonomy
;; - Self-moderating community with transparent flagging mechanisms
;; - Economic sustainability through balanced fee structures

;; PROTOCOL CONFIGURATION & CONSTANTS

(define-constant PROTOCOL_ADMINISTRATOR tx-sender)

;; System Error Codes
(define-constant ERR_UNAUTHORIZED_ACCESS (err u100))
(define-constant ERR_INVALID_SUBMISSION (err u101))
(define-constant ERR_DUPLICATE_ENTRY (err u102))
(define-constant ERR_NONEXISTENT_ITEM (err u103))
(define-constant ERR_INADEQUATE_BALANCE (err u104))
(define-constant ERR_INVALID_TOPIC (err u105))
(define-constant ERR_INVALID_FLAG (err u106))
(define-constant ERR_OVERFLOW (err u107))
(define-constant ERR_INVALID_APPRAISAL (err u108))
(define-constant ERR_INVALID_ITEM_ID (err u109))

;; Protocol Parameters
(define-constant MIN_HYPERLINK_LENGTH u10)
(define-constant MAX_UINT u340282366920938463463374607431768211455)

;; STATE VARIABLES

(define-data-var submission-charge uint u10)
(define-data-var aggregate-submissions uint u0)
(define-data-var content-topics (list 10 (string-ascii 20)) 
  (list "Technology" "Science" "Art" "Politics" "Sports"))

;; DATA STORAGE ARCHITECTURE

;; Primary content registry with comprehensive metadata tracking
(define-map curated-items 
  { item-identifier: uint } 
  { 
    originator: principal, 
    headline: (string-ascii 100), 
    hyperlink: (string-ascii 200), 
    topic: (string-ascii 20),
    publication-epoch: uint, 
    appraisals: int,
    gratuities: uint,
    flags: uint
  }
)

;; Individual participant voting records for transparency
(define-map participant-appraisals 
  { participant: principal, item-identifier: uint } 
  { appraisal: int }
)

;; Community reputation scoring system
(define-map participant-credibility
  { participant: principal }
  { metric: int }
)

;; INTERNAL UTILITY FUNCTIONS

;; Verify content item existence in the registry
(define-private (item-exists (item-identifier uint))
  (is-some (map-get? curated-items { item-identifier: item-identifier }))
)

;; Optional value filter for content retrieval
(define-private (not-none (item (optional {
    originator: principal, 
    headline: (string-ascii 100), 
    hyperlink: (string-ascii 200), 
    topic: (string-ascii 20),
    publication-epoch: uint, 
    appraisals: int,
    gratuities: uint,
    flags: uint
  })))
  (is-some item)
)

;; Quality threshold filter - only return positively rated content
(define-private (retrieve-item-if-valid (id uint))
  (match (map-get? curated-items { item-identifier: id })
    item (if (>= (get appraisals item) 0) (some item) none)
    none
  )
)

;; Sequential enumeration generator for pagination (optimized for gas efficiency)
(define-private (enumerate (n uint))
  (let ((limit (if (> n u10) u10 n)))
    (list
      (if (>= limit u1) u1 u0)
      (if (>= limit u2) u2 u0)
      (if (>= limit u3) u3 u0)
      (if (>= limit u4) u4 u0)
      (if (>= limit u5) u5 u0)
      (if (>= limit u6) u6 u0)
      (if (>= limit u7) u7 u0)
      (if (>= limit u8) u8 u0)
      (if (>= limit u9) u9 u0)
      (if (>= limit u10) u10 u0)
    )
  )
)

;; Zero-value filter for list processing
(define-private (is-non-zero (n uint))
  (not (is-eq n u0))
)

;; CORE PROTOCOL FUNCTIONS

;; Content Submission: Gateway for community-driven content curation
(define-public (contribute-item (headline (string-ascii 100)) (hyperlink (string-ascii 200)) (topic (string-ascii 20)))
  (let
    (
      (item-identifier (+ (var-get aggregate-submissions) u1))
    )
    ;; Comprehensive input validation
    (asserts! (and 
                (>= (len headline) u1)
                (>= (len hyperlink) MIN_HYPERLINK_LENGTH)
                (>= (len topic) u1)
              ) ERR_INVALID_SUBMISSION)
    
    ;; Overflow protection for sequential IDs
    (asserts! (> item-identifier (var-get aggregate-submissions)) ERR_OVERFLOW)
    
    ;; Category validation against approved taxonomy
    (asserts! (is-some (index-of (var-get content-topics) topic)) ERR_INVALID_TOPIC)
    
    ;; Economic barrier verification for spam prevention
    (asserts! (>= (stx-get-balance tx-sender) (var-get submission-charge)) ERR_INADEQUATE_BALANCE)
    
    ;; Process submission fee to maintain protocol sustainability
    (try! (stx-transfer? (var-get submission-charge) tx-sender PROTOCOL_ADMINISTRATOR))
    
    ;; Immutable content registration with full metadata
    (map-set curated-items
      { item-identifier: item-identifier }
      {
        originator: tx-sender,
        headline: headline,
        hyperlink: hyperlink,
        topic: topic,
        publication-epoch: stacks-block-height,
        appraisals: 0,
        gratuities: u0,
        flags: u0
      }
    )
    
    ;; Update global submission counter
    (var-set aggregate-submissions item-identifier)
    
    ;; Emit blockchain event for external indexing
    (print { type: "new-item", item-identifier: item-identifier, originator: tx-sender })
    (ok item-identifier)
  )
)

;; Community Validation: Democratic quality assessment mechanism
(define-public (appraise-item (item-identifier uint) (appraisal int))
  (let
    (
      (previous-appraisal (default-to 0 (get appraisal (map-get? participant-appraisals { participant: tx-sender, item-identifier: item-identifier }))))
      (target-item (unwrap! (map-get? curated-items { item-identifier: item-identifier }) ERR_NONEXISTENT_ITEM))
      (appraiser-standing (default-to { metric: 0 } (map-get? participant-credibility { participant: tx-sender })))
    )
    ;; Content existence verification
    (asserts! (item-exists item-identifier) ERR_NONEXISTENT_ITEM)
    
    ;; Binary voting system enforcement (upvote/downvote only)
    (asserts! (or (is-eq appraisal 1) (is-eq appraisal -1)) ERR_INVALID_APPRAISAL)
    
    ;; Record individual voting decision
    (map-set participant-appraisals
      { participant: tx-sender, item-identifier: item-identifier }
      { appraisal: appraisal }
    )
    
    ;; Update aggregate content score with vote differential
    (map-set curated-items
      { item-identifier: item-identifier }
      (merge target-item { appraisals: (+ (get appraisals target-item) (- appraisal previous-appraisal)) })
    )
    
    ;; Enhance participant reputation through active engagement
    (map-set participant-credibility
      { participant: tx-sender }
      { metric: (+ (get metric appraiser-standing) appraisal) }
    )
    
    ;; Broadcast validation event for transparency
    (print { type: "appraisal", item-identifier: item-identifier, appraiser: tx-sender, appraisal: appraisal })
    (ok true)
  )
)

;; Direct Creator Monetization: Peer-to-peer value transfer system
(define-public (reward-originator (item-identifier uint) (gratuity-amount uint))
  (let
    (
      (target-item (unwrap! (map-get? curated-items { item-identifier: item-identifier }) ERR_NONEXISTENT_ITEM))
    )
    ;; Content existence validation
    (asserts! (item-exists item-identifier) ERR_NONEXISTENT_ITEM)
    
    ;; Financial capacity verification
    (asserts! (>= (stx-get-balance tx-sender) gratuity-amount) ERR_INADEQUATE_BALANCE)
    
    ;; Pre-transfer state update for security (prevent reentrancy)
    (map-set curated-items
      { item-identifier: item-identifier }
      (merge target-item { gratuities: (+ (get gratuities target-item) gratuity-amount) })
    )
    
    ;; Execute direct STX transfer to content creator
    (try! (stx-transfer? gratuity-amount tx-sender (get originator target-item)))
    
    ;; Emit monetization event for ecosystem tracking
    (print { type: "reward", item-identifier: item-identifier, from: tx-sender, to: (get originator target-item), amount: gratuity-amount })
    (ok true)
  )
)

;; Community Moderation: Decentralized content governance
(define-public (flag-item (item-identifier uint))
  (let
    (
      (target-item (unwrap! (map-get? curated-items { item-identifier: item-identifier }) ERR_NONEXISTENT_ITEM))
    )
    ;; Target content validation
    (asserts! (item-exists item-identifier) ERR_NONEXISTENT_ITEM)
    
    ;; Self-flagging prevention for integrity
    (asserts! (not (is-eq (get originator target-item) tx-sender)) ERR_INVALID_FLAG)
    
    ;; Increment community concern counter
    (map-set curated-items
      { item-identifier: item-identifier }
      (merge target-item { flags: (+ (get flags target-item) u1) })
    )
    
    ;; Record moderation action for transparency
    (print { type: "flag", item-identifier: item-identifier, flagger: tx-sender })
    (ok true)
  )
)

;; READ-ONLY QUERY INTERFACE

;; Retrieve comprehensive content metadata
(define-read-only (retrieve-item-details (item-identifier uint))
  (map-get? curated-items { item-identifier: item-identifier })
)

;; Query individual voting history
(define-read-only (retrieve-participant-appraisal (participant principal) (item-identifier uint))
  (get appraisal (map-get? participant-appraisals { participant: participant, item-identifier: item-identifier }))
)

;; Get total ecosystem content volume
(define-read-only (retrieve-aggregate-submissions)
  (var-get aggregate-submissions)
)

;; Access community reputation metrics
(define-read-only (retrieve-participant-credibility (participant principal))
  (default-to { metric: 0 } (map-get? participant-credibility { participant: participant }))
)

;; Generate paginated content identifiers
(define-read-only (get-item-ids (count uint))
  (filter is-non-zero (enumerate count))
)

;; Retrieve community-validated premium content
(define-read-only (retrieve-top-items (limit uint))
  (let
    (
      (item-count (var-get aggregate-submissions))
      (actual-limit (if (> limit item-count) item-count limit))
    )
    (filter not-none
      (map retrieve-item-if-valid (get-item-ids actual-limit))
    )
  )
)

;; ADMINISTRATIVE GOVERNANCE FUNCTIONS

;; Economic Parameter Adjustment: Protocol fee management
(define-public (adjust-submission-charge (new-charge uint))
  (begin
    (asserts! (is-eq tx-sender PROTOCOL_ADMINISTRATOR) ERR_UNAUTHORIZED_ACCESS)
    (asserts! (<= new-charge MAX_UINT) ERR_OVERFLOW)
    (var-set submission-charge new-charge)
    (print { type: "fee-change", new-charge: new-charge })
    (ok true)
  )
)

;; Content Governance: Emergency removal capability
(define-public (expunge-item (item-identifier uint))
  (begin
    (asserts! (is-eq tx-sender PROTOCOL_ADMINISTRATOR) ERR_UNAUTHORIZED_ACCESS)
    (asserts! (item-exists item-identifier) ERR_NONEXISTENT_ITEM)
    (map-delete curated-items { item-identifier: item-identifier })
    (print { type: "item-expunged", item-identifier: item-identifier })
    (ok true)
  )
)

;; Taxonomy Expansion: Dynamic category management
(define-public (introduce-topic (new-topic (string-ascii 20)))
  (begin
    (asserts! (is-eq tx-sender PROTOCOL_ADMINISTRATOR) ERR_UNAUTHORIZED_ACCESS)
    (asserts! (< (len (var-get content-topics)) u10) ERR_INVALID_TOPIC)
    (asserts! (>= (len new-topic) u1) ERR_INVALID_TOPIC)
    (var-set content-topics (unwrap-panic (as-max-len? (append (var-get content-topics) new-topic) u10)))
    (print { type: "new-topic", topic: new-topic })
    (ok true)
  )
)