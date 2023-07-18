// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from "openzeppelin/token/ERC20/ERC20.sol";
import {ReentrancyGuard} from "openzeppelin/security/ReentrancyGuard.sol";

contract Dynametric is ReentrancyGuard {
    /**
     * Constants
     */
    uint256 private constant MINIMUM_LIQUIDITY = 1e3;
    uint256 private constant PRECISION = 1e4;
    uint256 private constant PRICE_FLOATING = 1e9;
    uint256 private constant LOW_VOLATILITY_BARRIER = 0.02e9;
    uint256 private constant HIGH_VOLATILITY_BARRIER = 0.05e9;
    uint256 private constant MIN_VOLATILITY = 30;
    uint256 private constant MAX_VOLATILITY = 100;
    uint256 private constant VOLATILITY_UPDATE_WAIT = 10 * 60; // 10 minutes

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
        uint256 causeOfError
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
        uint256 highPrice;
        uint256 lowPrice;
        uint256 volatilityIndex;
        uint256 lastUpdate;
    }

    /**
     * State Variables
     */
    mapping(address token0 => mapping(address token1 => Pool)) private s_pools;
    mapping(address token0 => mapping(address token1 => mapping(address user => uint256 numLPtokens)))
        private s_lpBalances;

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
        uint256 _currentPrice = currentRatio(amount0, amount1);
        s_pools[token0][token1] = Pool({
            token0: token0,
            token1: token1,
            amount0: amount0,
            amount1: amount1,
            numLPtokens: numLPtokens,
            highPrice: _currentPrice,
            lowPrice: _currentPrice,
            volatilityIndex: 0,
            lastUpdate: block.timestamp
        });
        s_lpBalances[token0][token1][msg.sender] = userLPtokens;

        // Interactions
        IERC20(token0).transferFrom(msg.sender, address(this), amount0);
        IERC20(token1).transferFrom(msg.sender, address(this), amount1);

        // Invariant - N/A
    }

    function swapExactInputForOutput(
        address tokenIn,
        uint256 amountIn,
        address tokenOut,
        uint256 minAmountOut
    ) external nonReentrant {
        require(amountIn > 0, "Amount is zero");

        (address token0, address token1, bool _tokensInOrder) = _getTokensOrder(
            tokenIn,
            tokenOut
        );

        Pool memory pool = _getPool(token0, token1);
        (
            uint256 newAmount0,
            uint256 newAmount1,
            uint256 amountOut
        ) = _getNewAmounts(pool, amountIn, _tokensInOrder);

        require(amountOut >= minAmountOut, "Exceeded max slippage");

        _updatePool(token0, token1, newAmount0, newAmount1);
        _transferTokens(tokenIn, tokenOut, amountIn, amountOut);

        require(
            newAmount0 * newAmount1 >= pool.amount0 * pool.amount1,
            "Swap failed"
        );
    }

    function swapInputForExactOutput(
        address tokenIn,
        uint256 maxAmountIn,
        address tokenOut,
        uint256 amountOut
    ) external nonReentrant {
        require(amountOut > 0, "Amount is zero");

        (address token0, address token1, bool _tokensInOrder) = _getTokensOrder(
            tokenIn,
            tokenOut
        );

        Pool memory pool = _getPool(token0, token1);
        (
            uint256 newAmount0,
            uint256 newAmount1,
            uint256 amountIn
        ) = _getNewAmounts(pool, amountOut, !_tokensInOrder);

        require(amountIn <= maxAmountIn, "Exceeded max slippage");

        _updatePool(token0, token1, newAmount0, newAmount1);
        _transferTokens(tokenIn, tokenOut, amountIn, amountOut);

        require(
            newAmount0 * newAmount1 >= pool.amount0 * pool.amount1,
            "Swap failed"
        );
    }

    function _getNewAmounts(
        Pool memory pool,
        uint256 amount,
        bool _tokensInOrder
    )
        internal
        pure
        returns (uint256 newAmount0, uint256 newAmount1, uint256 amountOut)
    {
        uint256 k = pool.amount0 * pool.amount1;
        if (_tokensInOrder) {
            newAmount1 = pool.amount1 + amount;
            newAmount0 = k / newAmount1;
            amountOut =
                ((pool.amount0 - newAmount0) *
                    (PRECISION - getFee(pool.highPrice, pool.lowPrice))) /
                PRECISION;
        } else {
            newAmount0 = pool.amount0 + amount;
            newAmount1 = k / newAmount0;
            amountOut =
                ((pool.amount1 - newAmount1) *
                    (PRECISION - getFee(pool.highPrice, pool.lowPrice))) /
                PRECISION;
        }
    }

    function _updatePool(
        address token0,
        address token1,
        uint256 newAmount0,
        uint256 newAmount1
    ) internal {
        Pool storage pool = s_pools[token0][token1];
        pool.amount0 = newAmount0;
        pool.amount1 = newAmount1;

        uint256 newPrice = currentRatio(newAmount0, newAmount1);
        if (block.timestamp >= pool.lastUpdate + VOLATILITY_UPDATE_WAIT) {
            pool.lastUpdate = block.timestamp;
            pool.highPrice = newPrice;
            pool.lowPrice = newPrice;
        } else if (newPrice > pool.highPrice) {
            pool.highPrice = newPrice;
        } else if (newPrice < pool.lowPrice) {
            pool.lowPrice = newPrice;
        }
    }

    function _transferTokens(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut
    ) internal {
        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
        IERC20(tokenOut).transfer(msg.sender, amountOut);
    }

    function _getTokensOrder(
        address tokenIn,
        address tokenOut
    )
        internal
        pure
        returns (address token0, address token1, bool _tokensInOrder)
    {
        if (tokenIn < tokenOut) {
            return (tokenIn, tokenOut, true);
        } else {
            return (tokenOut, tokenIn, false);
        }
    }

    /**
     * View/Pure Functions
     */

    // Returns price of asset0 in terms of asset1
    function currentPrice(
        address token0,
        address token1
    ) private view returns (uint256) {
        if (!tokensInOrder(token0, token1))
            (token0, token1) = swap(token0, token1);

        Pool memory pool = s_pools[token0][token1];
        return currentRatio(pool.amount0, pool.amount1);
    }

    // Returns price of asset0 in terms of asset1
    function currentRatio(
        uint256 amount0,
        uint256 amount1
    ) private pure returns (uint256) {
        return ((amount1 * PRICE_FLOATING) / amount0);
    }

    function _getPool(
        address token0,
        address token1
    ) private view returns (Pool memory pool) {
        pool = s_pools[token0][token1];
        if (pool.token0 == address(0))
            revert Dynametric__PoolDoesNotExist(token0, token1);
    }

    function getFee(
        uint256 highPrice,
        uint256 lowPrice
    ) private pure returns (uint256) {
        uint256 percentVolatility = ((highPrice - lowPrice) * PRICE_FLOATING) /
            lowPrice;

        if (percentVolatility <= LOW_VOLATILITY_BARRIER) return MIN_VOLATILITY;
        if (percentVolatility >= HIGH_VOLATILITY_BARRIER) return MAX_VOLATILITY;

        return
            ((MAX_VOLATILITY - MIN_VOLATILITY) *
                (percentVolatility - LOW_VOLATILITY_BARRIER)) /
            (HIGH_VOLATILITY_BARRIER - LOW_VOLATILITY_BARRIER);
    }

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

    /**
     * Getter Functions
     */

    // Getter function for s_pools
    function getPool(
        address token0,
        address token1
    ) public view returns (Pool memory) {
        if (tokensInOrder(token0, token1)) return _getPool(token0, token1);
        else return _getPool(token1, token0);
    }

    // Getter function for s_lpBalances
    function getLPBalance(
        address token0,
        address token1,
        address user
    ) public view returns (uint256) {
        if (tokensInOrder(token0, token1))
            return s_lpBalances[token0][token1][user];
        else return s_lpBalances[token1][token0][user];
    }
}
