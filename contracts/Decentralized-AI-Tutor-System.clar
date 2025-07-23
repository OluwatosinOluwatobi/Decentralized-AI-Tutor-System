(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-exists (err u102))
(define-constant err-unauthorized (err u103))
(define-constant err-insufficient-funds (err u104))
(define-constant err-invalid-input (err u105))

(define-data-var next-module-id uint u1)
(define-data-var next-credential-id uint u1)
(define-data-var next-bounty-id uint u1)
(define-data-var dao-proposal-threshold uint u3)

(define-map users principal {
  user-type: (string-ascii 10),
  reputation: uint,
  joined-at: uint
})

(define-map learning-modules uint {
  title: (string-ascii 100),
  description: (string-ascii 500),
  difficulty: uint,
  subject: (string-ascii 50),
  language: (string-ascii 20),
  creator: principal,
  created-at: uint,
  active: bool
})

(define-map user-progress {user: principal, module-id: uint} {
  progress-percent: uint,
  completion-time: (optional uint),
  score: uint,
  attempts: uint
})

(define-map credentials uint {
  recipient: principal,
  module-id: uint,
  score: uint,
  issued-at: uint,
  verified: bool
})

(define-map nft-badges {user: principal, module-id: uint} {
  badge-type: (string-ascii 20),
  earned-at: uint,
  metadata-uri: (string-ascii 200)
})

(define-map dao-proposals uint {
  proposer: principal,
  title: (string-ascii 100),
  description: (string-ascii 500),
  proposal-type: (string-ascii 20),
  votes-for: uint,
  votes-against: uint,
  status: (string-ascii 10),
  created-at: uint,
  voting-deadline: uint
})

(define-map dao-votes {proposal-id: uint, voter: principal} bool)

(define-map content-bounties uint {
  title: (string-ascii 100),
  description: (string-ascii 500),
  language: (string-ascii 20),
  subject: (string-ascii 50),
  reward-amount: uint,
  creator: principal,
  assignee: (optional principal),
  status: (string-ascii 20),
  created-at: uint,
  deadline: uint
})

(define-public (register-user (user-type (string-ascii 10)))
  (let ((user-data {user-type: user-type, reputation: u0, joined-at: stacks-block-height}))
    (if (is-none (map-get? users tx-sender))
      (begin
        (map-set users tx-sender user-data)
        (ok true))
      (err err-already-exists))))

(define-public (create-learning-module 
  (title (string-ascii 100))
  (description (string-ascii 500))
  (difficulty uint)
  (subject (string-ascii 50))
  (language (string-ascii 20)))
  (let ((module-id (var-get next-module-id))
        (module-data {
          title: title,
          description: description,
          difficulty: difficulty,
          subject: subject,
          language: language,
          creator: tx-sender,
          created-at: stacks-block-height,
          active: true
        }))
    (begin
      (asserts! (is-some (map-get? users tx-sender)) (err err-unauthorized))
      (map-set learning-modules module-id module-data)
      (var-set next-module-id (+ module-id u1))
      (ok module-id))))

(define-public (enroll-in-module (module-id uint))
  (let ((module (map-get? learning-modules module-id))
        (progress-key {user: tx-sender, module-id: module-id}))
    (begin
      (asserts! (is-some module) (err err-not-found))
      (asserts! (is-some (map-get? users tx-sender)) (err err-unauthorized))
      (asserts! (is-none (map-get? user-progress progress-key)) (err err-already-exists))
      (map-set user-progress progress-key {
        progress-percent: u0,
        completion-time: none,
        score: u0,
        attempts: u1
      })
      (ok true))))

(define-public (update-progress 
  (module-id uint) 
  (progress-percent uint) 
  (score uint))
  (let ((progress-key {user: tx-sender, module-id: module-id})
        (existing-progress (map-get? user-progress progress-key)))
    (begin
      (asserts! (is-some existing-progress) (err err-not-found))
      (asserts! (<= progress-percent u100) (err err-invalid-input))
      (map-set user-progress progress-key {
        progress-percent: progress-percent,
        completion-time: (if (is-eq progress-percent u100) (some stacks-block-height) none),
        score: score,
        attempts: (+ (get attempts (unwrap-panic existing-progress)) u1)
      })
      (if (is-eq progress-percent u100)
        (begin
          (unwrap-panic (issue-credential module-id score))
          (unwrap-panic (award-nft-badge module-id score))
          (ok true))
        (ok true)))))

(define-private (issue-credential (module-id uint) (score uint))
  (let ((credential-id (var-get next-credential-id))
        (credential-data {
          recipient: tx-sender,
          module-id: module-id,
          score: score,
          issued-at: stacks-block-height,
          verified: true
        }))
    (begin
      (map-set credentials credential-id credential-data)
      (var-set next-credential-id (+ credential-id u1))
      (ok credential-id))))

