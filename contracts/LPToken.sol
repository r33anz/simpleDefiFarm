// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import  {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract LPToken is ERC20, Ownable {
    constructor(address initialOwner) ERC20("LPToken", "LPT") Ownable(initialOwner) {

    }    

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
}

