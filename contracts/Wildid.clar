
(define-non-fungible-token wildid-nft uint)

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_OWNER_ONLY (err u100))
(define-constant ERR_NOT_TOKEN_OWNER (err u101))
(define-constant ERR_LISTING_NOT_FOUND (err u102))
(define-constant ERR_WRONG_COMMISSION (err u103))
(define-constant ERR_NOT_FOUND (err u104))
(define-constant ERR_METADATA_FROZEN (err u105))
(define-constant ERR_MINT_LIMIT (err u106))
(define-constant ERR_TRANSFER_RESTRICTED (err u107))
(define-constant ERR_INSUFFICIENT_FUNDS (err u108))
(define-constant ERR_INVALID_STATUS (err u109))
(define-constant ERR_NOT_VERIFIED (err u110))
(define-constant ERR_RESEARCH_NOT_FOUND (err u111))
(define-constant ERR_NOT_RESEARCHER (err u112))
(define-constant ERR_ALREADY_REVIEWED (err u113))
(define-constant ERR_INSUFFICIENT_FUNDING (err u114))
(define-constant ERR_RESEARCH_COMPLETED (err u115))

(define-data-var last-token-id uint u0)
(define-data-var total-supply uint u0)
(define-data-var mint-price uint u1000000)
(define-data-var conservation-fund uint u0)
(define-data-var contract-uri (optional (string-utf8 256)) none)
(define-data-var research-proposal-counter uint u0)
(define-data-var min-research-funding uint u5000000)

(define-map token-count principal uint)
(define-map market (tuple (token-id uint) (owner principal)) {price: uint, commission: principal})
(define-map administrators principal bool)
(define-map verified-conservationists principal bool)

(define-map species-registry uint {
    name: (string-utf8 64),
    scientific-name: (string-utf8 128),
    habitat: (string-utf8 256),
    conservation-status: (string-utf8 32),
    population-estimate: uint,
    threat-level: uint,
    region: (string-utf8 128),
    discovery-date: uint,
    verified: bool,
    metadata-frozen: bool
})

(define-map token-metadata uint {
    species-id: uint,
    individual-id: (string-utf8 64),
    tracking-data: (string-utf8 512),
    last-sighting: uint,
    health-status: (string-utf8 32),
    guardian: principal,
    transfer-restricted: bool,
    conservation-contribution: uint
})

(define-map guardian-permissions principal {
    can-transfer: bool,
    can-update-tracking: bool,
    verification-level: uint,
    registration-date: uint
})

(define-map conservation-donations principal uint)
(define-map species-funding uint uint)

(define-map registered-researchers principal {
    institution: (string-utf8 128),
    specialization: (string-utf8 64),
    verification-level: uint,
    research-credits: uint,
    registration-date: uint,
    active: bool
})

(define-map research-proposals uint {
    title: (string-utf8 128),
    description: (string-utf8 512),
    species-id: uint,
    researcher: principal,
    funding-goal: uint,
    current-funding: uint,
    start-date: uint,
    duration-blocks: uint,
    status: (string-utf8 16),
    peer-reviews: uint,
    positive-reviews: uint,
    data-hash: (optional (buff 32))
})

(define-map research-contributions principal uint)

(define-map research-findings uint {
    proposal-id: uint,
    findings: (string-utf8 1024),
    data-points: uint,
    confidence-level: uint,
    publication-date: uint,
    peer-verified: bool,
    impact-score: uint
})

(define-map peer-reviews (tuple (proposal-id uint) (reviewer principal)) {
    rating: uint,
    feedback: (string-utf8 256),
    review-date: uint,
    verified: bool
})

(define-map research-collaborations (tuple (proposal-id uint) (collaborator principal)) {
    role: (string-utf8 32),
    contribution-level: uint,
    join-date: uint,
    active: bool
})

(define-public (transfer (token-id uint) (sender principal) (recipient principal))
    (begin
        (asserts! (is-eq tx-sender sender) ERR_NOT_TOKEN_OWNER)
        (asserts! (is-eq (some sender) (nft-get-owner? wildid-nft token-id)) ERR_NOT_TOKEN_OWNER)
        (match (map-get? token-metadata token-id)
            metadata (if (get transfer-restricted metadata)
                        ERR_TRANSFER_RESTRICTED
                        (ok (try! (nft-transfer? wildid-nft token-id sender recipient))))
            ERR_NOT_FOUND)))

(define-public (set-administrator (user principal) (status bool))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_OWNER_ONLY)
        (ok (map-set administrators user status))))

