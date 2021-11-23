//SPDX-License-Identifier: GPLv3

pragma solidity ^0.8.4;

import "./ERC721Loanable.sol";

contract LoanNFT is ERC721Loanable, Ownable {

    uint public totalSupply = 0;

    constructor(string memory name, string memory symbol) ERC721Loanable(name, symbol) {}

    /* --- admin --- */

    function mint() public onlyOwner returns (uint)  {

        totalSupply += 1;

        _mint(msg.sender, totalSupply);
        
        return totalSupply;
    }
}
