// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {Dynametric} from "../src/Dynametric.sol";

contract DeployDynametric is Script {
    function run() public returns(Dynametric) {
        vm.broadcast();
        Dynametric dynametric = new Dynametric();

        return dynametric;
    }
}
