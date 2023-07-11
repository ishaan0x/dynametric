// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract Dynametric {
    struct Pool {
        address token0;
        address token1;
        uint256 amount0;
        uint256 amount1;
        uint256 numLPtokens;
    }

    mapping (address token0 => mapping(address token1 => Pool)) s_pools;

    function swapExactInputForOutput(address token, uint256 amount) external {}
}
