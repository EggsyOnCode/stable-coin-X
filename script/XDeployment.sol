// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {XStableCoin} from "../src/XStableCoin.sol";
import {XEngine} from "../src/XEngine.sol";

contract XDeployment is Script {
    address[] public priceFeeds;
    address[] public tokenAddresses;
    uint256 public d;

    function run() external returns (XEngine, XStableCoin, HelperConfig helperConfig) {
        helperConfig = new HelperConfig();
        (uint256 deployerKey, address wEthPriceFeed, address wBtcPriceFeed, address wEth, address wBtc) =
            helperConfig.activeNetworkConfig();
        priceFeeds = [wEthPriceFeed, wBtcPriceFeed];
        tokenAddresses = [wEth, wBtc];
        d = deployerKey;

        vm.startBroadcast();
        XStableCoin xStableCoin = new XStableCoin();
        XEngine xEngine = new XEngine(tokenAddresses, priceFeeds, address(xStableCoin));
        xStableCoin.transferOwnership(address(xEngine));
        vm.stopBroadcast();
        return (xEngine, xStableCoin, helperConfig);
    }
}
