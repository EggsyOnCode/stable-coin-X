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
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
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
    mapping(address user => uint256 tokenAmt) public s_XMinted;
    //array of the address of all tokens like address of ETH, BTC, etc
    address[] private s_collateralTokens;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;

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
        if (!suc) {
            revert XEngine_TransferFailed();
        }
    }

    function redeemCollateral() external {}

    function redeemCollateralForX() external {}

    function burnX() external {}

    function mintX(uint256 amtX) external nonReentrant {
        s_XMinted[msg.sender] += amtX;

        // check if the user minted too much (150X for 100$)
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    function liquidate() external {}

    //////////////INTERNAL FUNCTIONS////////////////////

    /// @notice returns how close to liquidation a user is
    /// if the health factor is less than 1, the user is undercollateralized hence liquidated
    /// @param user user address
    function _healthFactor(address user) internal view {
        // calcaulte total X minted by the user
        // calculate total collateral deposited by the user
        (uint256 totalCollateral, uint256 totalX) = _getUserAccountInfo(user);
        // how to do SafeMath?
        if (totalX / totalCollateral < 1) {
            // liquidate
        }
    }

    /// @dev
    /// @param Documents a parameter just like in doxygen (must be followed by parameter name)
    /// @return Documents the return variables of a contract’s function state variable
    /// @inheritdoc	Copies all missing tags from the base function (must be followed by the contract name)
    function _revertIfHealthFactorIsBroken(address user) internal view {
        // check the heath factor of the user
        // liquidate if below 1
    }

    function _getUserAccountInfo(address user) internal view returns (uint256 totalCollateral, uint256 totalX) {
        uint256 totalMinted = s_XMinted[user];
        uint256 totalCollateral = getCollateralDeposited(user);
        return (totalMinted, totalCollateral);
    }

    function _getUsdPrice(address token, uint256 amt) internal view returns (uint256) {
        AggreagtorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price,,,) = priceFeed.latestRoundData();
        // say 1 eth = 1000usd
        // value returned will be 1000 * 1e8
        return ((uint256(price) * ADDITIONAL_FEED_PRECISION) * amt) / PRECISION; // (1000 * 1e8) * (1000 usd amt * 1e18 wei)
    }

    /////////////////////PUBLIC and EXTERNAL VIEW FUNCTIONS////////////////////////

    function getCollateralDeposited(address user) external view returns (uint256 totalCollateral) {
        // return the total collateral deposited by the user in USD
        for (uint256 i = 0; i < s_collateralTokens.length; i++) {
            uint256 amtDeposited = s_collateralDeposited[user][s_collateralTokens[i]];
            totalCollateral += amtDeposited * _getUsdPrice(s_collateralTokens[i], amtDeposited);
        }
    }
}