(define-private (award-nft-badge (module-id uint) (score uint))
  (let ((badge-type (if (>= score u90) "gold" (if (>= score u70) "silver" "bronze")))
        (badge-key {user: tx-sender, module-id: module-id})
        (badge-data {
          badge-type: badge-type,
          earned-at: stacks-block-height,
          metadata-uri: ""
        }))
    (begin
      (map-set nft-badges badge-key badge-data)
      (ok true))))

(define-public (create-dao-proposal 
  (title (string-ascii 100))
  (description (string-ascii 500))
  (proposal-type (string-ascii 20))
  (voting-duration uint))
  (let ((proposal-id (var-get next-bounty-id))
        (proposal-data {
          proposer: tx-sender,
          title: title,
          description: description,
          proposal-type: proposal-type,
          votes-for: u0,
          votes-against: u0,
          status: "active",
          created-at: stacks-block-height,
          voting-deadline: (+ stacks-block-height voting-duration)
        }))
    (begin
      (asserts! (is-some (map-get? users tx-sender)) (err err-unauthorized))
      (map-set dao-proposals proposal-id proposal-data)
      (var-set next-bounty-id (+ proposal-id u1))
      (ok proposal-id))))

(define-public (vote-on-proposal (proposal-id uint) (vote-for bool))
  (let ((proposal (map-get? dao-proposals proposal-id))
        (vote-key {proposal-id: proposal-id, voter: tx-sender}))
    (begin
      (asserts! (is-some proposal) (err err-not-found))
      (asserts! (is-some (map-get? users tx-sender)) (err err-unauthorized))
      (asserts! (is-none (map-get? dao-votes vote-key)) (err err-already-exists))
      (asserts! (< stacks-block-height (get voting-deadline (unwrap-panic proposal))) (err err-invalid-input))
      (map-set dao-votes vote-key vote-for)
      (if vote-for
        (map-set dao-proposals proposal-id 
          (merge (unwrap-panic proposal) {votes-for: (+ (get votes-for (unwrap-panic proposal)) u1)}))
        (map-set dao-proposals proposal-id 
          (merge (unwrap-panic proposal) {votes-against: (+ (get votes-against (unwrap-panic proposal)) u1)})))
      (ok true))))

(define-public (create-content-bounty 
  (title (string-ascii 100))
  (description (string-ascii 500))
  (language (string-ascii 20))
  (subject (string-ascii 50))
  (reward-amount uint)
  (deadline uint))
  (let ((bounty-id (var-get next-bounty-id))
        (bounty-data {
          title: title,
          description: description,
          language: language,
          subject: subject,
          reward-amount: reward-amount,
          creator: tx-sender,
          assignee: none,
          status: "open",
          created-at: stacks-block-height,
          deadline: deadline
        }))
    (begin
      (asserts! (is-some (map-get? users tx-sender)) (err err-unauthorized))
      (map-set content-bounties bounty-id bounty-data)
      (var-set next-bounty-id (+ bounty-id u1))
      (ok bounty-id))))

(define-public (claim-bounty (bounty-id uint))
  (let ((bounty (map-get? content-bounties bounty-id)))
    (begin
      (asserts! (is-some bounty) (err err-not-found))
      (asserts! (is-some (map-get? users tx-sender)) (err err-unauthorized))
      (asserts! (is-eq (get status (unwrap-panic bounty)) "open") (err err-invalid-input))
      (map-set content-bounties bounty-id 
        (merge (unwrap-panic bounty) {assignee: (some tx-sender), status: "claimed"}))
      (ok true))))

(define-public (complete-bounty (bounty-id uint) (content-uri (string-ascii 200)))
  (let ((bounty (map-get? content-bounties bounty-id)))
    (begin
      (asserts! (is-some bounty) (err err-not-found))
      (asserts! (is-eq (some tx-sender) (get assignee (unwrap-panic bounty))) (err err-unauthorized))
      (asserts! (is-eq (get status (unwrap-panic bounty)) "claimed") (err err-invalid-input))
      (map-set content-bounties bounty-id 
        (merge (unwrap-panic bounty) {status: "completed"}))
      (ok true))))

(define-read-only (get-user (user principal))
  (map-get? users user))

(define-read-only (get-learning-module (module-id uint))
  (map-get? learning-modules module-id))

(define-read-only (get-user-progress (user principal) (module-id uint))
  (map-get? user-progress {user: user, module-id: module-id}))

(define-read-only (get-credential (credential-id uint))
  (map-get? credentials credential-id))

(define-read-only (get-nft-badge (user principal) (module-id uint))
  (map-get? nft-badges {user: user, module-id: module-id}))

(define-read-only (get-dao-proposal (proposal-id uint))
  (map-get? dao-proposals proposal-id))

(define-read-only (get-content-bounty (bounty-id uint))
  (map-get? content-bounties bounty-id))

(define-read-only (get-user-vote (proposal-id uint) (voter principal))
  (map-get? dao-votes {proposal-id: proposal-id, voter: voter}))
