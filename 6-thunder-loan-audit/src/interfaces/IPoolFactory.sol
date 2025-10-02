// SPDX-License-Identifier: AGPL-3.0-only
//@audit-info PUSH0 Opcode, detailed in Aderyn report
pragma solidity 0.8.20;

interface IPoolFactory {
    function getPool(address tokenAddress) external view returns (address);
}
