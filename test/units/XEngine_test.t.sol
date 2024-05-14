// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {XStableCoin} from "../../src/XStableCoin.sol";
import {XEngine} from "../../src/XEngine.sol";
import {XDeployment} from "../../script/XDeployment.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";

contract XEngineTest is Test {
    XEngine public engine;
    XStableCoin public stableCoin;
    HelperConfig public helperConfig;
    address public wethPriceFeed;
    address public weth;

    address public USER = makeAddr("user");
    uint256 public INITBALANCE = 100 ether;

    function setUp() external {
        (engine, stableCoin, helperConfig) = new XDeployment().run();
        (, wethPriceFeed,, weth,) = helperConfig.activeNetworkConfig();
    }

    //////////// Price Feed Tests ////////////

    function testDepositComplete() public {
        //setUp
        uint256 amount = 15e18; // 15 ethers in wei
        // 15e18 * 2000/ether = 30000e18
        //execution
        uint256 expectedUsdPrice = 30000e18;
        uint256 actualUsd = engine._getUsdPrice(weth, amount);
        //assert
        assertEq(actualUsd, expectedUsdPrice);
    }

    //// depositCollateral Tests ////

    function testRevertDepsitDueToZeroCollateral() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), INITBALANCE);
        vm.expectRevert(XEngine.XEngine_MoreThanZero.selector);
        engine.depositCollateral(weth, 0);
        vm.stopPrank();
    }
}
