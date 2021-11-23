# ERC721Loanable Extension

This repo contains an extension to the ERC721 token standard that allows the deployment of NFTs that users can loan out risk-free in exchange for an up-front premium. Due to the loan functionality being built in to the NFT contract, a restriction can be added that prevents the transfer of tokens that are "under loan", and the contract is able to take back the NFT from the borrower's address at the end of the loan term.

This removes the risk of the borrower being able to "run off" with the NFT they've been lent by not paying the loan, and allow for much more capital efficient lending - the borrower does not need to put down collateral that is equal to >100% the value NFT - they only need to pay the loan interest or premium for the requested term.

An added bonus is that there is no need for any extra "approve" transactions to enable entering into a loan, since the NFT contract has control over all internal transfers by default.

The code supports both off-chain offer book style creation (like 0x) through signatures, and on-chain creation and matching to enable smart contracts to list and lend/borrow NFTs (since smart contracts can't sign). It would be possible to make this actually compatible with 0x, but I did not have time to look into it that deeply.

It adds the following functions to the standard contract:

```solidity

/* function that loans a token based on a signature by the lender */

function takeSignedLoan(LoanTerms calldata _lt, bytes memory _sig) public;

/* function to take a loan that has been registered via call (from a contract) */

function takeRegisteredLoan(LoanTerms calldata _lt) public;

/* function for smart contracts to lend tokens they own since they cannot create signatures */

function registerLoanOffer(LoanTerms calldata _lt) public;

/* function for lender to manually take back NFT */

function closeLoan(LoanTerms calldata _lt) public;

/* function that allows anyone to return a lender's outstanding NFT for a */
/* reward - note that this function has some subtle externalities */

function closeLoanIncentivized(LoanTerms calldata _lt) public;

/* allows EOA lender and borrower to renegotiate loan close */

function closeLoanEarly(
        LoanTerms calldata _lt,
        uint256 refund,
        bytes memory _lenderSig,
        bytes memory _borrowerSig) public;

/* explicitly cancel a loan that hasn't timed out yet */

function cancelLoan(LoanTerms calldata _lt) public;

```

The `LoanTerms` structure is what is signed and passed into the functions and enforces the terms of the loan, and is defined as follows:

```solidity

struct LoanTerms {
    address from;
    address to;
    IERC20 premiumToken;
    uint256 tokenId;
    uint256 premiumAmount;
    uint256 loanExpiry;
    uint256 closeFeeReward;
    uint256 offerDeadline;
    uint256 nonce;
}
```

All these functions are pass/fail, and will just revert if there is any issue. Contracts should not try to catch the revert unless they are confident about the end to end control flow.

## Important notes

This is a PoC, and while I have significant experience writing secure solidity, I have not written comprehensive tests for this so there may be bugs, and there are some missing features that are not worth putting in for the "general" case. If you plan to use this, reach out to me on twitter or via email and I can sanity check your use case or modifications.

Also very important - **DO NOT** modify this code to allow the borrower to move their tokens. You might think that it's okay given that the NFT contract can always "forcefully take back" the token at the end of the loan term, regardless of where it has been moved to - but this is a very dangerous thing to enable, as the borrower could then list and sell the token on a platform like OpenSea, or sell it to a smart contract, and have the buyer be rugged at the end of the loan term when the NFT they just bought disappears from their wallet or from the smart contract.
