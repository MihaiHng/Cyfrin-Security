// SPDX-License-Identifier: MIT
//@audit-info PUSH0 Opcode, detailed in Aderyn report
pragma solidity 0.8.20;

// @audit-info  The IThunderLoan interface should be implemented by the ThunderLoan contract!
interface IThunderLoan {
    // @audit-info - Incorrect parameter type being passed
    function repay(address token, uint256 amount) external;
}
