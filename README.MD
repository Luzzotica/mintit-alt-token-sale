# MintIt Alt Token Sale

This contract allows people to create an alternate token that can be used to mint on MintIt.

Steps

1. Create an alt token sale by calling:
```lisp
(defun create-mintit-alt-coin:string 
  (
    collection-name:string
    bank-account:string
    alt-coin:module{fungible-v2}
    alt-kda-ratio:decimal
    require-whitelist:bool
    guard:guard
  )
)
```
2. Optionally whitelist accounts calling
```lisp
(defun add-whitelisted:[string] 
  (collection-name:string whitelisted:[string])
)
```
3. Build a website that lets users call
```lisp
(defun mint-with-alt-coin:string 
  (
    buyer:string
    collection-name:string
    guard:guard
  )
)

(defun claim-nfts:[string] 
  (buyer:string guard:guard)
)
```

You can get the nfts that a person has purchased through this method using
```lisp
(defun get-owned-nfts:[object] (buyer:string))
```

You can get the revealed NFTs by calling
```lisp
(defun get-revealed-nfts:[object] (buyer:string))
```

## Notes

`claim-nfts` can only be called once the NFT has been revealed by MintIt.

For users to claim you must pass in the following capability
```lisp
(MANAGED (get-managed-account-for-buyer buyer))
```
This means you will have to get their managed account using a local call first.  
I know this isn't ideal, but it's still a requirement for the permissions.