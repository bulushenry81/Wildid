;; Wildlife Rehabilitation Tracker Contract
;; Tracks injured/sick wildlife through rehabilitation and recovery process

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u200))
(define-constant ERR_CASE_NOT_FOUND (err u201))
(define-constant ERR_INVALID_STATUS (err u202))
(define-constant ERR_TREATMENT_NOT_FOUND (err u203))
(define-constant ERR_CENTER_NOT_VERIFIED (err u204))
(define-constant ERR_INVALID_WILDLIFE_TOKEN (err u205))
(define-constant ERR_CASE_ALREADY_EXISTS (err u206))
(define-constant ERR_INSUFFICIENT_FUNDS (err u207))

;; Case status constants
(define-constant STATUS_ADMITTED u1)
(define-constant STATUS_TREATMENT u2)
(define-constant STATUS_RECOVERY u3)
(define-constant STATUS_READY_RELEASE u4)
(define-constant STATUS_RELEASED u5)
(define-constant STATUS_DECEASED u6)

;; Treatment types
(define-constant TREATMENT_SURGERY u1)
(define-constant TREATMENT_MEDICATION u2)
(define-constant TREATMENT_THERAPY u3)
(define-constant TREATMENT_NUTRITION u4)

(define-data-var case-counter uint u0)
(define-data-var treatment-counter uint u0)
(define-data-var rehabilitation-fund uint u0)

;; Verified rehabilitation centers
(define-map rehabilitation-centers principal {
    center-name: (string-utf8 128),
    location: (string-utf8 128),
    license-number: (string-utf8 64),
    specializations: (list 5 (string-utf8 32)),
    verified: bool,
    capacity: uint,
    current-cases: uint,
    success-rate: uint,
    registration-date: uint
})

;; Rehabilitation cases
(define-map rehabilitation-cases uint {
    token-id: uint,
    center: principal,
    admission-date: uint,
    injury-type: (string-utf8 128),
    severity-level: uint,
    initial-condition: (string-utf8 256),
    current-status: uint,
    estimated-recovery-time: uint,
    total-cost: uint,
    veterinarian: principal,
    case-notes: (string-utf8 512)
})

;; Treatment records
(define-map treatment-records uint {
    case-id: uint,
    treatment-type: uint,
    treatment-date: uint,
    procedure-details: (string-utf8 256),
    medication: (string-utf8 128),
    cost: uint,
    administered-by: principal,
    effectiveness-score: uint,
    next-treatment: (optional uint)
})

;; Recovery progress tracking
(define-map recovery-progress uint {
    case-id: uint,
    progress-percentage: uint,
    milestone-reached: (string-utf8 64),
    assessment-date: uint,
    mobility-score: uint,
    feeding-status: (string-utf8 32),
    behavioral-notes: (string-utf8 256),
    assessed-by: principal
})

;; Case funding tracking
(define-map case-funding uint {
    total-donated: uint,
    funding-goal: uint,
    donors-count: uint,
    emergency-priority: bool
})

;; Register rehabilitation center
(define-public (register-rehabilitation-center (center-name (string-utf8 128)) (location (string-utf8 128)) (license-number (string-utf8 64)) (specializations (list 5 (string-utf8 32))) (capacity uint))
    (begin
        (asserts! (contract-call? .Wildid is-verified-conservationist tx-sender) ERR_UNAUTHORIZED)
        (map-set rehabilitation-centers tx-sender {
            center-name: center-name,
            location: location,
            license-number: license-number,
            specializations: specializations,
            verified: false,
            capacity: capacity,
            current-cases: u0,
            success-rate: u0,
            registration-date: stacks-block-height
        })
        (ok true)
    )
)

