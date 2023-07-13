// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import {Dynametric} from "../src/Dynametric.sol";
import {DeployDynametric} from "../script/Dynametric.s.sol";

contract TestDynametric is Test {
    Dynametric public dynametric;

    function setUp() public {
        DeployDynametric deployer = new DeployDynametric();
        dynametric = deployer.run();
    }

    // Swap on pool that does not exist
    // Create pool with same token
    // Create pool but less tokens than minimum liquidity
    // Create pool - happy path
    // Create pool with two non tokens (or even one)
    // Create pool already created
    // Swap on pool - happy path
    // Swap on pool - happy path but reverse
    // Swap on pool but exceed slippage
}
