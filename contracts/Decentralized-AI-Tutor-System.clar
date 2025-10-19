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
(define-data-var next-review-id uint u1)

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
  active: bool,
  prerequisite: (optional uint)
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

(define-map module-reviews uint {
  module-id: uint,
  reviewer: principal,
  rating: uint,
  review-text: (string-ascii 500),
  helpful-votes: uint,
  submitted-at: uint
})

(define-map module-ratings uint {
  total-rating: uint,
  review-count: uint,
  average-rating: uint
})

(define-map review-helpfulness {review-id: uint, voter: principal} bool)

(define-map referral-count principal uint)

(define-public (register-user (user-type (string-ascii 10)) (referrer (optional principal)))
  (let ((user-data {user-type: user-type, reputation: u0, joined-at: stacks-block-height}))
    (if (is-none (map-get? users tx-sender))
      (begin
        (map-set users tx-sender user-data)
        (if (is-some referrer)
          (let ((referrer-princ (unwrap-panic referrer)))
            (begin
              (asserts! (not (is-eq referrer-princ tx-sender)) (err err-invalid-input))
              (asserts! (is-some (map-get? users referrer-princ)) (err err-not-found))
              (let ((current-user (unwrap-panic (map-get? users tx-sender)))
                    (current-referrer (unwrap-panic (map-get? users referrer-princ)))
                    (current-count (default-to u0 (map-get? referral-count referrer-princ))))
                (begin
                  (map-set users tx-sender (merge current-user {reputation: (+ (get reputation current-user) u10)}))
                  (map-set users referrer-princ (merge current-referrer {reputation: (+ (get reputation current-referrer) u10)}))
                  (map-set referral-count referrer-princ (+ current-count u1))
                  true))))
          true)
        (ok true))
      (err err-already-exists))))

(define-public (create-learning-module
  (title (string-ascii 100))
  (description (string-ascii 500))
  (difficulty uint)
  (subject (string-ascii 50))
  (language (string-ascii 20))
  (prerequisite (optional uint)))
  (let ((module-id (var-get next-module-id))
        (module-data {
          title: title,
          description: description,
          difficulty: difficulty,
          subject: subject,
          language: language,
          creator: tx-sender,
          created-at: stacks-block-height,
          active: true,
          prerequisite: prerequisite
        }))
    (begin
      (asserts! (is-some (map-get? users tx-sender)) (err err-unauthorized))
      (if (is-some prerequisite)
        (asserts! (is-some (map-get? learning-modules (unwrap-panic prerequisite))) (err err-not-found))
        true)
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
      (if (is-some (get prerequisite (unwrap-panic module)))
        (let ((prereq-id (unwrap-panic (get prerequisite (unwrap-panic module))))
              (prereq-progress (map-get? user-progress {user: tx-sender, module-id: prereq-id})))
          (asserts! (and (is-some prereq-progress) (is-eq (get progress-percent (unwrap-panic prereq-progress)) u100)) (err err-unauthorized)))
        true)
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

(define-public (submit-module-review 
  (module-id uint) 
  (rating uint) 
  (review-text (string-ascii 500)))
  (let ((review-id (var-get next-review-id))
        (module (map-get? learning-modules module-id))
        (progress (map-get? user-progress {user: tx-sender, module-id: module-id}))
        (existing-review (filter-reviews-by-user-and-module tx-sender module-id))
        (review-data {
          module-id: module-id,
          reviewer: tx-sender,
          rating: rating,
          review-text: review-text,
          helpful-votes: u0,
          submitted-at: stacks-block-height
        }))
    (begin
      (asserts! (is-some module) (err err-not-found))
      (asserts! (is-some progress) (err err-unauthorized))
      (asserts! (and (>= rating u1) (<= rating u5)) (err err-invalid-input))
      (asserts! (is-eq existing-review u0) (err err-already-exists))
      (map-set module-reviews review-id review-data)
      (unwrap-panic (update-module-rating module-id rating))
      (unwrap-panic (award-reviewer-reputation))
      (var-set next-review-id (+ review-id u1))
      (ok review-id))))

(define-public (vote-review-helpful (review-id uint) (helpful bool))
  (let ((review (map-get? module-reviews review-id))
        (vote-key {review-id: review-id, voter: tx-sender}))
    (begin
      (asserts! (is-some review) (err err-not-found))
      (asserts! (is-some (map-get? users tx-sender)) (err err-unauthorized))
      (asserts! (is-none (map-get? review-helpfulness vote-key)) (err err-already-exists))
      (map-set review-helpfulness vote-key helpful)
      (if helpful
        (map-set module-reviews review-id 
          (merge (unwrap-panic review) {helpful-votes: (+ (get helpful-votes (unwrap-panic review)) u1)}))
        true)
      (ok true))))

(define-private (filter-reviews-by-user-and-module (user principal) (module-id uint))
  u0)

(define-private (update-module-rating (module-id uint) (new-rating uint))
  (let ((current-rating (default-to {total-rating: u0, review-count: u0, average-rating: u0} 
                                   (map-get? module-ratings module-id)))
        (new-total (+ (get total-rating current-rating) new-rating))
        (new-count (+ (get review-count current-rating) u1))
        (new-average (/ new-total new-count)))
    (begin
      (map-set module-ratings module-id {
        total-rating: new-total,
        review-count: new-count,
        average-rating: new-average
      })
      (ok true))))

(define-private (award-reviewer-reputation)
  (let ((current-user (unwrap-panic (map-get? users tx-sender))))
    (begin
      (map-set users tx-sender 
        (merge current-user {reputation: (+ (get reputation current-user) u5)}))
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

(define-read-only (get-module-review (review-id uint))
  (map-get? module-reviews review-id))

(define-read-only (get-module-rating (module-id uint))
  (map-get? module-ratings module-id))

(define-read-only (get-review-helpfulness (review-id uint) (voter principal))
  (map-get? review-helpfulness {review-id: review-id, voter: voter}))

(define-read-only (get-referral-count (user principal))
  (default-to u0 (map-get? referral-count user)))
