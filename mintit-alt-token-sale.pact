(namespace "free")

(module mintit-alt-token-sale GOV

  ;; -------------------------------
  ;; Governance and Permissions

  (defconst GOV_GUARD:string "gov")
  (defconst OPS_GUARD:string "ops")

  (defcap GOV ()
    (enforce-guard (at "guard" (read m-guards GOV_GUARD ["guard"])))
    (compose-capability (OPS))
  )

  (defcap OPS ()
    (enforce-guard (at "guard" (read m-guards OPS_GUARD ["guard"])))
  )

  (defschema m-guard ;; ID is a const: OPS_GUARD, GOV_GUARD etc.
    @doc "Stores guards for the module"
    guard:guard  
  )
  (deftable m-guards:{m-guard})

  (defun rotate-ops:string (guard:guard)
    @doc "Requires GOV. Changes the ops guard to the provided one."

    (with-capability (GOV)
      (update m-guards OPS_GUARD
        { "guard": guard }  
      )

      "Rotated OPS to a new guard"
    )
  )

  (defun rotate-gov:string (guard:guard)
    @doc "Requires GOV. Changes the gov guard to the provided one."

    (with-capability (GOV)
      (update m-guards GOV_GUARD
        { "guard": guard }  
      )

      "Rotated GOV to a new guard"
    )
  )

  (defun init-perms:string (gov:guard ops:guard)
    @doc "Initializes the guards and creates the tables for the module"

    ;; This is only vulnerable if GOV_GUARD doesn't exist
    ;; Which means it's only vulnerable if you don't call 
    ;; init when you deploy the contract.
    ;; So let us be sure that init is called. =)
    (insert m-guards GOV_GUARD
      { "guard": gov }  
    )
    (insert m-guards OPS_GUARD
      { "guard": ops }  
    )
  )

  ;; -------------------------------
  ;; String Values

  (defschema value
    @doc "Stores string values"
    value:string
  )
  (deftable values:{value})

  (defun update-string-value (val-id:string account:string)
    @doc "Updates the account for the bank"

    (with-capability (OPS)
      (write values val-id
        { "value": account }
      )
    )
  )

  (defun get-string-value:string (val-id:string)
    @doc "Gets the value with the provided id"

    (at "value" (read values val-id ["value"]))
  )

  ;; -------------------------------
  ;; Counter

  (defcap INCREMENT ()
    @doc "Private capability for incrementing the counter"
    true
  )

  (defschema counter
    @doc "Stores counters"
    counter:integer
  )
  (deftable counters:{counter})

  (defun increment-counter:integer (counter-id:string)
    @doc "Increments the given counter and returns the new count"

    (require-capability (INCREMENT))

    (with-read counters counter-id
      { "counter" := count }
      (let
        (
          (increment (+ count 1))
        )
        (update counters counter-id
          { "counter": increment }  
        )

        increment
      )
    )
  )

  (defun get-counter:integer (counter-id:string)
    (at "counter" (read counters counter-id ["counter"]))
  )

  (defun init-counter:string (counter-id:string)
    @doc "Initializes the guards and creates the tables for the module"

    (insert counters counter-id
      { "counter": 0 }  
    )
  )

  ;; -------------------------------
  ;; Managed Accounts

  (defcap MANAGED (account:string)
    @doc "Checks to make sure the guard for the given account name is satisfied"
    (enforce-guard (at "guard" (read managed-accounts account ["guard"])))
    (compose-capability (CONTRACT))
  )

  (defun require-MANAGED (account:string)
    @doc "The function used when building the user guard for managed accounts"
    (require-capability (MANAGED account))
  )

  (defun create-MANAGED-guard (account:string)
    @doc "Creates the user guard"
    (create-user-guard (require-MANAGED account))
  )

  (defschema managed-account ; ID is the account
    @doc "Stores each account and its guard"
    account:string
    guard:guard
  )
  (deftable managed-accounts:{managed-account})

  (defun create-managed-account:string 
    (
      account:string
      guard:guard
    )
    @doc "Creates an unguarded account with the provided coin contract. \
    \ Unguarded account allows smart contracts to install capabilities for them, \
    \ but they still require the root user's keyset"

    ; Create the managed account locally
    (insert managed-accounts account
      { "account": account
      , "guard": guard
      }
    )
  )

  (defun add-coin-to-managed-account:string 
    (
      account:string 
      token:module{fungible-v2}
    )
    @doc "Creates an unguarded account with the provided coin contract. \
    \ Unguarded account allows smart contracts to install capabilities for them, \
    \ but they still require the root user's keyset"
    
    (with-capability (MANAGED account)
      ; Create it in the provided coin
      (token::create-account 
        account
        (create-MANAGED-guard account)
      )
    )
  )

  ;; -------------------------------
  ;; MintIt Interaction

  (defcap MINTIT_ALT_COIN_MANAGER (collection-name)
    (with-read mintit-alt-coins collection-name
      { "guard":= guard }
      (enforce-guard guard)
    )
  )

  (defcap MINT ()
    @doc "Allows minting with an alt coin"
    (compose-capability (CONTRACT))
  )

  (defcap CONTRACT ()
    @doc "Private functions called from, or managed by the contract"
    true
  )

  (defun require-CONTRACT:bool (account:string)
    (require-capability (CONTRACT))
    true
  )

  (defun create-CONTRACT-guard:guard (account:string)
    (create-user-guard (require-CONTRACT account))
  )

  (defun contract-guard-name:string (account:string)
    (create-principal (create-CONTRACT-guard account))
  )

  (defschema mintit-alt-coin
    @doc "Stores a pool for an accepted alt coin. Id is the collection-name"
    collection-name:string
    bank-account:string
    alt-coin:module{fungible-v2}
    alt-kda-ratio:decimal
    require-whitelist:bool
    guard:guard
  )
  (deftable mintit-alt-coins:{mintit-alt-coin})

  (defun create-mintit-alt-coin:string 
    (
      collection-name:string
      bank-account:string
      alt-coin:module{fungible-v2}
      alt-kda-ratio:decimal
      require-whitelist:bool
      guard:guard
    )
    
    (insert mintit-alt-coins collection-name
      { "bank-account": bank-account
      , "collection-name": collection-name
      , "alt-coin": alt-coin
      , "alt-kda-ratio": alt-kda-ratio
      , "require-whitelist": require-whitelist
      , "guard": guard
      }
    )

    (with-capability (CONTRACT)
      (create-managed-account
        bank-account
        (create-CONTRACT-guard bank-account)
      )
      
      (add-coin-to-managed-account
        bank-account
        alt-coin
      )
    )
  )

  (defun mint-with-alt-coin:string 
    (
      buyer:string
      collection-name:string
      guard:guard
    )
    
    ; Require mint capability
    (with-capability (MINT) 
      ; Read from mintit alt coin
      (with-read mintit-alt-coins collection-name
        { "bank-account":= bank:string
        , "alt-coin":= alt-coin:module{fungible-v2}
        , "alt-kda-ratio":= alt-kda-ratio:decimal 
        , "require-whitelist":= require-whitelist:bool
        }  

        ; Enforce whitelist if required
        (if require-whitelist 
          (enforce-whitelisted collection-name buyer)  
          []
        )
        
        (let*
          (
            (tx-id (hash {"collection-name": collection-name, "buyer": buyer, "salt": (curr-time)}))
            (buyer-managed-account (contract-guard-name buyer))
            (buyer-contract-guard (create-CONTRACT-guard buyer))
            (buyer-managed-guard (create-MANAGED-guard buyer-managed-account))
            (mint-price (at "mint-price" (free.mintit-policy-v3.get-nft-collection collection-name)))
            (alt-coin-price (* mint-price alt-kda-ratio))
            (install-royalty-payout 
              (lambda (payout-info:object)
                (bind payout-info
                  { "stakeholder":= target, "payout":= payout }
                  (install-capability (coin.TRANSFER buyer-managed-account target payout))  
                )
              )
            )
          )

          ; Create a managed account to mint the token
          (with-default-read managed-accounts buyer-managed-account
            { "account": "", "guard": guard } 
            { "account":= old-a, "guard":= old-g } 
            ; If there is not account with that name yet, create one
            ; Otherwise, enforce the guard provided
            (if (= old-a "")
              (create-managed-account buyer-managed-account guard)
              (with-capability (MANAGED buyer-managed-account)
                true
              )
            )
          )

          (with-capability (MANAGED "bank")
            ; (create-managed-account buyer-managed-account buyer-managed-guard)
            
            ; Transfer tokens around
            (alt-coin::transfer buyer bank alt-coin-price)

            (install-capability (coin.TRANSFER bank buyer-managed-account mint-price))
            (coin.transfer-create bank buyer-managed-account buyer-contract-guard mint-price)

            ; Install needed capabilities and mint
            (map (install-royalty-payout) (at "payouts" (free.mintit-policy-v3.compute-nft-collection-mint-royalties collection-name buyer-managed-account)))
            (install-capability (free.mintit-policy-v3.MINT_NFT_REQUEST))
            (free.mintit-policy-v3.mint-nft {"account": buyer-managed-account, "guard": buyer-contract-guard, "collection-name": collection-name})
          )
        )
      )
    )
  )

  (defun get-managed-account-for-buyer:string (buyer:string)
    (contract-guard-name buyer)
  )

  (defun get-owned-nfts:[object] (buyer:string)
    (free.mintit-policy-v3.search-nfts-by-owner (get-managed-account-for-buyer buyer))
  )

  (defun get-revealed-nfts:[object] (buyer:string)
    (filter (compose (at "marmalade-token-id") (!= "")) (get-owned-nfts buyer))
  )

  (defun claim-nfts:[string] (buyer:string guard:guard)
    (let*
      (
        (managed-account (get-managed-account-for-buyer buyer))
        (transfer 
          (lambda (nft:object)
            (bind nft 
              { "marmalade-token-id":= token-id }
              (install-capability (marmalade.ledger.TRANSFER token-id managed-account buyer 1.0))  
              (marmalade.ledger.transfer-create token-id managed-account buyer guard 1.0)
            )
          )
        )
      )  
      ;  [managed-account]
      (with-capability (MANAGED managed-account)
        (map (transfer) (get-owned-nfts buyer))
      )
    )
  )

  ;; -------------------------------
  ;; Whitelisting

  (defschema whitelist
    @doc "Stores all the whitelisters. ID is the collection-name-account"
    whitelisted:bool
  )
  (deftable whitelisters:{whitelist})

  (defun add-whitelisted:[string] (collection-name:string whitelisted:[string])
    (with-capability (MINTIT_ALT_COIN_MANAGER collection-name)
      (map (add-whitelist collection-name) whitelisted)
    )
  )

  (defun add-whitelist:string (collection-name:string account:string)
    (require-capability (MINTIT_ALT_COIN_MANAGER collection-name))

    (write whitelisters (concat [collection-name "-" account])
      { "whitelisted": true }
    )
  )

  (defun enforce-whitelisted:bool (collection-name:string account:string)
    (with-default-read whitelisters (concat [collection-name "-" account])
      { "whitelisted": false }
      { "whitelisted":= wl }
      (enforce wl "Must be whitelisted")
    )
  )

  ;; -------------------------------
  ;; Utils

  (defun curr-time:time ()
    @doc "Returns current chain's block-time in time type"

    (at 'block-time (chain-data))
  )

)

(if (read-msg "init")
  [
    (create-table m-guards)
    (create-table counters)
    (create-table values)
    (create-table mintit-alt-coins)
    (create-table managed-accounts)
    (create-table whitelisters)
    (free.mintit-alt-token-sale.init-perms (read-keyset "gov") (read-keyset "ops"))
  ]
  "Contract upgraded"
)