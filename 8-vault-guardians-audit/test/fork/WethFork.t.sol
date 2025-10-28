// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19 <0.9.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {VaultShares} from "../../src/protocol/VaultShares.sol";
import {IWETH} from "./IWeth.sol";
import {Test, console} from "forge-std/Test.sol";

import {Fork_Test} from "./Fork.t.sol";

contract WethForkTest is Fork_Test {
    address public guardian = makeAddr("guardian");
    address public user = makeAddr("user");

    IWETH internal wETH;
    IERC20 internal uSDC;

    VaultShares public wethVaultShares;
    VaultShares public usdcVaultShares;

    uint256 guardianAndDaoCut;
    uint256 stakePrice;
    uint256 mintAmount = 100 ether;
    uint256 userBalance = 1000 ether;
    uint256 depositAmount = 100 ether;

    // 500 hold, 250 uniswap, 250 aave
    AllocationData allocationData = AllocationData(500, 250, 250);
    AllocationData newAllocationData = AllocationData(0, 500, 500);

    function setUp() public virtual override {
        Fork_Test.setUp();
        vm.deal(user, userBalance);
        vm.deal(guardian, userBalance);
        wETH = IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        uSDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

        deal(address(uSDC), guardian, userBalance);
        deal(address(uSDC), user, userBalance);
    }

    modifier hasGuardian() {
        vm.startPrank(guardian);
        wETH.deposit{value: mintAmount}(); // convert ETH -> WETH
        wETH.approve(address(vaultGuardians), mintAmount);
        console.log("vaultGuardians WETH: ", address(vaultGuardians.getWeth()));
        address wethVault = vaultGuardians.becomeGuardian(allocationData);
        console.log("VaultShares created: ", wethVault);
        wethVaultShares = VaultShares(wethVault);
        console.log(
            "Uniswap LP token: ",
            address(wethVaultShares.i_uniswapLiquidityToken())
        );
        console.log("VaultShares asset(): ", address(wethVaultShares.asset()));
        vm.stopPrank();
        _;
    }

    modifier hasTokenGuardian() {
        vm.startPrank(guardian);
        uSDC.approve(address(vaultGuardians), mintAmount);
        address tokenVault = vaultGuardians.becomeTokenGuardian(
            allocationData,
            uSDC
        );
        usdcVaultShares = VaultShares(tokenVault);
        vm.stopPrank();
        _;
    }

    // // Does not work when depositing weth => weth/weth pair => uniswap LP address(0)
    // function testWethDepositAndWithdraw() public hasGuardian {
    //     assertTrue(
    //         address(vaultGuardians.getWeth()) != address(0),
    //         "WETH address is zero"
    //     );

    //     console.logAddress(address(weth));

    //     vm.startPrank(user);
    //     wETH.deposit{value: mintAmount}(); // convert ETH -> WETH
    //     console.log("WETH amount user: ", wETH.balanceOf(user));
    //     uint256 wethBalanceBefore = wETH.balanceOf(address(user));
    //     console.log("User balance before: ", wethBalanceBefore);
    //     wETH.approve(address(wethVaultShares), mintAmount);
    //     wethVaultShares.deposit(depositAmount, msg.sender);

    //     vm.warp(block.timestamp + 1 days);
    //     vm.roll(block.number + 1);

    //     wethVaultShares.withdraw(depositAmount, user, msg.sender);
    //     vm.stopPrank();

    //     uint256 wethBalanceAfter = wETH.balanceOf(address(user));

    //     assertGe(wethBalanceAfter, wethBalanceBefore);
    // }

    function testUsdcDepositAndWithdraw() public hasGuardian hasTokenGuardian {
        assertTrue(
            address(vaultGuardians.getTokenOne()) != address(0),
            "USDC address is zero"
        );

        uint256 usdcBalanceBefore = uSDC.balanceOf(address(user));
        console.log("User balance before: ", usdcBalanceBefore);

        vm.startPrank(user);
        uSDC.approve(address(vaultGuardians), depositAmount);
        uint256 usdcSharesAfterDeposit = usdcVaultShares.deposit(
            depositAmount,
            msg.sender
        );
        console.log("User shares after deposit: ", usdcSharesAfterDeposit);

        vm.warp(block.timestamp + 1 days);
        vm.roll(block.number + 1);

        uint256 useSharesAfterWithdraw = usdcVaultShares.withdraw(
            depositAmount,
            user,
            msg.sender
        );
        console.log("User shares after withdraw: ", useSharesAfterWithdraw);
        vm.stopPrank();

        uint256 usdcBalanceAfter = uSDC.balanceOf(address(user));
        console.log("User balance after: ", usdcBalanceAfter);

        assertGe(usdcBalanceAfter, usdcBalanceBefore);
    }
}
