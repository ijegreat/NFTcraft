;; NFT Art Marketplace Contract
;; Supports digital art NFT minting, trading, and royalty mechanisms

;; Constants and Error Codes
(define-constant MARKETPLACE-ADMINISTRATOR tx-sender)
(define-constant MARKETPLACE-COMMISSION-RATE u5)  ;; 5% marketplace commission

;; Error codes
(define-constant ERR-UNAUTHORIZED-ACTION (err u1))
(define-constant ERR-INSUFFICIENT-TRADER-BALANCE (err u2))
(define-constant ERR-INVALID-CREATOR-ROYALTY (err u3))
(define-constant ERR-ARTWORK-NOT-FOUND (err u4))
(define-constant ERR-INVALID-ARTWORK-IDENTIFIER (err u5))
(define-constant ERR-INVALID-LISTING-PRICE (err u6))

;; NFT Definition
(define-non-fungible-token digital-art-token (string-ascii 100))

;; Royalty tracking map
(define-map artwork-royalty-details 
  { artwork-id: (string-ascii 100) }
  {
    original-creator: principal,
    creator-royalty-percentage: uint
  }
)

;; Artwork listing map
(define-map artwork-market-listings
  { artwork-id: (string-ascii 100) }
  {
    sale-price: uint,
    artwork-seller: principal,
    is-currently-listed: bool
  }
)

;; Mint a new digital art NFT with royalty settings
(define-public (create-digital-art-token 
  (artwork-id (string-ascii 100)) 
  (artwork-metadata (string-ascii 256))
  (creator-royalty-percentage uint)
)
  (begin
    ;; Validate artwork identifier length and non-emptiness
    (asserts! (and 
      (> (len artwork-id) u0) 
      (<= (len artwork-id) u100)
    ) ERR-INVALID-ARTWORK-IDENTIFIER)
    
    ;; Validate creator royalty percentage (max 20%)
    (asserts! (<= creator-royalty-percentage u20) ERR-INVALID-CREATOR-ROYALTY)
    
    ;; Mint the digital art token
    (try! (nft-mint? digital-art-token artwork-id tx-sender))
    
    ;; Store royalty information
    (map-set artwork-royalty-details 
      { artwork-id: artwork-id }
      {
        original-creator: tx-sender,
        creator-royalty-percentage: creator-royalty-percentage
      }
    )
    
    (ok artwork-id)
  )
)

;; List a digital art NFT for sale
(define-public (list-artwork-for-sale 
  (artwork-id (string-ascii 100))
  (sale-price uint)
)
  (let 
    (
      (artwork-owner (unwrap! (nft-get-owner? digital-art-token artwork-id) ERR-ARTWORK-NOT-FOUND))
    )
    ;; Validate artwork identifier length
    (asserts! (and 
      (> (len artwork-id) u0) 
      (<= (len artwork-id) u100)
    ) ERR-INVALID-ARTWORK-IDENTIFIER)
    
    ;; Validate sale price (must be positive)
    (asserts! (> sale-price u0) ERR-INVALID-LISTING-PRICE)
    
    ;; Only artwork owner can list
    (asserts! (is-eq artwork-owner tx-sender) ERR-UNAUTHORIZED-ACTION)
    
    ;; Set listing details
    (map-set artwork-market-listings 
      { artwork-id: artwork-id }
      {
        sale-price: sale-price,
        artwork-seller: tx-sender,
        is-currently-listed: true
      }
    )
    
    (ok true)
  )
)

;; Purchase a digital art NFT
(define-public (purchase-artwork 
  (artwork-id (string-ascii 100))
)
  (let 
    (
      ;; Retrieve listing details
      (artwork-listing (unwrap! 
        (map-get? artwork-market-listings { artwork-id: artwork-id }) 
        ERR-ARTWORK-NOT-FOUND
      ))
      
      ;; Current owner of the artwork token
      (current-artwork-owner (unwrap! 
        (nft-get-owner? digital-art-token artwork-id) 
        ERR-ARTWORK-NOT-FOUND
      ))
      
      ;; Royalty details
      (artwork-royalty-info (unwrap! 
        (map-get? artwork-royalty-details { artwork-id: artwork-id }) 
        ERR-ARTWORK-NOT-FOUND
      ))
      
      ;; Calculate transaction fees
      (total-sale-price (get sale-price artwork-listing))
      (marketplace-commission (/ (* total-sale-price MARKETPLACE-COMMISSION-RATE) u100))
      (creator-royalty-amount (/ (* total-sale-price (get creator-royalty-percentage artwork-royalty-info)) u100))
      (seller-proceeds (- (- total-sale-price marketplace-commission) creator-royalty-amount))
    )
    ;; Ensure artwork is currently listed for sale
    (asserts! (get is-currently-listed artwork-listing) ERR-INSUFFICIENT-TRADER-BALANCE)
    
    ;; Verify buyer has sufficient funds
    (asserts! (>= (stx-get-balance tx-sender) total-sale-price) ERR-INSUFFICIENT-TRADER-BALANCE)
    
    ;; Transfer marketplace commission
    (try! (stx-transfer? marketplace-commission tx-sender MARKETPLACE-ADMINISTRATOR))
    
    ;; Transfer royalty to original creator
    (try! (stx-transfer? creator-royalty-amount tx-sender (get original-creator artwork-royalty-info)))
    
    ;; Transfer remaining amount to artwork seller
    (try! (stx-transfer? seller-proceeds tx-sender current-artwork-owner))
    
    ;; Transfer artwork token ownership
    (try! (nft-transfer? digital-art-token artwork-id current-artwork-owner tx-sender))
    
    ;; Update artwork listing status
    (map-set artwork-market-listings 
      { artwork-id: artwork-id }
      {
        sale-price: u0,
        artwork-seller: tx-sender,
        is-currently-listed: false
      }
    )
    
    (ok true)
  )
)

;; Retrieve artwork token information
(define-read-only (get-artwork-token-details (artwork-id (string-ascii 100)))
  {
    owner: (nft-get-owner? digital-art-token artwork-id),
    listing: (map-get? artwork-market-listings { artwork-id: artwork-id }),
    royalties: (map-get? artwork-royalty-details { artwork-id: artwork-id })
  }
)