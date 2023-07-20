// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {DynametricNoFees, Dynametric} from "../src/DynametricNoFees.sol";

contract DeployDynametric is Script {
    function run() public returns(Dynametric, DynametricNoFees) {
        vm.startBroadcast();
        Dynametric dynametric = new Dynametric();
        DynametricNoFees dnf = new DynametricNoFees();
        vm.stopBroadcast();

        return (dynametric, dnf);
    }
}
