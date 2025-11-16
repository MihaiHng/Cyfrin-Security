// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console, console2} from "forge-std/Test.sol";
import {VaultShares} from "../../src/protocol/VaultShares.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";

contract Handler is Test {
    VaultShares public usdcVault;
    ERC20Mock public usdc;
    address public user;

    uint256 public totalDeposited;
    uint256 public totalWithdrawn;

    constructor(VaultShares _usdcVault, ERC20Mock _usdc, address _user) {
        usdcVault = _usdcVault;
        usdc = _usdc;
        user = _user;
    }

    function deposit(uint256 amount) public {
        amount = bound(amount, 1e6, 1e20);

        usdc.mint(amount, address(user));

        vm.startPrank(user);
        usdc.approve(address(usdcVault), amount);
        usdcVault.deposit(amount, user);
        vm.stopPrank();

        totalDeposited += amount;
    }

    function withdraw(uint256 amount) public {
        uint256 userShares = usdcVault.balanceOf(user);
        if (userShares == 0) return; // skip if no balance

        uint256 assetsAvailable = usdcVault.convertToAssets(userShares);
        amount = bound(amount, 0, assetsAvailable);

        vm.startPrank(user);
        usdcVault.withdraw(amount, user, user);
        vm.stopPrank();

        totalWithdrawn += amount;
    }

    function redeem(uint256 shares) public {
        uint256 userShares = usdcVault.balanceOf(user);
        if (userShares == 0) return; // skip if no balance

        shares = bound(shares, 1, userShares);

        vm.startPrank(user);
        usdcVault.redeem(shares, user, user);
        vm.stopPrank();

        uint256 assetsReturned = usdcVault.convertToAssets(shares);
        totalWithdrawn += assetsReturned;
    }

    function getNetDeposits() external view returns (uint256) {
        return totalDeposited - totalWithdrawn;
    }
}
