// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import {DynametricNoFees, Dynametric} from "../src/DynametricNoFees.sol";
import {DeployDynametric} from "../script/Dynametric.s.sol";
import {ERC20Mock} from "openzeppelin/mocks/ERC20Mock.sol";

contract TestDynametric is Test {
    Dynametric public dynametric;
    DynametricNoFees dnf;
    ERC20Mock tokenA;
    address addressA;
    ERC20Mock tokenB;
    address addressB;

    address immutable SWAPPER = makeAddr("swapper");
    address immutable LPer = makeAddr("LPer");

    uint256 constant STARTING_BALANCE = 100 ether;
    uint256 constant SWAP_AMOUNT = 10 ether;
    uint256 constant SMALL_AMOUNT = 10;

    function setUp() public {
        DeployDynametric deployer = new DeployDynametric();
        (dynametric, dnf) = deployer.run();

        tokenA = new ERC20Mock();
        addressA = address(tokenA);
        tokenB = new ERC20Mock();
        addressB = address(tokenB);

        if (uint160(addressA) > uint160(addressB)) {
            address temp = addressA;
            addressA = addressB;
            addressB = temp;

            ERC20Mock temp2 = tokenA;
            tokenA = tokenB;
            tokenB = temp2;
        }

        tokenA.mint(SWAPPER, STARTING_BALANCE);
        tokenA.mint(LPer, STARTING_BALANCE);
        tokenB.mint(SWAPPER, STARTING_BALANCE);
        tokenB.mint(LPer, STARTING_BALANCE);
    }

    // Swap on pool that does not exist
    function test_SwapOnPoolThatDoesNotExist() public {
        vm.prank(SWAPPER);
        vm.expectRevert(
            abi.encodeWithSelector(
                Dynametric.Dynametric__PoolDoesNotExist.selector,
                addressA,
                addressB
            )
        );
        dynametric.swapExactInputForOutput(addressA, SWAP_AMOUNT, addressB, 0);
    }

    // Create pool with same token
    function test_CreatePoolWithSameToken() public {
        vm.prank(LPer);
        vm.expectRevert(
            abi.encodeWithSelector(
                Dynametric.Dynametric__CannotCreatePoolWithSameToken.selector,
                addressA
            )
        );
        dynametric.createPool(addressA, SWAP_AMOUNT, addressA, SWAP_AMOUNT);
    }

    // Create pool but less tokens than minimum liquidity
    function test_CreatePoolWithLessTokensThanMinimumLiquidity() public {
        vm.prank(LPer);
        vm.expectRevert();
        dynametric.createPool(addressA, SMALL_AMOUNT, addressB, SMALL_AMOUNT);
    }

    // Create pool - happy path
    function test_CreatePoolHappyPath() public {
        vm.startPrank(LPer);
        tokenA.increaseAllowance(address(dynametric), 2 * SWAP_AMOUNT);
        tokenB.increaseAllowance(address(dynametric), 2 * SWAP_AMOUNT);

        dynametric.createPool(addressA, SWAP_AMOUNT, addressB, SWAP_AMOUNT);

        assertEq(
            dynametric.getLPBalance(addressA, addressB, LPer),
            SWAP_AMOUNT ** 2 - 10 ** 3
        );
        assertEq(dynametric.getLPBalance(addressA, addressB, SWAPPER), 0);

        assertEq(tokenA.balanceOf(address(dynametric)), SWAP_AMOUNT);
        assertEq(tokenB.balanceOf(address(dynametric)), SWAP_AMOUNT);
    }

    // Create pool with two non tokens (or even one) - TODO
    function test_CreatePoolWithTwoNonTokens() public {}

    // Create pool already created
    function test_CreatePoolAlreadyCreated() public {
        vm.startPrank(LPer);
        tokenA.increaseAllowance(address(dynametric), 2 * SWAP_AMOUNT);
        tokenB.increaseAllowance(address(dynametric), 2 * SWAP_AMOUNT);

        dynametric.createPool(addressA, SWAP_AMOUNT, addressB, SWAP_AMOUNT);
        vm.expectRevert(
            abi.encodeWithSelector(
                Dynametric.Dynametric__PoolAlreadyExists.selector,
                addressA,
                addressB
            )
        );
        dynametric.createPool(addressA, SWAP_AMOUNT, addressB, SWAP_AMOUNT);
    }

    // Swap on pool - happy path
    function test_SwapOnPoolHappyPath() public {
        vm.startPrank(LPer);
        tokenA.increaseAllowance(address(dynametric), SWAP_AMOUNT);
        tokenB.increaseAllowance(address(dynametric), SWAP_AMOUNT);

        dynametric.createPool(addressA, SWAP_AMOUNT, addressB, SWAP_AMOUNT);
        vm.stopPrank();

        vm.startPrank(SWAPPER);
        tokenA.increaseAllowance(address(dynametric), SWAP_AMOUNT);
        dynametric.swapExactInputForOutput(
            addressA,
            SWAP_AMOUNT,
            addressB,
            SMALL_AMOUNT
        );

        assertEq(tokenA.balanceOf(SWAPPER), STARTING_BALANCE - SWAP_AMOUNT);
        assert(tokenB.balanceOf(SWAPPER) < STARTING_BALANCE + SWAP_AMOUNT / 2);

        assertEq(tokenA.balanceOf(address(dynametric)), 2 * SWAP_AMOUNT);
        assert(tokenB.balanceOf(address(dynametric)) > SWAP_AMOUNT / 2);
    }

    // Swap on pool - happy path but reverse
    function test_SwapOnPoolHappyPathButReverse() public {
        vm.startPrank(LPer);
        tokenA.increaseAllowance(address(dynametric), SWAP_AMOUNT);
        tokenB.increaseAllowance(address(dynametric), SWAP_AMOUNT);

        dynametric.createPool(addressB, SWAP_AMOUNT, addressA, SWAP_AMOUNT);
        vm.stopPrank();

        vm.startPrank(SWAPPER);
        tokenB.increaseAllowance(address(dynametric), SWAP_AMOUNT);
        dynametric.swapExactInputForOutput(
            addressB,
            SWAP_AMOUNT,
            addressA,
            SMALL_AMOUNT
        );

        assertEq(tokenB.balanceOf(SWAPPER), STARTING_BALANCE - SWAP_AMOUNT);
        assert(tokenA.balanceOf(SWAPPER) < STARTING_BALANCE + SWAP_AMOUNT / 2);

        assertEq(tokenB.balanceOf(address(dynametric)), 2 * SWAP_AMOUNT);
        assert(tokenA.balanceOf(address(dynametric)) > SWAP_AMOUNT / 2);
    }

    // Swap on pool but exceed slippage
    function test_SwapOnPoolExceedSlippage() public {
        vm.startPrank(LPer);
        tokenA.increaseAllowance(address(dynametric), SWAP_AMOUNT);
        tokenB.increaseAllowance(address(dynametric), SWAP_AMOUNT);

        dynametric.createPool(addressA, SWAP_AMOUNT, addressB, SWAP_AMOUNT);
        vm.stopPrank();

        vm.startPrank(SWAPPER);
        tokenA.increaseAllowance(address(dynametric), SWAP_AMOUNT);

        vm.expectRevert();
        // abi.encodeWithSelector(
        //     Dynametric.Dynametric__ExceededMaxSlippage.selector,
        //     addressA,
        //     SWAP_AMOUNT,
        //     addressB,
        //     SWAP_AMOUNT / 2,
        //     SWAP_AMOUNT
        // )
        dynametric.swapExactInputForOutput(
            addressA,
            SWAP_AMOUNT,
            addressB,
            SWAP_AMOUNT
        );
    }

    // Swap on pool - happy path
    function test_SwapAndSwapBack_HappyPath() public {
        vm.startPrank(LPer);
        tokenA.increaseAllowance(address(dynametric), SWAP_AMOUNT);
        tokenB.increaseAllowance(address(dynametric), SWAP_AMOUNT);

        dynametric.createPool(addressA, SWAP_AMOUNT, addressB, SWAP_AMOUNT);
        vm.stopPrank();

        vm.startPrank(SWAPPER);
        tokenA.increaseAllowance(address(dynametric), SWAP_AMOUNT);
        dynametric.swapExactInputForOutput(
            addressA,
            SWAP_AMOUNT,
            addressB,
            SMALL_AMOUNT
        );
        tokenB.increaseAllowance(address(dynametric), SWAP_AMOUNT);

        console.log(tokenA.balanceOf(SWAPPER));
        console.log(tokenB.balanceOf(SWAPPER));
        console.log(tokenA.balanceOf(address(dynametric)));
        console.log(tokenB.balanceOf(address(dynametric)));

        // dynametric.swapExactInputForOutput(
        //     addressB,
        //     SWAP_AMOUNT,
        //     addressA,
        //     SMALL_AMOUNT
        // );
        dynametric.swapInputForExactOutput(
            addressB,
            SWAP_AMOUNT,
            addressA,
            SWAP_AMOUNT
        );

        console.log(tokenA.balanceOf(SWAPPER));
        console.log(tokenB.balanceOf(SWAPPER));
        console.log(tokenA.balanceOf(address(dynametric)));
        console.log(tokenB.balanceOf(address(dynametric)));

        assertEq(tokenA.balanceOf(SWAPPER), STARTING_BALANCE);
        assert(tokenB.balanceOf(SWAPPER) < STARTING_BALANCE);

        assertEq(tokenA.balanceOf(address(dynametric)), SWAP_AMOUNT);
        assert(tokenB.balanceOf(address(dynametric)) > SWAP_AMOUNT);
    }

    // Swap, Add liquidity, Swap, Remove Liquidity
    function test_IntegrationTest_HappyPath() public {
        vm.startPrank(LPer);
        tokenA.increaseAllowance(address(dnf), SWAP_AMOUNT);
        tokenB.increaseAllowance(address(dnf), SWAP_AMOUNT);

        dnf.createPool(addressA, SWAP_AMOUNT, addressB, SWAP_AMOUNT);
        vm.stopPrank();

        vm.startPrank(SWAPPER);
        tokenA.increaseAllowance(address(dnf), SWAP_AMOUNT);
        dnf.swapExactInputForOutput(
            addressA,
            SWAP_AMOUNT,
            addressB,
            SMALL_AMOUNT
        );
        vm.stopPrank();

        vm.startPrank(LPer);
        tokenA.increaseAllowance(address(dnf), SWAP_AMOUNT);
        tokenB.increaseAllowance(address(dnf), SWAP_AMOUNT);

        dnf.addLiquidity(addressA, SWAP_AMOUNT, addressB, SWAP_AMOUNT);
        vm.stopPrank();

        assertEq(tokenA.balanceOf(address(dnf)), SWAP_AMOUNT * 3);
        assertEq(tokenB.balanceOf(address(dnf)), (SWAP_AMOUNT * 3) / 4);

        vm.startPrank(SWAPPER);
        tokenB.increaseAllowance(address(dnf), (SWAP_AMOUNT * 3) / 2);
        dnf.swapInputForExactOutput(
            addressB,
            (SWAP_AMOUNT * 3) / 4,
            addressA,
            (SWAP_AMOUNT * 3) / 2
        );
        vm.stopPrank();

        assertEq(tokenA.balanceOf(address(dnf)), (SWAP_AMOUNT * 3) / 2);
        assertEq(tokenB.balanceOf(address(dnf)), (SWAP_AMOUNT * 3) / 2);

        vm.startPrank(LPer);
        uint lpbalance = dnf.getLPBalance(addressA, addressB, LPer);
        assertEq(lpbalance, (SWAP_AMOUNT * SWAP_AMOUNT * 3) / 2 - 1000);
        dnf.removeLiquidity(
            addressA,
            addressB,
            lpbalance
        );
        vm.stopPrank();
    }

    // Try to remove more liquidity tokens than you have
    function test_removeTooMuchLiquidity() public {
        vm.startPrank(LPer);
        tokenA.increaseAllowance(address(dynametric), SWAP_AMOUNT);
        tokenB.increaseAllowance(address(dynametric), SWAP_AMOUNT);

        dynametric.createPool(addressA, SWAP_AMOUNT, addressB, SWAP_AMOUNT);

        vm.expectRevert();
        dynametric.removeLiquidity(
            addressA,
            addressB,
            SWAP_AMOUNT * SWAP_AMOUNT
        );
    }

    // Add liquidity to pool that does not exist
    function test_addLiquidityFromDNEPool() public {
        vm.startPrank(LPer);

        vm.expectRevert(
            abi.encodeWithSelector(
                Dynametric.Dynametric__PoolDoesNotExist.selector,
                addressA,
                addressB
            )
        );
        dynametric.addLiquidity(addressA, SWAP_AMOUNT, addressB, SWAP_AMOUNT);
    }

    // Remove liquidity from pool that does not exist
    function test_removeLiquidityFromDNEPool() public {
        vm.startPrank(LPer);

        vm.expectRevert(
            abi.encodeWithSelector(
                Dynametric.Dynametric__PoolDoesNotExist.selector,
                addressA,
                addressB
            )
        );
        dynametric.removeLiquidity(addressA, addressB, SWAP_AMOUNT);
    }
}