(define-public (verify-conservationist (user principal))
    (begin
        (asserts! (or (is-eq tx-sender CONTRACT_OWNER) (default-to false (map-get? administrators tx-sender))) ERR_OWNER_ONLY)
        (ok (map-set verified-conservationists user true))))

(define-public (register-species (name (string-utf8 64)) (scientific-name (string-utf8 128)) (habitat (string-utf8 256)) (conservation-status (string-utf8 32)) (population-estimate uint) (threat-level uint) (region (string-utf8 128)))
    (let ((species-id (+ (var-get last-token-id) u1)))
        (asserts! (default-to false (map-get? verified-conservationists tx-sender)) ERR_NOT_VERIFIED)
        (map-set species-registry species-id {
            name: name,
            scientific-name: scientific-name,
            habitat: habitat,
            conservation-status: conservation-status,
            population-estimate: population-estimate,
            threat-level: threat-level,
            region: region,
            discovery-date: stacks-block-height,
            verified: false,
            metadata-frozen: false
        })
        (var-set last-token-id species-id)
        (ok species-id)))

(define-public (verify-species (species-id uint))
    (begin
        (asserts! (or (is-eq tx-sender CONTRACT_OWNER) (default-to false (map-get? administrators tx-sender))) ERR_OWNER_ONLY)
        (match (map-get? species-registry species-id)
            species (ok (map-set species-registry species-id (merge species {verified: true})))
            ERR_NOT_FOUND)))

(define-public (mint-wildlife-nft (species-id uint) (individual-id (string-utf8 64)) (tracking-data (string-utf8 512)) (recipient principal))
    (let ((token-id (+ (var-get total-supply) u1)))
        (asserts! (>= (stx-get-balance tx-sender) (var-get mint-price)) ERR_INSUFFICIENT_FUNDS)
        (asserts! (default-to false (map-get? verified-conservationists tx-sender)) ERR_NOT_VERIFIED)
        (match (map-get? species-registry species-id)
            species (if (get verified species)
                        (begin
                            (try! (stx-transfer? (var-get mint-price) tx-sender (as-contract tx-sender)))
                            (var-set conservation-fund (+ (var-get conservation-fund) (var-get mint-price)))
                            (try! (nft-mint? wildid-nft token-id recipient))
                            (map-set token-metadata token-id {
                                species-id: species-id,
                                individual-id: individual-id,
                                tracking-data: tracking-data,
                                last-sighting: stacks-block-height,
                                health-status: u"unknown",
                                guardian: tx-sender,
                                transfer-restricted: (>= (get threat-level species) u7),
                                conservation-contribution: (var-get mint-price)
                            })
                            (map-set guardian-permissions tx-sender {
                                can-transfer: true,
                                can-update-tracking: true,
                                verification-level: u1,
                                registration-date: stacks-block-height
                            })
                            (var-set total-supply token-id)
                            (map-set token-count recipient (+ (default-to u0 (map-get? token-count recipient)) u1))
                            (ok token-id))
                        ERR_NOT_VERIFIED)
            ERR_NOT_FOUND)))

(define-public (update-tracking-data (token-id uint) (new-tracking-data (string-utf8 512)) (health-status (string-utf8 32)))
    (match (map-get? token-metadata token-id)
        metadata (if (is-eq tx-sender (get guardian metadata))
                    (ok (map-set token-metadata token-id (merge metadata {
                        tracking-data: new-tracking-data,
                        health-status: health-status,
                        last-sighting: stacks-block-height
                    })))
                    ERR_NOT_TOKEN_OWNER)
        ERR_NOT_FOUND))

(define-public (donate-to-conservation (species-id uint) (amount uint))
    (begin
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        (var-set conservation-fund (+ (var-get conservation-fund) amount))
        (map-set conservation-donations tx-sender (+ (default-to u0 (map-get? conservation-donations tx-sender)) amount))
        (map-set species-funding species-id (+ (default-to u0 (map-get? species-funding species-id)) amount))
        (ok true)))

(define-public (list-in-market (token-id uint) (price uint) (comm-trait <commission-trait>))
    (let ((listing {token-id: token-id, owner: tx-sender}))
        (asserts! (is-eq (some tx-sender) (nft-get-owner? wildid-nft token-id)) ERR_NOT_TOKEN_OWNER)
        (map-set market listing {price: price, commission: (contract-of comm-trait)})
        (ok (map-set market listing {price: price, commission: (contract-of comm-trait)}))))

(define-public (unlist-in-market (token-id uint))
    (begin
        (asserts! (is-eq (some tx-sender) (nft-get-owner? wildid-nft token-id)) ERR_NOT_TOKEN_OWNER)
        (map-delete market {token-id: token-id, owner: tx-sender})
        (ok true)))

