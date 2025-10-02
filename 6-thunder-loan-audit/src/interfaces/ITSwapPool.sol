// SPDX-License-Identifier: AGPL-3.0-only
//@audit-info PUSH0 Opcode, detailed in Aderyn report
pragma solidity 0.8.20;

// @Audit-Question: Why are we only using the price of a pool token in weth?
// It is a bug!
interface ITSwapPool {
    function getPriceOfOnePoolTokenInWeth() external view returns (uint256);
}
