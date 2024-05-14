// SPDX-License-Identifier: MIT

// This is considered an Exogenous, Decentralized, Anchored (pegged), Crypto Collateralized low volitility coin

// Layout of Contract:
// version
// imports
// interfaces, libraries, contracts
// errors
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

pragma solidity ^0.8.18;

/// @title XStableCoin
/// @author EggsyOnCode
/// @notice  A stablecoin that is pegged to the value of the US dollar
/// @dev Collateral: Exogenous (Crypto), Minting: Decentralized (Algortihmic), Anchored (pegged)

// This is the contract meant to be owned by XEngine. It is a ERC20 token that can be minted and burned by the XEngine smart contract.

import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract XStableCoin is ERC20, ERC20Burnable, Ownable {
    error XStableCoin_BurnBalanceLessThanAmt();
    error XStableCoin_NegativeAmt();
    error XStableCoin_MintToZeroAddress();

    constructor() ERC20("XStableCoin", "XSC") Ownable(msg.sender) {}

    //External Functions
    function mint(address to, uint256 amount) external onlyOwner {
        if (to == address(0)) {
            revert XStableCoin_MintToZeroAddress();
        }
        if (amount < 0) {
            revert XStableCoin_NegativeAmt();
        }
        _mint(to, amount);
    }

    // Public Functions
    function burn(uint256 amount) public override onlyOwner {
        uint256 balance = balanceOf(msg.sender);
        if (amount < 0) {
            revert XStableCoin_NegativeAmt();
        }

        if (balance < amount) {
            revert XStableCoin_BurnBalanceLessThanAmt();
        }
        //overirding the burn function from ERC20Burnable
        super.burn(amount);
    }
}
