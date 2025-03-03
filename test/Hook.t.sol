// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {BalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {CurrencyLibrary, Currency} from "v4-core/types/Currency.sol";
import {PoolSwapTest} from "v4-core/test/PoolSwapTest.sol";
import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {Hook} from "../src/Hook.sol";
import {IERC20Minimal} from "v4-core/interfaces/external/IERC20Minimal.sol";

contract HookTest is Test, Deployers {
    Hook hook;

    function setUp() public {
        deployFreshManagerAndRouters();
        (currency0, currency1) = deployMintAndApprove2Currencies();

        address hookAddress = address(
            uint160(
                Hooks.BEFORE_SWAP_FLAG | Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG
            )
        );
        deployCodeTo("Hook.sol", abi.encode(manager), hookAddress);
        hook = Hook(hookAddress);

        (key, ) = initPool(currency0, currency1, hook, 3000, SQRT_PRICE_1_1);

        modifyLiquidityRouter.modifyLiquidity(
            key,
            IPoolManager.ModifyLiquidityParams({
                tickLower: -60,
                tickUpper: 60,
                liquidityDelta: 100000e18,
                salt: bytes32(0)
            }),
            ZERO_BYTES
        );
    }

    function test_swap_pause() public {
        uint256 hookToken0BalanceBefore = key.currency0.balanceOf(
            address(hook)
        );
        uint256 userToken1BalanceBefore = key.currency1.balanceOf(
            address(this)
        );

        swapRouter.swap(
            key,
            IPoolManager.SwapParams({
                zeroForOne: true,
                amountSpecified: -100e18,
                sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
            }),
            PoolSwapTest.TestSettings({
                takeClaims: false,
                settleUsingBurn: false
            }),
            ZERO_BYTES
        );

        uint256 hookToken0BalanceAfter = key.currency0.balanceOf(address(hook));
        uint256 userToken1BalanceAfter = key.currency1.balanceOf(address(this));

        assertEq(hookToken0BalanceAfter, hookToken0BalanceBefore + 100e18); // hook got all 100 tokens
        assertEq(userToken1BalanceAfter, userToken1BalanceBefore); // user didnt get any token1
    }
}
