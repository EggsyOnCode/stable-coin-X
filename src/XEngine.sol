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
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
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
    error XEngine_MintFailed();
    error XEngine_BreaksHealthFactor();
    ///////
    //StateVars///
    ///////

    mapping(address token => address priceFeeds) private s_priceFeeds;
    XStableCoin immutable i_XStableCoin;
    mapping(address user => mapping(address token => uint256 amt)) public s_collateralDeposited;
    mapping(address user => uint256 tokenAmt) public s_XMinted;
    //array of the address of all tokens like address of ETH, BTC, etc
    address[] private s_collateralTokens;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant LIQUIDATION_THRESHOLD = 50; //200% overcollateralized
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant MIN_HEALTH_FACTOR = 1;

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
            s_collateralTokens.push(tokenAddresses[i]);
        }
        i_XStableCoin = XStableCoin(XToken);
    }

    ///////
    //External func///
    ///////

    /// @notice follows CEI pattern(modiifers are checks, then effectsm then interction with other contracts at the end)
    /// @param tokenCollateralAddress The ERC20 contract address of the token to be deposited as collateral like ETH
    /// @param collateralAmt The amount of collateral to be deposited
    function depositCollateral(address tokenCollateralAddress, uint256 collateralAmt)
        public
        moreThanZero(collateralAmt)
        isAllowedToken(tokenCollateralAddress)
        nonReentrant
    {
        //register the collateral deposited
        s_collateralDeposited[msg.sender][tokenCollateralAddress] += collateralAmt;

        emit CollateralDepsited(msg.sender, tokenCollateralAddress, collateralAmt);

        //interface for the ERC20 token used as adapter over the tokenCollateralAddress to invoke ERC20 specific func over it
        bool suc = IERC20(tokenCollateralAddress).transferFrom(msg.sender, address(this), collateralAmt);
        if (!suc) {
            revert XEngine_TransferFailed();
        }
    }

    function depostiCollateralAndMintX(address tokenCollateralAddress, uint256 collateralAmt, uint256 amtMnt)
        external
    {
        depositCollateral(tokenCollateralAddress, collateralAmt);
        mintX(amtMnt);
    }

    /// @notice Redeems the collateral deposited by the user
    function redeemCollateral(address tokenCollateralAddress, uint256 collateralAmt)
        public
        nonReentrant
        moreThanZero(collateralAmt)
    {
        s_collateralDeposited[msg.sender][tokenCollateralAddress] -= collateralAmt;
        emit CollateralDepsited(msg.sender, tokenCollateralAddress, collateralAmt);
        bool success = IERC20(tokenCollateralAddress).transfer(msg.sender, collateralAmt);
        if (!success) {
            revert XEngine_TransferFailed();
        }
        //  check if health factor is  not broken
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    // 100 $ ETH --> depsited as collateral
    // 20 $ X minted
    // FOR redeeming now; you must 1. burn 20 X 2. redeem 100$ ETH cuz we can never be undercollateralized at any time

    /// @param tokenAmt: amount of X to be burnt
    /// @param tokenCollateralAddress: address of the token in which collateral is deposited (ERC20 token)
    /// @param collateralAmt: amt of collateral to be redeemed
    function redeemCollateralForX(address tokenCollateralAddress, uint256 collateralAmt, uint256 tokenAmt)
        external
        nonReentrant
    {
        burnX(tokenAmt);
        redeemCollateral(tokenCollateralAddress, collateralAmt);
    }

    function burnX(uint256 amt) public moreThanZero(amt) {
        s_XMinted[msg.sender] -= amt;
        // transfering ownership to Engine ; promotng Single Resp Func
        // Engine should be resp for maanging the funds and not the ERC20 contract
        // IMP design pricniple
        bool success = i_XStableCoin.transferFrom(msg.sender, address(this), amt);
        if (!success) {
            revert XEngine_TransferFailed();
        }
        // burn the X
        i_XStableCoin.burn(amt);
        // check if the user is undercollateralized
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    function mintX(uint256 amtX) public nonReentrant {
        s_XMinted[msg.sender] += amtX;

        // check if the user minted too much (150X for 100$)
        _revertIfHealthFactorIsBroken(msg.sender);
        //if the mint fails the tx would be revereted by teh mint function
        i_XStableCoin.mint(msg.sender, amtX);
    }

    /////////////////////PUBLIC and EXTERNAL VIEW FUNCTIONS////////////////////////
    function _getUsdPrice(address token, uint256 amt) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price,,,) = priceFeed.latestRoundData();
        // say 1 eth = 1000usd
        // value returned will be 1000 * 1e8
        return ((uint256(price) * ADDITIONAL_FEED_PRECISION) * amt) / PRECISION; // (1000 * 1e8) * (1000 usd amt * 1e18 wei)
    }

    function getCollateralDeposited(address user) public view returns (uint256 totalCollateral) {
        // return the total collateral deposited by the user in USD
        for (uint256 i = 0; i < s_collateralTokens.length; i++) {
            uint256 amtDeposited = s_collateralDeposited[user][s_collateralTokens[i]];
            totalCollateral += amtDeposited * _getUsdPrice(s_collateralTokens[i], amtDeposited);
        }
    }

    //////////////INTERNAL FUNCTIONS////////////////////

    /// @notice returns how close to liquidation a user is
    /// if the health factor is less than 1, the user is undercollateralized hence liquidated
    /// @param user user address
    function _healthFactor(address user) internal returns (uint256) {
        // calcaulte total X minted by the user
        // calculate total collateral deposited by the user
        (uint256 totalCollateral, uint256 totalX) = _getUserAccountInfo(user);
        uint256 collateralAjustedForThreshold = (totalCollateral * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        return (collateralAjustedForThreshold * PRECISION) / totalX;
    }

    function _revertIfHealthFactorIsBroken(address user) internal {
        // check the heath factor of the user
        // liquidate if below 1
        uint256 userHealthFactor = _healthFactor(user);
        if (userHealthFactor < MIN_HEALTH_FACTOR) {
            // liquidate the user
            revert XEngine_BreaksHealthFactor();
        }
    }

    function _liquidate(address user) internal {}

    function _getUserAccountInfo(address user) internal view returns (uint256, uint256) {
        uint256 totalMinted = s_XMinted[user];
        uint256 totalCollateral = getCollateralDeposited(user);
        return (totalMinted, totalCollateral);
    }
}