(define-public (buy-in-market (token-id uint) (comm-trait <commission-trait>))
    (let ((owner (unwrap! (nft-get-owner? wildid-nft token-id) ERR_NOT_FOUND))
          (listing (unwrap! (map-get? market {token-id: token-id, owner: owner}) ERR_LISTING_NOT_FOUND))
          (price (get price listing)))
        (asserts! (is-eq (contract-of comm-trait) (get commission listing)) ERR_WRONG_COMMISSION)
        (try! (stx-transfer? price tx-sender owner))
        (try! (contract-call? comm-trait pay token-id price))
        (try! (transfer token-id owner tx-sender))
        (map-delete market {token-id: token-id, owner: owner})
        (ok token-id)))

(define-public (set-mint-price (new-price uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_OWNER_ONLY)
        (ok (var-set mint-price new-price))))

(define-public (withdraw-conservation-funds (amount uint) (recipient principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_OWNER_ONLY)
        (asserts! (<= amount (var-get conservation-fund)) ERR_INSUFFICIENT_FUNDS)
        (try! (as-contract (stx-transfer? amount tx-sender recipient)))
        (var-set conservation-fund (- (var-get conservation-fund) amount))
        (ok true)))

(define-public (freeze-metadata (species-id uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_OWNER_ONLY)
        (match (map-get? species-registry species-id)
            species (ok (map-set species-registry species-id (merge species {metadata-frozen: true})))
            ERR_NOT_FOUND)))

(define-public (register-researcher (institution (string-utf8 128)) (specialization (string-utf8 64)))
    (begin
        (asserts! (default-to false (map-get? verified-conservationists tx-sender)) ERR_NOT_VERIFIED)
        (map-set registered-researchers tx-sender {
            institution: institution,
            specialization: specialization,
            verification-level: u1,
            research-credits: u0,
            registration-date: stacks-block-height,
            active: true
        })
        (ok true)))

(define-public (verify-researcher (researcher principal) (verification-level uint))
    (begin
        (asserts! (or (is-eq tx-sender CONTRACT_OWNER) (default-to false (map-get? administrators tx-sender))) ERR_OWNER_ONLY)
        (match (map-get? registered-researchers researcher)
            researcher-data (ok (map-set registered-researchers researcher 
                (merge researcher-data {verification-level: verification-level})))
            ERR_NOT_RESEARCHER)))

(define-public (create-research-proposal (title (string-utf8 128)) (description (string-utf8 512)) (species-id uint) (funding-goal uint) (duration-blocks uint))
    (let ((proposal-id (+ (var-get research-proposal-counter) u1)))
        (asserts! (>= funding-goal (var-get min-research-funding)) ERR_INSUFFICIENT_FUNDING)
        (asserts! (is-some (map-get? registered-researchers tx-sender)) ERR_NOT_RESEARCHER)
        (asserts! (is-some (map-get? species-registry species-id)) ERR_NOT_FOUND)
        (map-set research-proposals proposal-id {
            title: title,
            description: description,
            species-id: species-id,
            researcher: tx-sender,
            funding-goal: funding-goal,
            current-funding: u0,
            start-date: stacks-block-height,
            duration-blocks: duration-blocks,
            status: u"active",
            peer-reviews: u0,
            positive-reviews: u0,
            data-hash: none
        })
        (var-set research-proposal-counter proposal-id)
        (ok proposal-id)))

(define-public (fund-research-proposal (proposal-id uint) (amount uint))
    (match (map-get? research-proposals proposal-id)
        proposal (if (is-eq (get status proposal) u"active")
                    (begin
                        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
                        (map-set research-proposals proposal-id 
                            (merge proposal {current-funding: (+ (get current-funding proposal) amount)}))
                        (map-set research-contributions tx-sender 
                            (+ (default-to u0 (map-get? research-contributions tx-sender)) amount))
                        (ok true))
                    ERR_INVALID_STATUS)
        ERR_RESEARCH_NOT_FOUND))

(define-public (submit-peer-review (proposal-id uint) (rating uint) (feedback (string-utf8 256)))
    (let ((review-key {proposal-id: proposal-id, reviewer: tx-sender}))
        (asserts! (<= rating u5) ERR_INVALID_STATUS)
        (asserts! (is-some (map-get? registered-researchers tx-sender)) ERR_NOT_RESEARCHER)
        (asserts! (is-none (map-get? peer-reviews review-key)) ERR_ALREADY_REVIEWED)
        (match (map-get? research-proposals proposal-id)
            proposal (begin
                        (map-set peer-reviews review-key {
                            rating: rating,
                            feedback: feedback,
                            review-date: stacks-block-height,
                            verified: (>= (default-to u0 (get verification-level (map-get? registered-researchers tx-sender))) u2)
                        })
                        (map-set research-proposals proposal-id 
                            (merge proposal {
                                peer-reviews: (+ (get peer-reviews proposal) u1),
                                positive-reviews: (if (>= rating u4) (+ (get positive-reviews proposal) u1) (get positive-reviews proposal))
                            }))
                        (ok true))
            ERR_RESEARCH_NOT_FOUND)))

