pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


contract PayToken is ERC20 {

    constructor() ERC20("PayToken", "PTKN") {
        _mint(msg.sender, 1000000000 ether);
    }

}
