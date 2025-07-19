
;; Stackendance
;; stx-proof-of-attendance

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-ALREADY-CLAIMED (err u101))
(define-constant ERR-EVENT-NOT-ENDED (err u102))
(define-constant ERR-EVENT-ENDED (err u103))
(define-constant ERR-NO-REWARD (err u104))
(define-constant ERR-EVENT-NOT-FOUND (err u105))
(define-constant ERR-INSUFFICIENT-FUNDS (err u106))
(define-constant ERR-INVALID-DURATION (err u107))
(define-constant ERR-ALREADY-REGISTERED (err u108))


;; Constants for validation
(define-constant MAX-DURATION u52560) ;; Example: max duration of ~1 year in blocks (assuming 10-min blocks)
(define-constant MIN-DURATION u144)   ;; Example: min duration of 1 day in blocks
(define-constant MAX-REWARD u1000000000000) ;; Example: 1000 STX maximum reward
(define-constant ERR-INVALID-START-HEIGHT (err u110))
(define-constant ERR-INVALID-REWARD (err u111))
(define-constant ERR-INVALID-MIN-ATTENDANCE (err u112))


;; Data variables
(define-data-var contract-owner principal tx-sender)
(define-data-var event-counter uint u0)
(define-data-var treasury-balance uint u0)

;; Event struct
(define-map events 
    uint 
    {
        name: (string-ascii 50),
        description: (string-ascii 200),
        start-height: uint,
        end-height: uint,
        base-reward: uint,
        bonus-reward: uint,
        min-attendance-duration: uint,
        organizer: principal,
        is-active: bool
    })

;; Attendance tracking
(define-map event-attendance 
    { event-id: uint, attendee: principal }
    {
        check-in-height: uint,
        check-out-height: uint,
        duration: uint,
        verified: bool
    })

;; Separate map for verification details
(define-map verification-details
    { event-id: uint, attendee: principal }
    {
        verified-by: principal,
        verified-at: uint
    })


;; Rewards claimed
(define-map rewards-claimed
    { event-id: uint, attendee: principal }
    {
        amount: uint,
        claimed-at: uint,
        reward-tier: uint
    })

;; Verification authorities
(define-map verifiers principal bool)

;; Read-only functions
(define-read-only (get-owner)
    (var-get contract-owner))

(define-read-only (get-event (event-id uint))
    (map-get? events event-id))

(define-read-only (get-attendance-record (event-id uint) (attendee principal))
    (map-get? event-attendance {event-id: event-id, attendee: attendee}))

(define-read-only (get-reward-claim (event-id uint) (attendee principal))
    (map-get? rewards-claimed {event-id: event-id, attendee: attendee}))

(define-read-only (is-verifier (address principal))
    (default-to false (map-get? verifiers address)))

;; Event management functions

;; Constants for string validation
(define-constant MIN-NAME-LENGTH u3)
(define-constant MAX-NAME-LENGTH u50)
(define-constant MIN-DESC-LENGTH u10)
(define-constant MAX-DESC-LENGTH u200)
(define-constant ERR-INVALID-NAME (err u2000))
(define-constant ERR-INVALID-DESCRIPTION (err u2001))
(define-constant ERR-CONTAINS-INVALID-CHARS (err u2002))

;; Helper function to check if string contains only valid characters
(define-private (is-valid-ascii (s (string-ascii 200)))
    (let ((len (len s)))
        (and
            ;; Check if length is greater than 0
            (> len u0)
            ;; Ensure first character isn't whitespace
            (not (is-eq (unwrap-panic (element-at s u0)) " "))
            ;; Ensure last character isn't whitespace
            (not (is-eq (unwrap-panic (element-at s (- len u1))) " ")))))


(define-public (create-event (name (string-ascii 50)) 
                           (description (string-ascii 200))
                           (start-height uint)
                           (duration uint)
                           (base-reward uint)
                           (bonus-reward uint)
                           (min-attendance uint))
    (let ((event-id (+ (var-get event-counter) u1))
          (end-height (+ start-height duration))
          (current-height stacks-block-height)
          (name-length (len name))
          (desc-length (len description)))
        (begin
            ;; Authorization check
            (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)

            ;; Name validation
            (asserts! (and (>= name-length MIN-NAME-LENGTH)
                          (<= name-length MAX-NAME-LENGTH)
                          (is-valid-ascii name))
                     ERR-INVALID-NAME)

            ;; Description validation
            (asserts! (and (>= desc-length MIN-DESC-LENGTH)
                          (<= desc-length MAX-DESC-LENGTH)
                          (is-valid-ascii description))
                     ERR-INVALID-DESCRIPTION)

            ;; Duration validation
            (asserts! (and (>= duration MIN-DURATION) 
                          (<= duration MAX-DURATION)) 
                     ERR-INVALID-DURATION)

            ;; Start height validation - must be in the future
            (asserts! (> start-height current-height) 
                     ERR-INVALID-START-HEIGHT)

            ;; Reward amount validation
            (asserts! (and (<= base-reward MAX-REWARD)
                          (<= bonus-reward MAX-REWARD)
                          (> base-reward u0))
                     ERR-INVALID-REWARD)

            ;; Minimum attendance validation
            (asserts! (and (> min-attendance u0)
                          (<= min-attendance duration))
                     ERR-INVALID-MIN-ATTENDANCE)

            ;; Create the event with validated data
            (map-set events event-id
                {
                    name: name,
                    description: description,
                    start-height: start-height,
                    end-height: end-height,
                    base-reward: base-reward,
                    bonus-reward: bonus-reward,
                    min-attendance-duration: min-attendance,
                    organizer: tx-sender,
                    is-active: true
                })

            ;; Update event counter
            (var-set event-counter event-id)
            (ok event-id))))



