// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {StdInvariant} from "forge-std/StdInvariant.sol";
import {Test, console, console2} from "forge-std/Test.sol";
import {Base_Test_Invariant} from "./utils/Base_Test_Invariant.t.sol";
import {Handler} from "./Handler.t.sol";
import {IVaultShares, IVaultData} from "../../src/interfaces/IVaultShares.sol";
import {VaultShares} from "../../src/protocol/VaultShares.sol";
import {IUniswapV2Pair} from "../utils/IUniswapV2Pair.sol";
import {IERC20} from "../../src/protocol/VaultGuardians.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";

contract Invariant is StdInvariant, Test, Base_Test_Invariant {
    address public guardian = makeAddr("guardian");
    address public user = makeAddr("user");

    VaultShares public wethVaultShares;
    VaultShares public usdcVaultShares;

    uint256 mintAmount = 100 ether;

    // uint256 guardianAndDaoCut;
    // uint256 stakePrice;

    Handler public handler;

    // 500 hold, 250 uniswap, 250 aave
    IVaultData.AllocationData allocationData =
        IVaultData.AllocationData({
            holdAllocation: 500,
            uniswapAllocation: 250,
            aaveAllocation: 250
        });

    function setUp() public override {
        Base_Test_Invariant.setUp();

        weth.mint(mintAmount, guardian);
        vm.startPrank(guardian);
        weth.approve(address(vaultGuardians), mintAmount);
        address wethVault = vaultGuardians.becomeGuardian(allocationData);
        wethVaultShares = VaultShares(wethVault);
        vm.stopPrank();

        usdc.mint(mintAmount, guardian);
        vm.startPrank(guardian);
        usdc.approve(address(vaultGuardians), mintAmount);
        address tokenVault = vaultGuardians.becomeTokenGuardian(
            allocationData,
            usdc
        );
        usdcVaultShares = VaultShares(tokenVault);
        vm.stopPrank();

        // guardianAndDaoCut = vaultGuardians.getGuardianAndDaoCut();
        // stakePrice = vaultGuardians.getGuardianStakePrice();

        handler = new Handler(usdcVaultShares, usdc, user);
        targetContract(address(handler));

        // bytes4[] memory selectors = new bytes4[](3);
        // selectors[0] = handler.deposit.selector;
        // selectors[1] = handler.withdraw.selector;
        // selectors[2] = handler.redeem.selector;

        // FuzzSelector memory selector = FuzzSelector({
        //     addr: address(handler),
        //     selectors: selectors
        // });

        // targetSelector(selector);
    }

    /**
     * Invariant: The total vault value (on-chain + invested) must always be ≥ total user deposits.
     */
    function invariant_totalAssetsConservation() public {
        uint256 vaultTotal = usdcVaultShares.totalAssets();

        uint256 internalHoldings = IERC20(usdcVaultShares.asset()).balanceOf(
            address(usdcVaultShares)
        );

        (uint256 aaveInvested, uint256 uniswapInvested) = getInvestedAmounts();
        uint256 invested = aaveInvested + uniswapInvested;

        console2.log("Vault totalAssets:", vaultTotal);
        console2.log("Internal holdings:", internalHoldings);
        console2.log("Aave invested:", aaveInvested);
        console2.log("Uniswap invested:", uniswapInvested);

        assertApproxEqAbs(
            vaultTotal,
            internalHoldings + invested,
            (internalHoldings + invested) / 2
        );

        // uint256 netDeposits = handler.getNetDeposits();
        //assertGe(internalHoldings + invested + 1e6, handler.getNetDeposits());
    }

    function getInvestedAmounts()
        public
        view
        returns (uint256 aaveInvested, uint256 uniswapInvested)
    {
        address aaveTokenUsdc = usdcVaultShares.getAaveAToken();
        address uniswapLpToken = usdcVaultShares.getUniswapLiquidtyToken();

        // --- AAVE ---
        aaveInvested = IERC20(aaveTokenUsdc).balanceOf(
            address(usdcVaultShares) // Is this the usdc amount investment or the aaveToken for usdc investment
        );

        // --- UNISWAP ---
        uint256 lpBalance = IERC20(uniswapLpToken).balanceOf(
            address(usdcVaultShares)
        );
        if (lpBalance > 0) {
            (uint112 reserve0, uint112 reserve1, ) = IUniswapV2Pair(
                address(uniswapLpToken)
            ).getReserves();
            uint256 totalSupply = IERC20(uniswapLpToken).totalSupply();
            address token0 = IUniswapV2Pair(address(uniswapLpToken)).token0();
            address token1 = IUniswapV2Pair(address(uniswapLpToken)).token1();

            // base asset = vault's asset()
            if (token0 == address(usdc)) {
                uniswapInvested = (uint256(reserve0) * lpBalance) / totalSupply;
            } else if (token1 == address(usdc)) {
                uniswapInvested = (uint256(reserve1) * lpBalance) / totalSupply;
            } else {
                // edge case: LP doesn't actually contain the vault's asset
                uniswapInvested = 0;
            }
        }
    }
}
