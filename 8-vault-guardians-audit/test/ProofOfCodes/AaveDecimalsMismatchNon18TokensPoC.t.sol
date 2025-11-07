// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {AaveAdapter} from "../../src/protocol/InvestableUniverseAdapters/AaveAdapter.sol";
import {IPool} from "../../src/vendor/IPool.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Mock USDC token with 6 decimals
contract MockUSDC is ERC20 {
    constructor() ERC20("Mock USDC", "USDC") {}

    function decimals() public pure override returns (uint8) {
        return 6;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

// Mock Aave pool
contract MockAavePool {
    function supply(
        address asset,
        uint256 amount,
        address onBehalfOf,
        uint16
    ) external {
        IERC20(asset).transferFrom(onBehalfOf, address(this), amount);
    }
}

// Mock vault with Aave Adapter for investment strategy
contract MockVault is AaveAdapter {
    IERC20 public immutable asset;

    constructor(address pool, IERC20 _asset) AaveAdapter(pool) {
        asset = _asset;
    }

    function invest(uint256 amount) external {
        // Simulate deposit of tokens into the vault
        _aaveInvest(asset, amount);
    }
}

// ---------------------------
//       Test Contract
// ---------------------------

contract AaveDecimalsMismatchNon18TokensPoC is Test {
    MockUSDC private usdc;
    MockAavePool private aavePool;
    MockVault private vault;

    error ERC20InsufficientBalance(address, uint256, uint256);

    function setUp() public {
        usdc = new MockUSDC();
        aavePool = new MockAavePool();
        vault = new MockVault(address(aavePool), usdc);

        usdc.mint(address(vault), 1e6);
    }

    function test_USDCRevertsDueToDecimalMismatch() public {
        // Simulate normalized 18-decimal math — vault believes amount is 1e18
        uint256 normalAmount = 1e18;

        uint256 currentBalance = usdc.balanceOf(address(vault));
        console.log("Current Balance:", currentBalance);

        uint256 requiredBalance = normalAmount;
        console.log("Requiered Balance:", requiredBalance);

        // Expect revert because trying to transfer 1e18 USDC
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC20InsufficientBalance.selector,
                address(vault),
                currentBalance,
                requiredBalance
            )
        );

        vault.invest(normalAmount);
    }
}