;; Verify rehabilitation center (admin only)
(define-public (verify-rehabilitation-center (center principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (match (map-get? rehabilitation-centers center)
            center-data (ok (map-set rehabilitation-centers center 
                (merge center-data {verified: true})))
            ERR_CASE_NOT_FOUND)
    )
)

;; Admit wildlife for rehabilitation
(define-public (admit-wildlife (token-id uint) (injury-type (string-utf8 128)) (severity-level uint) (initial-condition (string-utf8 256)) (estimated-recovery-time uint) (veterinarian principal))
    (let ((case-id (+ (var-get case-counter) u1)))
        (asserts! (is-some (contract-call? .Wildid get-token-metadata token-id)) ERR_INVALID_WILDLIFE_TOKEN)
        (asserts! (default-to false (get verified (map-get? rehabilitation-centers tx-sender))) ERR_CENTER_NOT_VERIFIED)
        (asserts! (is-none (map-get? rehabilitation-cases case-id)) ERR_CASE_ALREADY_EXISTS)
        
        (map-set rehabilitation-cases case-id {
            token-id: token-id,
            center: tx-sender,
            admission-date: stacks-block-height,
            injury-type: injury-type,
            severity-level: severity-level,
            initial-condition: initial-condition,
            current-status: STATUS_ADMITTED,
            estimated-recovery-time: estimated-recovery-time,
            total-cost: u0,
            veterinarian: veterinarian,
            case-notes: u""
        })
        
        ;; Initialize case funding
        (map-set case-funding case-id {
            total-donated: u0,
            funding-goal: (* severity-level u1000000),
            donors-count: u0,
            emergency-priority: (>= severity-level u8)
        })
        
        (var-set case-counter case-id)
        (ok case-id)
    )
)

;; Record treatment
(define-public (record-treatment (case-id uint) (treatment-type uint) (procedure-details (string-utf8 256)) (medication (string-utf8 128)) (cost uint))
    (let ((treatment-id (+ (var-get treatment-counter) u1)))
        (match (map-get? rehabilitation-cases case-id)
            case-data (if (or (is-eq tx-sender (get center case-data)) (is-eq tx-sender (get veterinarian case-data)))
                (begin
                    (map-set treatment-records treatment-id {
                        case-id: case-id,
                        treatment-type: treatment-type,
                        treatment-date: stacks-block-height,
                        procedure-details: procedure-details,
                        medication: medication,
                        cost: cost,
                        administered-by: tx-sender,
                        effectiveness-score: u0,
                        next-treatment: none
                    })
                    ;; Update case total cost
                    (map-set rehabilitation-cases case-id 
                        (merge case-data {
                            total-cost: (+ (get total-cost case-data) cost),
                            current-status: STATUS_TREATMENT
                        }))
                    (var-set treatment-counter treatment-id)
                    (ok treatment-id))
                ERR_UNAUTHORIZED)
            ERR_CASE_NOT_FOUND)
    )
)

;; Update recovery progress
(define-public (update-recovery-progress (case-id uint) (progress-percentage uint) (milestone-reached (string-utf8 64)) (mobility-score uint) (feeding-status (string-utf8 32)) (behavioral-notes (string-utf8 256)))
    (match (map-get? rehabilitation-cases case-id)
        case-data (if (or (is-eq tx-sender (get center case-data)) (is-eq tx-sender (get veterinarian case-data)))
            (let ((new-status (if (>= progress-percentage u90)
                                STATUS_READY_RELEASE
                                (if (>= progress-percentage u50)
                                    STATUS_RECOVERY
                                    STATUS_TREATMENT))))
                (map-set recovery-progress case-id {
                    case-id: case-id,
                    progress-percentage: progress-percentage,
                    milestone-reached: milestone-reached,
                    assessment-date: stacks-block-height,
                    mobility-score: mobility-score,
                    feeding-status: feeding-status,
                    behavioral-notes: behavioral-notes,
                    assessed-by: tx-sender
                })
                ;; Update case status based on progress
                (map-set rehabilitation-cases case-id 
                    (merge case-data {current-status: new-status}))
                (ok true))
            ERR_UNAUTHORIZED)
        ERR_CASE_NOT_FOUND)
)

;; Release wildlife back to wild
(define-public (release-wildlife (case-id uint) (release-location (string-utf8 128)) (release-notes (string-utf8 256)))
    (match (map-get? rehabilitation-cases case-id)
        case-data (if (is-eq tx-sender (get center case-data))
            (begin
                (asserts! (is-eq (get current-status case-data) STATUS_READY_RELEASE) ERR_INVALID_STATUS)
                (map-set rehabilitation-cases case-id 
                    (merge case-data {
                        current-status: STATUS_RELEASED,
                        case-notes: release-notes
                    }))
                ;; Update wildlife NFT tracking data
                (try! (contract-call? .Wildid update-tracking-data 
                    (get token-id case-data)
                    u"Released from rehabilitation - location recorded in case notes"
                    u"healthy"))
                (ok true))
            ERR_UNAUTHORIZED)
        ERR_CASE_NOT_FOUND)
)

;; Donate to specific rehabilitation case
(define-public (donate-to-case (case-id uint) (amount uint))
    (match (map-get? rehabilitation-cases case-id)
        case-data (begin
            (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
            (var-set rehabilitation-fund (+ (var-get rehabilitation-fund) amount))
            (match (map-get? case-funding case-id)
                funding (map-set case-funding case-id 
                    (merge funding {
                        total-donated: (+ (get total-donated funding) amount),
                        donors-count: (+ (get donors-count funding) u1)
                    }))
                (map-set case-funding case-id {
                    total-donated: amount,
                    funding-goal: u1000000,
                    donors-count: u1,
                    emergency-priority: false
                }))
            (ok true))
        ERR_CASE_NOT_FOUND)
)

;; Update treatment effectiveness
(define-public (rate-treatment-effectiveness (treatment-id uint) (effectiveness-score uint))
    (match (map-get? treatment-records treatment-id)
        treatment (match (map-get? rehabilitation-cases (get case-id treatment))
            case-data (if (is-eq tx-sender (get veterinarian case-data))
                (begin
                    (asserts! (<= effectiveness-score u10) ERR_INVALID_STATUS)
                    (map-set treatment-records treatment-id 
                        (merge treatment {effectiveness-score: effectiveness-score}))
                    (ok true))
                ERR_UNAUTHORIZED)
            ERR_CASE_NOT_FOUND)
        ERR_TREATMENT_NOT_FOUND)
)

;; Get rehabilitation case details
(define-read-only (get-rehabilitation-case (case-id uint))
    (map-get? rehabilitation-cases case-id)
)

;; Get treatment record
(define-read-only (get-treatment-record (treatment-id uint))
    (map-get? treatment-records treatment-id)
)

;; Get recovery progress
(define-read-only (get-recovery-progress (case-id uint))
    (map-get? recovery-progress case-id)
)

;; Get rehabilitation center info
(define-read-only (get-rehabilitation-center (center principal))
    (map-get? rehabilitation-centers center)
)

;; Get case funding status
(define-read-only (get-case-funding (case-id uint))
    (map-get? case-funding case-id)
)

;; Get rehabilitation statistics
(define-read-only (get-rehabilitation-stats)
    (ok {
        total-cases: (var-get case-counter),
        total-treatments: (var-get treatment-counter),
        rehabilitation-fund: (var-get rehabilitation-fund)
    })
)

;; Check if case is ready for release
(define-read-only (is-ready-for-release (case-id uint))
    (match (map-get? rehabilitation-cases case-id)
        case-data (is-eq (get current-status case-data) STATUS_READY_RELEASE)
        false)
)

;; Get case status string
(define-read-only (get-status-name (status uint))
    (if (is-eq status STATUS_ADMITTED)
        "Admitted"
        (if (is-eq status STATUS_TREATMENT)
            "In Treatment"
            (if (is-eq status STATUS_RECOVERY)
                "Recovering"
                (if (is-eq status STATUS_READY_RELEASE)
                    "Ready for Release"
                    (if (is-eq status STATUS_RELEASED)
                        "Released"
                        "Deceased"
                    )
                )
            )
        )
    )
)
