// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {XStableCoin} from "../../src/XStableCoin.sol";
import {XEngine} from "../../src/XEngine.sol";
import {XDeployment} from "../../script/XDeployment.sol";

contract XEngineTest is Test {
    XEngine public engine;
    XStableCoin public stableCoin;
    HelperConfig public helperConfig;
    address public wethPriceFeed;
    address public weth;

    function setUp() external {
        (engine, stableCoin, helperConfig) = new XDeployment().run();
        (, wethPriceFeed,, weth,) = helperConfig.activeNetworkConfig();
    }

    //////////// Price Feed Tests ////////////

    function testDepositComplete() public {
        //setUp
        uint256 amount = 15e18; // 15 ethers in wei
        // 15e18 * 2000/ether = 3000e18
        //execution
        uint256 expectedUsdPrice = 30000e18;
        uint256 actualUsd = engine._getUsdPrice(weth, amount);
        //assert
        assertEq(actualUsd, expectedUsdPrice);
    }
}