(define-public (publish-research-findings (proposal-id uint) (findings (string-utf8 1024)) (data-points uint) (confidence-level uint) (data-hash (buff 32)))
    (match (map-get? research-proposals proposal-id)
        proposal (if (is-eq tx-sender (get researcher proposal))
                    (let ((findings-id (+ (var-get research-proposal-counter) u1)))
                        (map-set research-findings findings-id {
                            proposal-id: proposal-id,
                            findings: findings,
                            data-points: data-points,
                            confidence-level: confidence-level,
                            publication-date: stacks-block-height,
                            peer-verified: (>= (get positive-reviews proposal) u3),
                            impact-score: (+ data-points confidence-level)
                        })
                        (map-set research-proposals proposal-id 
                            (merge proposal {
                                status: u"completed",
                                data-hash: (some data-hash)
                            }))
                        (match (map-get? registered-researchers tx-sender)
                            researcher (map-set registered-researchers tx-sender 
                                (merge researcher {research-credits: (+ (get research-credits researcher) u10)}))
                            false)
                        (ok findings-id))
                    ERR_NOT_TOKEN_OWNER)
        ERR_RESEARCH_NOT_FOUND))

(define-public (join-research-collaboration (proposal-id uint) (role (string-utf8 32)))
    (let ((collab-key {proposal-id: proposal-id, collaborator: tx-sender}))
        (asserts! (is-some (map-get? registered-researchers tx-sender)) ERR_NOT_RESEARCHER)
        (match (map-get? research-proposals proposal-id)
            proposal (if (is-eq (get status proposal) u"active")
                        (begin
                            (map-set research-collaborations collab-key {
                                role: role,
                                contribution-level: u1,
                                join-date: stacks-block-height,
                                active: true
                            })
                            (ok true))
                        ERR_INVALID_STATUS)
            ERR_RESEARCH_NOT_FOUND)))

(define-trait commission-trait
    ((pay (uint uint) (response bool uint))))

(define-read-only (get-last-token-id)
    (ok (var-get last-token-id)))

(define-read-only (get-token-uri (token-id uint))
    (ok none))

(define-read-only (get-total-supply)
    (ok (var-get total-supply)))

(define-read-only (get-owner (token-id uint))
    (ok (nft-get-owner? wildid-nft token-id)))

(define-read-only (get-species-info (species-id uint))
    (map-get? species-registry species-id))

(define-read-only (get-token-metadata (token-id uint))
    (map-get? token-metadata token-id))

(define-read-only (get-conservation-fund)
    (var-get conservation-fund))

(define-read-only (get-mint-price)
    (var-get mint-price))

(define-read-only (get-market-listing (token-id uint) (owner principal))
    (map-get? market {token-id: token-id, owner: owner}))

(define-read-only (get-guardian-permissions (guardian principal))
    (map-get? guardian-permissions guardian))

(define-read-only (is-verified-conservationist (user principal))
    (default-to false (map-get? verified-conservationists user)))

(define-read-only (get-species-funding (species-id uint))
    (default-to u0 (map-get? species-funding species-id)))

(define-read-only (get-donation-total (donor principal))
    (default-to u0 (map-get? conservation-donations donor)))

(define-read-only (get-researcher-info (researcher principal))
    (map-get? registered-researchers researcher))

(define-read-only (get-research-proposal (proposal-id uint))
    (map-get? research-proposals proposal-id))

(define-read-only (get-research-findings (findings-id uint))
    (map-get? research-findings findings-id))

(define-read-only (get-peer-review (proposal-id uint) (reviewer principal))
    (map-get? peer-reviews {proposal-id: proposal-id, reviewer: reviewer}))

(define-read-only (get-research-collaboration (proposal-id uint) (collaborator principal))
    (map-get? research-collaborations {proposal-id: proposal-id, collaborator: collaborator}))

(define-read-only (get-research-contribution-total (contributor principal))
    (default-to u0 (map-get? research-contributions contributor)))

(define-read-only (get-proposal-counter)
    (var-get research-proposal-counter))

(define-read-only (get-min-research-funding)
    (var-get min-research-funding))
