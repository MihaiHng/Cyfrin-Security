// SPDX-License-Identifier: AGPL-3.0
//@audit-info PUSH0 Opcode, detailed in Aderyn report
pragma solidity 0.8.20;

// @audit-info Unused import, written in Aderyn:  It's bad practice to edit live code for tests/mocks, we must remove the import from `MockFlashLockReceiver.sol`
import {IThunderLoan} from "./IThunderLoan.sol";

/**
 * @dev Inspired by Aave:
 * https://github.com/aave/aave-v3-core/blob/master/contracts/flashloan/interfaces/IFlashLoanReceiver.sol
 */
// @audit-info - No natspec
interface IFlashLoanReceiver {
    function executeOperation(
        address token,
        uint256 amount,
        uint256 fee,
        address initiator,
        bytes calldata params
    ) external returns (bool);
}
