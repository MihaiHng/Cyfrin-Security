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

    VaultShares public wethVaultShares;

    uint256 guardianAndDaoCut;
    uint256 stakePrice;
    uint256 mintAmount = 100 ether;
    uint256 userEthBalance = 1000 ether;
    uint256 depositAmount = 100 ether;

    // 500 hold, 250 uniswap, 250 aave
    AllocationData allocationData = AllocationData(500, 250, 250);
    AllocationData newAllocationData = AllocationData(0, 500, 500);

    function setUp() public virtual override {
        Fork_Test.setUp();
        vm.deal(user, userEthBalance);
        vm.deal(guardian, userEthBalance);
        wETH = IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
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

    function testDepositAndWithdraw() public hasGuardian {
        assertTrue(
            address(vaultGuardians.getWeth()) != address(0),
            "WETH address is zero"
        );

        console.logAddress(address(weth));

        vm.startPrank(user);
        wETH.deposit{value: mintAmount}(); // convert ETH -> WETH
        console.log("WETH amount user: ", wETH.balanceOf(user));
        uint256 wethBalanceBefore = wETH.balanceOf(address(user));
        console.log("User balance before: ", wethBalanceBefore);
        wETH.approve(address(wethVaultShares), mintAmount);
        wethVaultShares.deposit(depositAmount, msg.sender);

        vm.warp(block.timestamp + 1 days);
        vm.roll(block.number + 1);

        wethVaultShares.withdraw(depositAmount, user, msg.sender);
        vm.stopPrank();

        uint256 wethBalanceAfter = wETH.balanceOf(address(user));

        assertGe(wethBalanceAfter, wethBalanceBefore);
    }
}
