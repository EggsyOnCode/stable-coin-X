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

import {XStableCoin} from "./XStableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
/*
 * @title XEngine
 * @author Patrick Collins
 *
 * The system is designed to be as minimal as possible, and have the tokens maintain a 1 token == $1 peg at all times.
 * This is a stablecoin with the properties:
 * - Exogenously Collateralized
 * - Dollar Pegged
 * - Algorithmically Stable
 *
 * It is similar to DAI if DAI had no governance, no fees, and was backed by only WETH and WBTC.
 *
 * Our X system should always be "overcollateralized". At no point, should the value of
 * all collateral < the $ backed value of all the X.
 *
 * @notice This contract is the core of the Decentralized Stablecoin system. It handles all the logic
 * for minting and redeeming X, as well as depositing and withdrawing collateral.
 * @notice This contract is based on the MakerDAO DSS system
 */

contract XEngine is ReentrancyGuard {
    ///////
    //Erros///
    ///////
    error XEngine_MoreThanZero();
    error XEngine_MismatchedLengthPriceFeedsAndTokenAddresses();
    error XEngine_UnallowedToken();
    error XEngine_TransferFailed();
    ///////
    //StateVars///
    ///////

    mapping(address token => address priceFeeds) private s_priceFeeds;
    XStableCoin immutable i_XStableCoin;
    mapping(address user => mapping(address token => uint256 amt)) public s_collateralDeposited;

    ///////
    //Events//
    ///////
    event CollateralDepsited(address indexed user, address indexed jtoken, uint256 indexed amt);

    
    ///////
    //Modifiers///
    ///////

    modifier moreThanZero(uint256 amt) {
        if (amt <= 0) {
            revert XEngine_MoreThanZero();
        }
        _;
    }

    modifier isAllowedToken(address token) {
        if (s_priceFeeds[token] == address(0)) {
            revert XEngine_UnallowedToken();
        }
        _;
    }

    ///////
    //Functions///
    ///////
    constructor(address[] memory tokenAddresses, address[] memory priceFeeds, address XToken) {
        // usd price Feeds only
        if (tokenAddresses.length != priceFeeds.length) {
            revert XEngine_MismatchedLengthPriceFeedsAndTokenAddresses();
        }
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            s_priceFeeds[tokenAddresses[i]] = priceFeeds[i];
        }
        i_XStableCoin = XStableCoin(XToken);
    }

    ///////
    //External func///
    ///////
    function depostiCollateralAndMintX() external {}

    /// @notice follows CEI pattern(modiifers are checks, then effectsm then interction with other contracts at the end)
    /// @param tokenCollateralAddress The ERC20 contract address of the token to be deposited as collateral like ETH
    /// @param collateralAmt The amount of collateral to be deposited
    function depositCollateral(address tokenCollateralAddress, uint256 collateralAmt)
        external
        moreThanZero(collateralAmt)
        isAllowedToken(tokenCollateralAddress)
        nonReentrant
    {
        //register the collateral deposited
        s_collateralDeposited[msg.sender][tokenCollateralAddress] += collateralAmt;

        emit CollateralDepsited(msg.sender, tokenCollateralAddress, collateralAmt);

        //interface for the ERC20 token used as adapter over the tokenCollateralAddress to invoke ERC20 specific func over it
        bool suc = IERC20(tokenCollateralAddress).transferFrom(msg.sender, address(this), collateralAmt);
        if (!suc){
            revert XEngine_TransferFailed();
        }
    }

    function redeemCollateral() external {}

    function redeemCollateralForX() external {}

    function burnX() external {}

    function mintX() external {}

    function liquidate() external {}

    // to calculate the how far an asset is from getting  under collateralized
    function getHealthFactor() external {}
}
