// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {VaultShares} from "../../src/protocol/VaultShares.sol";
import {IVaultShares, IERC4626, IVaultData} from "../../src/interfaces/IVaultShares.sol";
import {DataTypes} from "../../src/vendor/DataTypes.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Base_Test} from "../Base.t.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";

// Mocks returning address(0)
contract MockAavePool is Base_Test {
    function getReserveData(
        address
    ) external pure returns (DataTypes.ReserveData memory) {
        // Create a blank configuration map
        DataTypes.ReserveConfigurationMap memory emptyConfig = DataTypes
            .ReserveConfigurationMap({data: 0});

        return
            DataTypes.ReserveData({
                configuration: emptyConfig,
                liquidityIndex: 0,
                currentLiquidityRate: 0,
                variableBorrowIndex: 0,
                currentVariableBorrowRate: 0,
                currentStableBorrowRate: 0,
                lastUpdateTimestamp: 0,
                id: 0,
                aTokenAddress: address(0),
                stableDebtTokenAddress: address(0),
                variableDebtTokenAddress: address(0),
                interestRateStrategyAddress: address(0),
                accruedToTreasury: 0,
                unbacked: 0,
                isolationModeTotalDebt: 0
            });
    }
}

contract MockUniswapFactory {
    function getPair(address, address) external pure returns (address) {
        return address(0);
    }
}

contract MockUniswapRouterZero {
    address private _factory;

    constructor(address factory_) {
        _factory = factory_;
    }

    function factory() external view returns (address) {
        return _factory;
    }
}

contract VaultSharesZeroAddressPoC is Base_Test {
    function test_DeployVaultWithZeroAddresses() public {
        // Deploy mocks used for this PoC (independent of Base_Test's network config)
        MockAavePool poolZero = new MockAavePool();
        MockUniswapFactory factoryZero = new MockUniswapFactory();
        MockUniswapRouterZero routerZero = new MockUniswapRouterZero(
            address(factoryZero)
        );

        // Deploy simple ERC20 mocks for asset/weth/usdc (reuse your ERC20Mock)
        ERC20Mock mockAsset = new ERC20Mock();
        ERC20Mock mockWETH = new ERC20Mock();
        ERC20Mock mockUSDC = new ERC20Mock();

        // Make sure the deployer (this) is the vaultGuardians to satisfy onlyVaultGuardians in constructor
        IVaultShares.ConstructorData memory cdata = IVaultShares
            .ConstructorData({
                asset: mockAsset,
                vaultName: "ZeroAddressVault",
                vaultSymbol: "ZAV",
                aavePool: address(poolZero),
                uniswapRouter: address(routerZero),
                weth: address(mockWETH),
                usdc: address(mockUSDC),
                guardian: address(this),
                guardianAndDaoCut: 100, // arbitrary
                vaultGuardians: address(this), // important: constructor calls updateHoldingAllocation() which is onlyVaultGuardians
                allocationData: IVaultData.AllocationData({
                    holdAllocation: 500,
                    uniswapAllocation: 250,
                    aaveAllocation: 250
                })
            });

        // Deploy VaultShares (constructor will query aavePoolZero and factoryZero)
        VaultShares vault = new VaultShares(cdata);

        console.log("Vault deployed at:", address(vault));

        // Vulnerable state: the constructor saved zero addresses returned by external calls
        address aToken = vault.getAaveAToken();
        address lpToken = vault.getUniswapLiquidtyToken();

        console.log("aToken stored:", aToken);
        console.log("uniswap LP token stored:", lpToken);

        assertEq(aToken, address(0), "expected aToken to be address(0)");
        assertEq(
            lpToken,
            address(0),
            "expected uniswap LP token to be address(0)"
        );
    }
}
