// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

// invariants are
// 1- the total supply should be less than hte collateral (weth + wbtc balances)
// 2- all getters should not be reverting

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {XStableCoin} from "../../src/XStableCoin.sol";
import {XEngine} from "../../src/XEngine.sol";
import {XDeployment} from "../../script/XDeployment.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";
import {Handler} from "./Handler.t.sol";

// open testing -- randomly call all the public functions with random params and order
contract OpenInvarint is StdInvariant, Test {
    XEngine public engine;
    XStableCoin public stableCoin;
    HelperConfig public helperConfig;
    Handler public handler;
    address public wethPriceFeed;
    address public bethPriceFeed;
    address public weth;
    address public wbtc;

    // constants
    address public USER = address(0x1);
    uint256 public INIT_BALANCE = 1000 ether;
    uint256 public INIT_COLLATERAL = 10 ether;

    function setUp() external {
        (engine, stableCoin, helperConfig) = new XDeployment().run();
        (, wethPriceFeed,, weth, wbtc) = helperConfig.activeNetworkConfig();
        handler = new Handler(engine, stableCoin);
        targetContract(address(handler));
    }

    function invariant_totalSupplyShouldBeLessThanCollateral() external {
        // assertEq(stableCoin.totalSupply(), 0);

        // vm.startPrank(USER);
        // vm.deal(USER, INIT_BALANCE);
        // assertEq(USER.balance, INIT_BALANCE);
        // ERC20Mock(weth).mint(USER, INIT_BALANCE);
        // ERC20Mock(weth).approve(address(engine), INIT_COLLATERAL);
        // engine.depositCollateral(weth, INIT_COLLATERAL);
        uint256 totalSupply = stableCoin.totalSupply();
        uint256 wethBalance = ERC20Mock(weth).balanceOf(address(engine));
        uint256 wbtcBalance = ERC20Mock(weth).balanceOf(address(engine));

        uint256 wethamt = engine._getUsdPrice(weth, wethBalance);
        uint256 wbtcamt = engine._getUsdPrice(wbtc, wbtcBalance);

        assert(totalSupply <= wethamt + wbtcamt);
    }
}
