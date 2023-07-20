// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Dynametric} from "./Dynametric.sol";

contract DynametricNoFees is Dynametric {
    function getFee(
        uint256 highPrice,
        uint256 lowPrice
    ) internal pure override returns (uint256) {
        return 0;
    }
}
