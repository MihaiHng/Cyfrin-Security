// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IPool, DataTypes} from "../../../src/vendor/IPool.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IMintableERC20 is IERC20 {
    function mint(uint256 amount, address to) external;

    function burn(uint256 amount, address from) external;
}

contract AavePoolMockInvariant is IPool {
    mapping(address => address) public s_assetToAtoken;

    function updateAtokenAddress(address asset, address aToken) public {
        s_assetToAtoken[asset] = aToken;
    }

    // Mimics Aave supply: pull asset + mint aToken
    function supply(
        address asset,
        uint256 amount,
        address onBehalfOf,
        uint16
    ) external {
        IERC20(asset).transferFrom(msg.sender, address(this), amount);

        address aToken = s_assetToAtoken[asset];
        require(aToken != address(0), "AavePoolMock: aToken not set");

        IMintableERC20(aToken).mint(amount, onBehalfOf);
    }

    // Mimics Aave withdraw: burn aToken + return asset
    function withdraw(
        address asset,
        uint256 amount,
        address to
    ) external returns (uint256) {
        address aToken = s_assetToAtoken[asset];
        require(aToken != address(0), "AavePoolMock: aToken not set");

        IMintableERC20(aToken).burn(amount, msg.sender);
        IERC20(asset).transfer(to, amount);

        return amount;
    }

    // Minimal reserve data support
    function getReserveData(
        address asset
    ) external view returns (DataTypes.ReserveData memory) {
        DataTypes.ReserveConfigurationMap memory map = DataTypes
            .ReserveConfigurationMap({data: 0});

        return
            DataTypes.ReserveData({
                configuration: map,
                liquidityIndex: 0,
                currentLiquidityRate: 0,
                variableBorrowIndex: 0,
                currentVariableBorrowRate: 0,
                currentStableBorrowRate: 0,
                lastUpdateTimestamp: 0,
                id: 0,
                aTokenAddress: s_assetToAtoken[asset],
                stableDebtTokenAddress: address(0),
                variableDebtTokenAddress: address(0),
                interestRateStrategyAddress: address(0),
                accruedToTreasury: 0,
                unbacked: 0,
                isolationModeTotalDebt: 0
            });
    }
}
