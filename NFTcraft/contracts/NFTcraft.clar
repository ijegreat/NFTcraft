;; NFT Marketplace Contract
;; Supports NFT minting, trading, and royalty mechanisms

;; Constants and Error Codes
(define-constant CONTRACT-OWNER tx-sender)
(define-constant MARKET-FEE-RATE u5)  ;; 5% marketplace fee

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u1))
(define-constant ERR-INSUFFICIENT-BALANCE (err u2))
(define-constant ERR-INVALID-ROYALTY (err u3))
(define-constant ERR-NFT-NOT-FOUND (err u4))
(define-constant ERR-INVALID-NFT-ID (err u5))
(define-constant ERR-INVALID-PRICE (err u6))
(define-constant ERR-ALREADY-LISTED (err u7))

;; NFT Definition
(define-non-fungible-token marketplace-nft (string-ascii 100))

;; Royalty tracking map
(define-map nft-royalties 
  { nft-id: (string-ascii 100) }
  {
    creator: principal,
    royalty-rate: uint
  }
)

;; Market listing map
(define-map market-listings
  { nft-id: (string-ascii 100) }
  {
    price: uint,
    seller: principal,
    listed: bool
  }
)

;; Helper function to validate NFT ID
(define-private (is-valid-nft-id (nft-id (string-ascii 100)))
  (and 
    (> (len nft-id) u0)
    (<= (len nft-id) u100)
  )
)

;; Helper function to validate ownership
(define-private (is-owner (nft-id (string-ascii 100)))
  (match (nft-get-owner? marketplace-nft nft-id)
    owner (is-eq tx-sender owner)
    false
  )
)

;; Mint a new NFT with royalty settings
(define-public (mint-nft 
  (nft-id (string-ascii 100)) 
  (metadata (string-ascii 256))
  (royalty-rate uint)
)
  (begin
    ;; Validate NFT ID length
    (asserts! (is-valid-nft-id nft-id) ERR-INVALID-NFT-ID)
    
    ;; Validate royalty rate (max 20%)
    (asserts! (<= royalty-rate u20) ERR-INVALID-ROYALTY)
    
    ;; Mint the NFT
    (try! (nft-mint? marketplace-nft nft-id tx-sender))
    
    ;; Store royalty info
    (map-set nft-royalties 
      { nft-id: nft-id }
      {
        creator: tx-sender,
        royalty-rate: royalty-rate
      }
    )
    
    (ok nft-id)
  )
)

;; List NFT for sale
(define-public (list-nft 
  (nft-id (string-ascii 100))
  (price uint)
)
  (let 
    (
      (owner (unwrap! (nft-get-owner? marketplace-nft nft-id) ERR-NFT-NOT-FOUND))
      (current-listing (map-get? market-listings { nft-id: nft-id }))
    )
    ;; Validate NFT ID and ownership
    (asserts! (is-valid-nft-id nft-id) ERR-INVALID-NFT-ID)
    (asserts! (is-owner nft-id) ERR-NOT-AUTHORIZED)
    
    ;; Validate price
    (asserts! (> price u0) ERR-INVALID-PRICE)
    
    ;; Verify ownership
    (asserts! (is-eq owner tx-sender) ERR-NOT-AUTHORIZED)
    
    ;; Check if not already listed
    (asserts! (or 
      (is-none current-listing)
      (not (get listed (unwrap-panic current-listing)))
    ) ERR-ALREADY-LISTED)
    
    ;; Create listing
    (map-set market-listings 
      { nft-id: nft-id }
      {
        price: price,
        seller: tx-sender,
        listed: true
      }
    )
    
    (ok true)
  )
)

;; Remove NFT listing
(define-public (delist-nft 
  (nft-id (string-ascii 100))
)
  (let 
    (
      (owner (unwrap! (nft-get-owner? marketplace-nft nft-id) ERR-NFT-NOT-FOUND))
      (listing (unwrap! (map-get? market-listings { nft-id: nft-id }) ERR-NFT-NOT-FOUND))
    )
    ;; Validate NFT ID and ownership
    (asserts! (is-valid-nft-id nft-id) ERR-INVALID-NFT-ID)
    (asserts! (is-owner nft-id) ERR-NOT-AUTHORIZED)
    
    ;; Verify listing status
    (asserts! (get listed listing) ERR-NOT-AUTHORIZED)
    
    ;; Remove listing
    (map-set market-listings 
      { nft-id: nft-id }
      {
        price: u0,
        seller: tx-sender,
        listed: false
      }
    )
    
    (ok true)
  )
)

;; Purchase an NFT
(define-public (buy-nft 
  (nft-id (string-ascii 100))
)
  (let 
    (
      ;; Validate NFT ID
      (valid-id (asserts! (is-valid-nft-id nft-id) ERR-INVALID-NFT-ID))
      
      ;; Get listing details
      (listing (unwrap! (map-get? market-listings { nft-id: nft-id }) ERR-NFT-NOT-FOUND))
      
      ;; Get current owner
      (current-owner (unwrap! (nft-get-owner? marketplace-nft nft-id) ERR-NFT-NOT-FOUND))
      
      ;; Get royalty details
      (royalty-info (unwrap! (map-get? nft-royalties { nft-id: nft-id }) ERR-NFT-NOT-FOUND))
      
      ;; Calculate fees
      (sale-price (get price listing))
      (market-fee (/ (* sale-price MARKET-FEE-RATE) u100))
      (royalty-amount (/ (* sale-price (get royalty-rate royalty-info)) u100))
      (seller-amount (- (- sale-price market-fee) royalty-amount))
    )
    ;; Verify listing status
    (asserts! (get listed listing) ERR-INSUFFICIENT-BALANCE)
    
    ;; Check buyer balance
    (asserts! (>= (stx-get-balance tx-sender) sale-price) ERR-INSUFFICIENT-BALANCE)
    
    ;; Transfer market fee
    (try! (stx-transfer? market-fee tx-sender CONTRACT-OWNER))
    
    ;; Transfer royalty
    (try! (stx-transfer? royalty-amount tx-sender (get creator royalty-info)))
    
    ;; Transfer payment to seller
    (try! (stx-transfer? seller-amount tx-sender current-owner))
    
    ;; Transfer NFT ownership
    (try! (nft-transfer? marketplace-nft nft-id current-owner tx-sender))
    
    ;; Update listing
    (map-set market-listings 
      { nft-id: nft-id }
      {
        price: u0,
        seller: tx-sender,
        listed: false
      }
    )
    
    (ok true)
  )
)

;; Get NFT information
(define-read-only (get-nft-info (nft-id (string-ascii 100)))
  (begin
    (asserts! (is-valid-nft-id nft-id) ERR-INVALID-NFT-ID)
    (ok {
      owner: (nft-get-owner? marketplace-nft nft-id),
      listing: (map-get? market-listings { nft-id: nft-id }),
      royalties: (map-get? nft-royalties { nft-id: nft-id })
    })
  )
)