;; Helper function to check if an event exists
(define-read-only (event-exists (event-id uint))
    (is-some (map-get? events event-id)))
;; Attendance functions
(define-public (check-in (event-id uint))
    (let ((event (unwrap! (get-event event-id) ERR-EVENT-NOT-FOUND)))
        (begin
            (asserts! (get is-active event) ERR-EVENT-ENDED)          ;; Fixed: correct tuple accessor syntax
            (asserts! (>= stacks-block-height (get start-height event)) ERR-EVENT-NOT-ENDED)  ;; Fixed: correct tuple accessor syntax
            (asserts! (< stacks-block-height (get end-height event)) ERR-EVENT-ENDED)         ;; Fixed: correct tuple accessor syntax
            (asserts! (is-none (get-attendance-record event-id tx-sender)) ERR-ALREADY-REGISTERED)
            (map-set event-attendance 
                {event-id: event-id, attendee: tx-sender}
                {
                    check-in-height: stacks-block-height,
                    check-out-height: u0,
                    duration: u0,
                    verified: false
                })
            (ok true))))

(define-public (check-out (event-id uint))
    (let ((attendance (unwrap! (get-attendance-record event-id tx-sender) ERR-EVENT-NOT-FOUND))
          (event (unwrap! (get-event event-id) ERR-EVENT-NOT-FOUND)))
        (begin
            (asserts! (get is-active event) ERR-EVENT-ENDED)                         ;; Fixed: correct tuple accessor syntax
            (asserts! (> stacks-block-height (get check-in-height attendance)) ERR-INVALID-DURATION)  ;; Fixed: correct tuple accessor syntax
            (let ((duration (- stacks-block-height (get check-in-height attendance))))      ;; Fixed: correct tuple accessor syntax
                (map-set event-attendance
                    {event-id: event-id, attendee: tx-sender}
                    {
                        check-in-height: (get check-in-height attendance),           ;; Fixed: correct tuple accessor syntax
                        check-out-height: stacks-block-height,
                        duration: duration,
                        verified: false
                    })
                (ok duration)))))

;; Additional error codes for verification
(define-constant ERR-EVENT-NOT-ACTIVE (err u120))
(define-constant ERR-NO-CHECKIN-RECORD (err u121))
(define-constant ERR-ALREADY-VERIFIED (err u122))
(define-constant ERR-INVALID-ATTENDEE (err u123))

;; Helper function to check if attendance can be verified
(define-read-only (can-verify-attendance (event-id uint) (attendee principal))
    (let ((attendance (get-attendance-record event-id attendee))
          (event (get-event event-id)))
        (and 
            (is-some attendance)                          ;; Attendance record exists
            (is-some event)                              ;; Event exists
            (get is-active (unwrap! event false))        ;; Event is active
            (> (get check-in-height (unwrap! attendance false)) u0)  ;; Has checked in
            (not (get verified (unwrap! attendance false)))          ;; Not already verified
        )))


;; Enhanced verification function
(define-public (verify-attendance (event-id uint) (attendee principal))
    (let ((attendance (unwrap! (get-attendance-record event-id attendee) ERR-EVENT-NOT-FOUND))
          (event (unwrap! (get-event event-id) ERR-EVENT-NOT-FOUND)))
        (begin
            ;; Verify the caller is authorized
            (asserts! (is-verifier tx-sender) ERR-NOT-AUTHORIZED)

            ;; Check if event is still active
            (asserts! (get is-active event) ERR-EVENT-NOT-ACTIVE)

            ;; Verify attendee is a valid principal
            (asserts! (not (is-eq attendee tx-sender)) ERR-INVALID-ATTENDEE)

            ;; Check if already verified
            (asserts! (not (get verified attendance)) ERR-ALREADY-VERIFIED)

            ;; Verify check-in record exists and is valid
            (asserts! (> (get check-in-height attendance) u0) ERR-NO-CHECKIN-RECORD)

            ;; Update attendance record
            (map-set event-attendance
                {event-id: event-id, attendee: attendee}
                (merge attendance {verified: true}))

            ;; Store verification details separately
            (map-set verification-details
                {event-id: event-id, attendee: attendee}
                {
                    verified-by: tx-sender,
                    verified-at: stacks-block-height
                })
            (ok true))))

;; Helper function to get verification details
(define-read-only (get-verification-details (event-id uint) (attendee principal))
    (map-get? verification-details {event-id: event-id, attendee: attendee}))

