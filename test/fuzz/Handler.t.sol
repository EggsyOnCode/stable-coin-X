// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

// invariants are
// 1- the total supply should be less than hte collateral (weth + wbtc balances)
// 2- all getters should not be reverting

import {Test} from "forge-std/Test.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {XStableCoin} from "../../src/XStableCoin.sol";
import {XEngine} from "../../src/XEngine.sol";
import {XDeployment} from "../../script/XDeployment.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";

// open testing -- randomly call all the public functions with random params and order
contract Handler is Test {
    XEngine public engine;
    XStableCoin public stableCoin;
    HelperConfig public helperConfig;
    address public wethPriceFeed;
    address public bethPriceFeed;
    address public weth;
    address public wbtc;

    // Ghost Variables
    uint96 public constant MAX_DEPOSIT_SIZE = type(uint96).max;

    constructor(XEngine _engine, XStableCoin _coin) {
        engine = _engine;
        stableCoin = _coin;
    }

    function depositCollateral(uint256 collateralSeed, uint256 amountCollateral) external {
        // bouding the collateral between possible constraints
        amountCollateral = bound(amountCollateral, 1, MAX_DEPOSIT_SIZE);
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);

        vm.startPrank(msg.sender);
        collateral.mint(msg.sender, amountCollateral);
        collateral.approve(address(engine), amountCollateral);
        engine.depositCollateral(address(collateral), amountCollateral);
        vm.stopPrank();
    }

    function _getCollateralFromSeed(uint256 collateralSeed) private view returns (ERC20Mock) {
        if (collateralSeed % 2 == 0) {
            return ERC20Mock(weth);
        } else {
            return ERC20Mock(wbtc);
        }
    }
}
