// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from "openzeppelin/token/ERC20/ERC20.sol";
import {ReentrancyGuard} from "openzeppelin/security/ReentrancyGuard.sol";

contract Dynametric is ReentrancyGuard {
    /**
     * Constants
     */
    uint256 constant MINIMUM_LIQUIDITY = 10**3;
    
    /**
     * Errors
     */
    error Dynametric__CannotCreatePoolWithSameToken(address token);
    error Dynametric__PoolAlreadyExists(address token0, address token1);
    error Dynametric__PoolDoesNotExist(address token0, address token1);
    error Dynametric__AmountIsZero();
    error Dynametric__ExceededMaxSlippage(
        address tokenIn,
        uint256 amountIn,
        address tokenOut,
        uint256 amountOut,
        uint256 minAmountOut
    );
    error Dynametric__SwapFailed(
        address token0,
        address token1,
        uint256 oldAmount0,
        uint256 oldAmount1,
        uint256 newAmount0,
        uint256 newAmount1
    );

    /**
     * Type Declarations
     */
    struct Pool {
        address token0;
        address token1;
        uint256 amount0;
        uint256 amount1;
        uint256 numLPtokens;
    }

    /**
     * State Variables
     */
    mapping(address token0 => mapping(address token1 => Pool)) s_pools;
    mapping(address token0 => mapping(address token1 => mapping(address user => uint256 numLPtokens))) lpBalances;

    /**
     * Events
     */
    event Swap(
        address indexed sender,
        address indexed tokenIn,
        uint256 amountIn,
        address indexed tokenOut,
        uint256 amountOut
    );

    /**
     * Functions
     */
    function createPool(
        address token0,
        uint256 amount0,
        address token1,
        uint256 amount1
    ) external nonReentrant {
        // Checks
        if (amount0 == 0 || amount1 == 0) revert Dynametric__AmountIsZero();
        if (token0 == token1)
            revert Dynametric__CannotCreatePoolWithSameToken(token0);
        if (!tokensInOrder(token0, token1)) {
            (token0, token1) = swap(token0, token1);
            (amount0, amount1) = swap(amount0, amount1);
        }
        if (s_pools[token0][token1].token0 != address(0))
            revert Dynametric__PoolAlreadyExists(token0, token1);

        // Effects
        uint256 numLPtokens = (amount0 * amount1);
        uint256 userLPtokens = numLPtokens - MINIMUM_LIQUIDITY;
        s_pools[token0][token1] = Pool({
            token0: token0,
            token1: token1,
            amount0: amount0,
            amount1: amount1,
            numLPtokens: numLPtokens
        });
        lpBalances[token0][token1][msg.sender] = userLPtokens;

        // Interactions - N/A
        // Invariant - N/A
    }

    function swapExactInputForOutput(
        address tokenIn,
        uint256 amountIn,
        address tokenOut,
        uint256 minAmountOut
    ) external nonReentrant {
        // Checks
        if (amountIn == 0) revert Dynametric__AmountIsZero();

        address token0;
        address token1;
        uint256 amount0;
        uint256 amount1;

        if (tokensInOrder(tokenIn, tokenOut)) {
            token0 = tokenIn;
            token1 = tokenOut;
            amount0 = amountIn;
        } else {
            token0 = tokenOut;
            token1 = tokenIn;
            amount1 = amountIn;
        }

        Pool memory pool = s_pools[token0][token1];
        if (pool.token0 == address(0))
            revert Dynametric__PoolDoesNotExist(token0, token1);

        // Effects
        uint256 k = pool.amount0 * pool.amount1;
        uint256 newAmount0;
        uint256 newAmount1;
        uint256 amountOut;

        if (amount0 == 0) {
            newAmount1 = pool.amount1 + amount1;
            newAmount0 = k / pool.amount1;
            amountOut = pool.amount0 - newAmount0;
        } else {
            newAmount0 = pool.amount0 + amount0;
            newAmount1 = k / pool.amount1;
            amountOut = pool.amount1 - newAmount1;
        }

        if (amountOut < minAmountOut)
            revert Dynametric__ExceededMaxSlippage(
                tokenIn,
                amountIn,
                tokenOut,
                amountOut,
                minAmountOut
            );

        s_pools[token0][token1].amount0 = newAmount0;
        s_pools[token0][token1].amount1 = newAmount1;
        emit Swap(msg.sender, tokenIn, amountIn, tokenOut, amountOut);

        // Interactions
        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
        IERC20(tokenOut).transfer(msg.sender, amountOut);

        // Invariants
        if (newAmount0 * newAmount1 < k)
            revert Dynametric__SwapFailed(
                token0,
                token1,
                pool.amount0,
                pool.amount1,
                newAmount0,
                newAmount1
            );
    }

    /**
     * View/Pure Functions
     */
    function tokensInOrder(
        address token0,
        address token1
    ) private pure returns (bool) {
        return uint160(token0) < uint160(token1);
    }

    function swap(
        address address1,
        address address2
    ) private pure returns (address, address) {
        address temp = address1;
        address1 = address2;
        address2 = temp;
        return (address1, address2);
    }

    function swap(
        uint256 a,
        uint256 b
    ) private pure returns (uint256, uint256) {
        uint256 temp = a;
        a = b;
        b = temp;
        return (a, b);
    }
}