;; Helper function to check verification status with details
(define-read-only (get-full-verification-status (event-id uint) (attendee principal))
    (let ((attendance (get-attendance-record event-id attendee))
          (details (get-verification-details event-id attendee)))
        {
            verified: (match attendance
                        attendance-data (get verified attendance-data)
                        false),
            details: details
        }))

;; Reward claiming
(define-public (claim-reward (event-id uint))
    (let ((event (unwrap! (get-event event-id) ERR-EVENT-NOT-FOUND))
          (attendance (unwrap! (get-attendance-record event-id tx-sender) ERR-EVENT-NOT-FOUND)))
        (begin
            (asserts! (> stacks-block-height (get end-height event)) ERR-EVENT-NOT-ENDED)          ;; Fixed: correct tuple accessor syntax
            (asserts! (get verified attendance) ERR-NOT-AUTHORIZED)                          ;; Fixed: correct tuple accessor syntax
            (asserts! (is-none (get-reward-claim event-id tx-sender)) ERR-ALREADY-CLAIMED)

            ;; Calculate reward based on attendance duration
            (let ((base-amount (get base-reward event))                                      ;; Fixed: correct tuple accessor syntax
                  (bonus-amount (if (>= (get duration attendance)                            ;; Fixed: correct tuple accessor syntax
                                      (get min-attendance-duration event))                    ;; Fixed: correct tuple accessor syntax
                                  (get bonus-reward event)                                   ;; Fixed: correct tuple accessor syntax
                                  u0))
                  (total-reward (+ base-amount bonus-amount)))

                (asserts! (<= total-reward (var-get treasury-balance)) ERR-INSUFFICIENT-FUNDS)
                (try! (as-contract (stx-transfer? total-reward tx-sender tx-sender)))
                (var-set treasury-balance (- (var-get treasury-balance) total-reward))

                (map-set rewards-claimed
                    {event-id: event-id, attendee: tx-sender}
                    {
                        amount: total-reward,
                        claimed-at: stacks-block-height,
                        reward-tier: (if (> bonus-amount u0) u2 u1)
                    })
                (ok total-reward)))))
;; Constants
(define-constant BURN-ADDRESS 'SP000000000000000000002Q6VF78)
;; (define-constant ERR-NOT-AUTHORIZED (err u1000))
;; (define-constant ERR-EVENT-NOT-FOUND (err u1001))
(define-constant ERR-INVALID-ADDRESS (err u1002))
(define-constant ERR-ALREADY-VERIFIER (err u1003))
(define-constant ERR-NOT-VERIFIER (err u1004))
(define-constant ERR-INVALID-AMOUNT (err u1005))
(define-constant ERR-EVENT-ALREADY-INACTIVE (err u1006))
(define-constant ERR-TRANSFER-FAILED (err u1007))

;; Admin functions
(define-public (add-verifier (address principal))
    (begin
        ;; Check if caller is contract owner
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
        ;; Check if address is valid (not burn address)
        (asserts! (not (is-eq address BURN-ADDRESS)) ERR-INVALID-ADDRESS)
        ;; Check if address is not already a verifier
        (asserts! (not (default-to false (map-get? verifiers address))) ERR-ALREADY-VERIFIER)
        ;; Add verifier
        (map-set verifiers address true)
        (ok true)))

(define-public (remove-verifier (address principal))
    (begin
        ;; Check if caller is contract owner
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
        ;; Check if address is valid
        (asserts! (not (is-eq address BURN-ADDRESS)) ERR-INVALID-ADDRESS)
        ;; Check if address is currently a verifier
        (asserts! (default-to false (map-get? verifiers address)) ERR-NOT-VERIFIER)
        ;; Remove verifier
        (map-set verifiers address false)
        (ok true)))

(define-public (deactivate-event (event-id uint))
    (let 
        (
            (event (unwrap! (get-event event-id) ERR-EVENT-NOT-FOUND))
        )
        (begin
            ;; Check if caller is contract owner
            (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
            ;; Check if event exists and is currently active
            (asserts! (get is-active event) ERR-EVENT-ALREADY-INACTIVE)
            ;; Deactivate event
            (map-set events event-id
                (merge event {is-active: false}))
            (ok true))))

(define-public (deposit-funds (amount uint))
    (begin
        ;; Check if amount is valid (greater than 0)
        (asserts! (> amount u0) ERR-INVALID-AMOUNT)
        ;; Check if sender has sufficient balance
        (asserts! (<= amount (stx-get-balance tx-sender)) ERR-INVALID-AMOUNT)
        ;; Perform transfer
        (let ((transfer-result (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))))
            (begin
                (var-set treasury-balance (+ (var-get treasury-balance) amount))
                (ok true)))))

(define-public (withdraw-funds (amount uint))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
        (asserts! (<= amount (var-get treasury-balance)) ERR-INSUFFICIENT-FUNDS)
        (try! (as-contract (stx-transfer? amount tx-sender tx-sender)))
        (var-set treasury-balance (- (var-get treasury-balance) amount))
        (ok true)))