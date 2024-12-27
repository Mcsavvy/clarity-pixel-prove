;; PixelProve - Photography NFT Platform

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-token-owner (err u101))
(define-constant err-listing-not-found (err u102))
(define-constant err-insufficient-payment (err u103))

;; Define NFT
(define-non-fungible-token pixel-photo uint)

;; Data structures
(define-map photo-metadata
    uint
    {
        photographer: principal,
        title: (string-utf8 100),
        timestamp: uint,
        camera-model: (string-utf8 50),
        location: (string-utf8 100),
        settings: (string-utf8 100)
    }
)

(define-map photo-listings
    uint
    {
        price: uint,
        seller: principal
    }
)

(define-map royalty-settings
    uint
    {
        percentage: uint,
        recipient: principal
    }
)

;; Data variables
(define-data-var last-token-id uint u0)

;; Private functions
(define-private (is-owner (photo-id uint) (user principal))
    (is-eq user (unwrap! (nft-get-owner? pixel-photo photo-id) false))
)

;; Public functions
(define-public (mint-photo (title (string-utf8 100)) 
                          (camera-model (string-utf8 50))
                          (location (string-utf8 100))
                          (settings (string-utf8 100))
                          (royalty-percentage uint))
    (let
        (
            (token-id (+ (var-get last-token-id) u1))
        )
        (try! (nft-mint? pixel-photo token-id tx-sender))
        (map-set photo-metadata token-id {
            photographer: tx-sender,
            title: title,
            timestamp: block-height,
            camera-model: camera-model,
            location: location,
            settings: settings
        })
        (map-set royalty-settings token-id {
            percentage: royalty-percentage,
            recipient: tx-sender
        })
        (var-set last-token-id token-id)
        (ok token-id)
    )
)

(define-public (transfer (photo-id uint) (recipient principal))
    (let
        (
            (owner (unwrap! (nft-get-owner? pixel-photo photo-id) err-not-token-owner))
        )
        (asserts! (is-eq tx-sender owner) err-not-token-owner)
        (try! (nft-transfer? pixel-photo photo-id tx-sender recipient))
        (ok true)
    )
)

(define-public (list-for-sale (photo-id uint) (price uint))
    (let
        (
            (owner (unwrap! (nft-get-owner? pixel-photo photo-id) err-not-token-owner))
        )
        (asserts! (is-eq tx-sender owner) err-not-token-owner)
        (map-set photo-listings photo-id {
            price: price,
            seller: tx-sender
        })
        (ok true)
    )
)

(define-public (buy-photo (photo-id uint))
    (let
        (
            (listing (unwrap! (map-get? photo-listings photo-id) err-listing-not-found))
            (price (get price listing))
            (seller (get seller listing))
            (royalty (unwrap! (map-get? royalty-settings photo-id) err-listing-not-found))
            (royalty-amount (/ (* price (get percentage royalty)) u100))
        )
        (try! (stx-transfer? price tx-sender seller))
        (try! (stx-transfer? royalty-amount tx-sender (get recipient royalty)))
        (try! (nft-transfer? pixel-photo photo-id seller tx-sender))
        (map-delete photo-listings photo-id)
        (ok true)
    )
)

;; Read only functions
(define-read-only (get-photo-details (photo-id uint))
    (ok (map-get? photo-metadata photo-id))
)

(define-read-only (get-listing (photo-id uint))
    (ok (map-get? photo-listings photo-id))
)

(define-read-only (get-last-token-id)
    (ok (var-get last-token-id))
)