//SPDX-License-Identifier: GPLv3

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "@openzeppelin/contracts/access/Ownable.sol";

import "hardhat/console.sol";

abstract contract ERC721Loanable is ERC721 {

    using ECDSA for bytes32;
    using SafeERC20 for IERC20;

    enum LoanStatus {
        NONE,
        PENDING,
        ACTIVE,
        CLOSED,
        CANCELLED
    }

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

    event Loan(
        address from,
        address to,
        uint256 tokenId
    );


    mapping (uint256 => address) _loanedTokens;

    mapping (bytes32 => LoanStatus) _loans;

    mapping (address => mapping (address => uint256)) loanApprovals; 


    modifier LoanSanityCheck(LoanTerms calldata _lt){
        require(_lt.offerDeadline > block.timestamp, "Offer expiry in the past.");
        require(_lt.loanExpiry != 0 && block.timestamp < _lt.loanExpiry, "Loan expiry in the past.");
        require(_lt.offerDeadline <= _lt.loanExpiry, "Offer expiry can't go past loan term.");
        _;
    }

    modifier LoanTargetCheck(address _to){
        require(_to == msg.sender || _to == address(0), "Caller is not target of offer.");
        _;
    }

    constructor(string memory name, string memory symbol) ERC721(name, symbol) {}

    /* function that loans a token based on a signature by the lender */

    function takeSignedLoan(LoanTerms calldata _lt, bytes memory _sig) LoanSanityCheck(_lt) LoanTargetCheck(_lt.to) public {

        bytes32 hash = keccak256(abi.encode(_lt));

        require(_loans[hash] == LoanStatus.NONE, "Loan has already been executed");
        require(_offerCheckAuth(hash, _lt.from, _lt.tokenId, _sig), "Signature not valid for this caller or loan.");

        _performLoan(_lt, hash);

        emit Loan(_lt.from, msg.sender, _lt.tokenId);
    }

    /* function to take a loan that has been registered via call (from a contract) */

    function takeRegisteredLoan(LoanTerms calldata _lt) LoanSanityCheck(_lt) LoanTargetCheck(_lt.to) public {

        bytes32 hash = keccak256(abi.encode(_lt));

        require(_loans[hash] == LoanStatus.PENDING, "Offer does not exist.");

        _performLoan(_lt, hash);

        emit Loan(_lt.from, msg.sender, _lt.tokenId);
    }

    /* function for smart contracts to lend tokens they own since they are unable to create signatures */

    function registerLoanOffer(LoanTerms calldata _lt) LoanSanityCheck(_lt) public  {

        require(_checkApproved(_lt.from, msg.sender, _lt.tokenId), "Not authorized to create this loan offer.");

        bytes32 hash = keccak256(abi.encode(_lt));

        require(_loans[hash] == LoanStatus.NONE, "Offer exists already");

        _loans[hash] = LoanStatus.PENDING;
    }

    /* function for lender to manually take back NFT */

    function closeLoan(LoanTerms calldata _lt) public {
        bytes32 hash = keccak256(abi.encode(_lt));

        require(_loans[hash] == LoanStatus.ACTIVE, "Loan does not exist.");
        require(_lt.loanExpiry <= block.timestamp);

        _loans[hash] = LoanStatus.CLOSED;
        _transfer(_lt.to, _lt.from, _lt.tokenId);

        _loanedTokens[_lt.tokenId] = address(0);
    }

    /* function that allows anyone to return a lender's outstanding NFT for a fee reward */

    function closeLoanIncentivized(LoanTerms calldata _lt) public {
        bytes32 hash = keccak256(abi.encode(_lt));

        require(_loans[hash] == LoanStatus.ACTIVE, "Loan does not exist.");
        require(_lt.loanExpiry <= block.timestamp);

        _loans[hash] = LoanStatus.CLOSED;
        _transfer(_lt.to, _lt.from, _lt.tokenId);

        _loanedTokens[_lt.tokenId] = address(0);

        _lt.premiumToken.safeTransferFrom(_lt.from, msg.sender, _lt.closeFeeReward);
    }


    /* allows lender and borrower to renegotiate loan close */

    function closeLoanEarly(LoanTerms calldata _lt, uint256 refund, bytes memory _lenderSig, bytes memory _borrowerSig) public {
        bytes32 hash = keccak256(abi.encode(_lt));

        require(_loans[hash] == LoanStatus.ACTIVE, "Loan does not exist.");

        bytes32 ethMessageHash = keccak256(abi.encode(hash, refund)).toEthSignedMessageHash();

        require(ethMessageHash.recover(_lenderSig) == _lt.from, "Lender signature invalid");
        require(ethMessageHash.recover(_borrowerSig) == _lt.to, "Borrower signature invlalid");


        _loans[hash] = LoanStatus.CLOSED;
        _transfer(_lt.to, _lt.from, _lt.tokenId);

        _loanedTokens[_lt.tokenId] = address(0);

        _lt.premiumToken.safeTransferFrom(_lt.from, _lt.to, refund);
    }

    /* explicitly cancel a loan that hasn't timed out yet */

    function cancelLoan(LoanTerms calldata _lt) public {

        bytes32 hash = keccak256(abi.encode(_lt));

        require(_loans[hash] == LoanStatus.NONE || _loans[hash] == LoanStatus.PENDING, "Loan has already been executed");
        require(_checkApproved(_lt.from, msg.sender, _lt.tokenId), "Not authorized to cancel this loan offer.");

        _loans[hash] = LoanStatus.CANCELLED;
    }


    /* --- internal --- */

    function _performLoan(LoanTerms calldata _lt, bytes32 _hash) internal { 

        /* update tracking maps to null out reentrancy issues */
        _loans[_hash] = LoanStatus.ACTIVE;
        _transfer(_lt.from, msg.sender, _lt.tokenId);
        _loanedTokens[_lt.tokenId] = msg.sender;

        _lt.premiumToken.safeTransferFrom(msg.sender, _lt.from, _lt.premiumAmount);
    }

    function _offerCheckAuth(bytes32 _hash, address _account, uint256 _tokenId, bytes memory _sig) view internal returns (bool) {
        address signer = _hash.toEthSignedMessageHash().recover(_sig);

        return _checkApproved(_account, signer, _tokenId);
    }

    function _checkApproved(address _owner, address _operator, uint256 _tokenId) internal view returns (bool) {
        return (_operator == _owner || loanApprovals[_owner][_operator] == _tokenId);
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal virtual override {
        super._beforeTokenTransfer(from, to, tokenId);

        require(_loanedTokens[tokenId] == address(0), "Loaned tokens cannot be transferred");
    }
}
