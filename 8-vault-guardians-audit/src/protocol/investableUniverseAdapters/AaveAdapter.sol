// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IPool} from "../../vendor/IPool.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract AaveAdapter {
    using SafeERC20 for IERC20;

    error AaveAdapter__TransferFailed();

    IPool public immutable i_aavePool;

    constructor(address aavePool) {
        i_aavePool = IPool(aavePool);
    }

    /**
     * @notice Used by the vault to deposit vault's underlying asset token as lending amount in Aave v3
     * @param asset The vault's underlying asset token
     * @param amount The amount of vault's underlying asset token to invest
     */
    function _aaveInvest(IERC20 asset, uint256 amount) internal {
        // @audit-issue Unsafe approve pattern -> Use SafeERC20.safeIncreaseAllowance OZ library(Low - AAVE is a trusted spender)
        // asset.safeIncreaseAllowance(address(i_aavePool), amount);
        // If the vault logic always uses 18-decimal normalized math, we must rescale:
        // @audit-issue USDC token -> no amount transformation leads to invalid amounts
        uint8 assetDecimals = IERC20Metadata(address(asset)).decimals();

        if (assetDecimals < 18) {
            amount = amount / (10 ** (18 - assetDecimals));
        } else if (assetDecimals > 18) {
            amount = amount * (10 ** (assetDecimals - 18));
        }

        bool succ = asset.approve(address(i_aavePool), amount);
        if (!succ) {
            revert AaveAdapter__TransferFailed();
        }
        i_aavePool.supply({
            asset: address(asset),
            amount: amount,
            onBehalfOf: address(this), // decides who get's Aave's aTokens for the investment. In this case, mint it to the vault
            referralCode: 0
        });
    }

    /**
     * @notice Used by the vault to withdraw the its underlying asset token deposited as lending amount in Aave v3
     * @param token The vault's underlying asset token to withdraw
     * @param amount The amount of vault's underlying asset token to withdraw
     */
    // @audit-issue - Low: No explicit return, when compiled will return 0(because `amountOfAssetReturned` is not initialized) which is not good, check where _aaveDivest is used
    // @audit-issue Unchecked return value
    function _aaveDivest(
        IERC20 token,
        uint256 amount
    ) internal returns (uint256 amountOfAssetReturned) {
        /* amountOfAssetReturned = */ i_aavePool.withdraw({
            asset: address(token),
            amount: amount,
            to: address(this)
        });
        // if (amountOfAssetReturned == 0) {
        //   revert AaveAdapter__NothingToWithdraw();
        // }
        // return amountOfAssetReturned;
    }
}
