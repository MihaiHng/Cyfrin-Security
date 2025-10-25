### [S-#] TITLE (Root Cause -> Impact)

**Description:** 

**Impact:** 

**Proof of Concept:**

**Recommended Mitigation:** 



### [H-#] `nonReentrant` is not the First Modifier in `VaultShares.sol` which makes the functions vulnerable to reentrancy attacks

**Description:** 

Found in:
`VaultShares::deposit`
`VaultShares::rebalanceFunds`
`VaultShares::withdraw`
`VaultShares::redeem`

The placement of the divestThenInvest modifier before the nonReentrant modifier in the function signature creates a critical window for exploitation.

```js
function rebalanceFunds() public isActive divestThenInvest nonReentrant {}
```

**Impact:** Loss or manipulation of funds

This could allow an attacker to, for example, withdraw their share twice or call the divestment logic to retrieve tokens that they shouldn't have access to, leading to a direct loss of user funds from the vault.

A reentrant call could interrupt the process, leading to a situation where the contract's internal accounting is calculated based on incomplete or manipulated data.

**Proof of Concept:**

*** Mechanism of Attack ***

The Solidity compiler executes modifiers in the order they are listed.

1. isActive runs (a simple check, no external call, safe).

2. divestThenInvest runs:

- It executes the Divest logic, which includes external calls to third-party protocols (Uniswap and Aave) via _uniswapDivest and _aaveDivest.

- Since divestment from these protocols often involves the target protocol sending tokens back to the vault, these are external calls that transfer control flow.

3. Reentrancy Window Opens: An attacker (who controls one of the addresses or a token hook involved in the divestment) can trigger a malicious fallback or hook function in their contract during the divestment phase.

4. Bypass: The attacker's malicious code executes and immediately calls rebalanceFunds() again. Since the execution hasn't reached the nonReentrant modifier yet, the reentrancy lock has not been set.

5. Exploitation: The recursive call to rebalanceFunds() proceeds and executes the divestThenInvest logic a second time, potentially causing unauthorized state changes, double-claiming of funds, or manipulation of the fund's internal accounting before the first call can complete its state updates.

**Recommended Mitigation:** The fix is a best practice standard that should always be followed to prevent a reentrancy vulnerability from being introduced in the future:

Always place the nonReentrant modifier first in the function declaration.

```js
function rebalanceFunds() public nonReentrant isActive divestThenInvest {}
```


### [H-#] Using `block.timestamp` for swap deadline offers no protection

**Description:** The purpose of the deadline parameter in a swap function (like on Uniswap) is to specify a fixed future time after which the transaction will fail.

When deadline: block.timestamp is used, the deadline is set to the exact moment the transaction is included in the block.

The swap router contract usually checks: 

```js
require(deadline >= block.timestamp, 'EXPIRED');
```

**Impact:** Loss of funds(MEV Attacks), transactions stuck forever

The primary function of the swap deadline is to protect the user from slippage and Miner Extractable Value (MEV) attacks, specifically the sandwich attack. By nullifying the deadline check:

Enables Sandwich Attacks: A block producer (validator) can see the user's transaction in the mempool and hold it indefinitely. They can wait for the price to move favorably, execute a transaction just before the user's swap (front-running) to drive the price against the user, and a transaction just after (back-running) to pocket the difference. The user is guaranteed a bad price, and the block producer extracts maximum value.

Allows Arbitrary Delay/Censorship: The validator can delay the transaction for hours or even days, allowing huge price swings that exceed the user's intended slippage tolerance, leading to massive and unintended loss of funds.

The direct result of this vulnerability is the theft or extraction of value from the user, which places it firmly in the high-severity category.

**Proof of Concept:** If the user passes a fixed future time (e.g., block.timestamp + 300 seconds from the frontend), the check prevents the transaction from being executed after that time.

If the user passes block.timestamp from within the smart contract, the condition becomes require(block.timestamp >= block.timestamp), which will always be true.

The deadline check is completely bypassed, meaning the transaction never expires due to time and offers zero protection against high slippage or attacks by malicious block producers.

**Recommended Mitigation:** 

1. Use a future deadline window
Instead of:
deadline: block.timestamp
use something like:
deadline: block.timestamp + 300  // 5 minutes
or make it configurable.
That way:
Your transaction won’t be stuck forever (it expires in 5 minutes).
A validator can’t hold it indefinitely for manipulation.

2. Use MEV-resistant submission 
For high-value transactions:
Send the transaction via Flashbots Protect / MEV-Blocker RPC or similar RPC relayers.
These systems submit your transaction directly to block builders privately (not via the public mempool), preventing front-running and sandwiching.

### [M-1] Using unsafe ERC20 approve() operation in AaveAdapter.sol, UniswapAdapter.sol and VaultGuardiansBase.sol can result in stolen assets

**Description:** The ERC20 approve() function sets the spender’s allowance to a specific amount — but if there was already an allowance, it overwrites it. This creates a race condition known as the ERC20 approve front-running issue:
If someone can front-run your transaction between two approvals (e.g., approve(100) → approve(200)), they might use the old allowance before it’s updated.

Used in: 

`UniswapAdapter::_uniswapInvest`
`AaveAdapter::_aaveInvest`
`VaultGuardiansBase::_becomeTokenGuardian`

**Impact:** Loss of funds 

**Proof of Concept:**

You currently have allowance = 100.
You try to change it to 200.
Before your new approval is mined, the spender calls transferFrom(..., 100) — using the old allowance.
Your transaction sets allowance to 200 again → they can now pull 200 more.
This risk exists any time you use approve() to modify a nonzero allowance directly.

**Recommended Mitigation:** 

✅ Option 1 — Use SafeERC20.safeIncreaseAllowance
OpenZeppelin’s SafeERC20 has helper functions that safely add to the existing allowance instead of overwriting it:
asset.safeIncreaseAllowance(address(i_aavePool), amount);
This increases the allowance by amount rather than replacing it, and reverts on failure.
You don’t even need to check a boolean return — the SafeERC20 wrapper handles that internally.

✅ Option 2 — Use safeApprove(0) before setting new allowance
If you prefer the raw approve() semantics, the safe pattern is:
asset.safeApprove(address(i_aavePool), 0);
asset.safeApprove(address(i_aavePool), amount);
This clears the previous allowance first (per ERC20 recommendations), then sets the new one.
It ensures no residual approvals exist in between.

In this specific context ( Aave and Uniswap), the spender is a trusted protocol — it will only pull tokens during your supply()/addLiquidity() call, so the race condition isn’t a real-world exploit risk.

However, it’s still a bad pattern to replicate elsewhere, for example VaultGuardiansBase.sol.
If your vault ever interacts with other contracts dynamically (like different pools or adapters), it becomes dangerous.
So it’s still best practice to always use SafeERC20 helpers for approvals.


### [L-1] Unchecked return value 

**Description:** These functions return a value that is then ignored and can lead to several severe security and functionality consequences, especially in DeFi protocols dealing with asset transfers and external calls.

`VaultShares::divestThenInvest` - _aaveDivest(), _uniswapDivest()
`AaveAdapter::_aaveDivest`

**Impact:** The primary consequence is the loss of funds or a failure to execute critical protocol logic without the contract being aware.

**Proof of Concept:**

**Recommended Mitigation:** The necessary fix is to always check the return value of external calls that return a success indicator or an amount.

Example check pattern for value return: 

```js
if(returnedValue == 0) {
    revert ("No assets returned");
}
```

### [L-2] Unused State Variable in `VaultGuardiansBase`

**Description:** Declared variable is not used anywhere in the contract logic

```js
	    uint256 private constant GUARDIAN_FEE = 0.1 ether;
```

**Recommended Mitigation:** Consider removing it.


### [L-3] Unused error in `VaultGuardians`, `VaultGuardiansBase`

**Description:** 

<details><summary>4 Found Instances</summary>


- Found in src/protocol/VaultGuardians.sol [Line: 43](src/protocol/VaultGuardians.sol#L43)

    ```solidity
        error VaultGuardians__TransferFailed();
    ```

- Found in src/protocol/VaultGuardiansBase.sol [Line: 46](src/protocol/VaultGuardiansBase.sol#L46)

    ```solidity
        error VaultGuardiansBase__NotEnoughWeth(uint256 amount, uint256 amountNeeded);
    ```

- Found in src/protocol/VaultGuardiansBase.sol [Line: 48](src/protocol/VaultGuardiansBase.sol#L48)

    ```solidity
        error VaultGuardiansBase__CantQuitGuardianWithNonWethVaults(address guardianAddress);
    ```

- Found in src/protocol/VaultGuardiansBase.sol [Line: 51](src/protocol/VaultGuardiansBase.sol#L51)

    ```solidity
        error VaultGuardiansBase__FeeTooSmall(uint256 fee, uint256 requiredFee);
    ```

</details>

**Impact:** Can increase contract size and complexity.

**Recommended Mitigation:** Consider using or removing the unused errors.


### [L-4] PUSH0 Opcode

**Description:** The primary concern identified in the smart contracts relates to the Solidity compiler version used, specifically pragma solidity 0.8.20;. This version, along with every version after 0.8.19, introduces the use of the PUSH0 opcode. This opcode is not universally supported across all Ethereum Virtual Machine (EVM)-based Layer 2 (L2) solutions. For instance, ZKSync, one of the targeted platforms for this protocol's deployment, does not currently support the PUSH0 opcode.

The consequence of this incompatibility is that contracts compiled with Solidity versions higher than 0.8.19 may not function correctly or fail to deploy on certain L2 solutions.

**Impact:** The impact of using a Solidity compiler version that includes the PUSH0 opcode is significant for a protocol intended to operate across multiple EVM-based chains. Chains that do not support this opcode will not be able to execute the contracts as intended, resulting in a range of issues from minor malfunctions to complete deployment failures. This limitation directly affects the protocol's goal of wide compatibility and interoperability, potentially excluding it from deployment on key L2 solutions like ZKsync.

**Recommended Mitigation:** To mitigate this issue and ensure broader compatibility with various EVM-based L2 solutions, it is recommended to downgrade the Solidity compiler version used in the smart contracts to 0.8.19. This version does not utilize the PUSH0 opcode and therefore maintains compatibility with a wider range of L2 solutions, including ZKsync.


### [L-5] No `address(0)` check in `VaultGuardiansBase::_becomeTokenGuardian`

**Description:** The `s_guardians` mapping entry for a guardian is assigned a vault address that can possibly be address(0) if there isn't a check to guard for this possibility.

The functions (becomeGuardian and becomeTokenGuardian) are actually calling _becomeTokenGuardian and generate a non-zero address via new VaultShares(...). So here the contract logic and the `private` visibility help in guarding against assigning an address(0), but there are some edge cases when this could happen, like if the contract is upgraded and new functions or new logic is added.

```js
s_guardians[msg.sender][token] = IVaultShares(address(tokenVault));
```
**Impact:** The primary impact of the missing address(0) check in _becomeTokenGuardian is a potential for Corrupted State leading to a localized Denial of Service (DoS), which is only possible if the contract is upgraded, or if another internal function is added that fails to validate the input.

**Recommended Mitigation:** Add address(0) check before assigning a new address to the guardian mapping entry.

```diff
function _becomeTokenGuardian(
        IERC20 token,
        VaultShares tokenVault
    ) private returns (address) {
+       if(IVaultShares(address(tokenVault) == address(0) {
+          revert VaultGuardiansBase__InvalidAddress();   
        s_guardians[msg.sender][token] = IVaultShares(address(tokenVault)); 
        })
        //...
    }
```




### [I-1] Consider cleaning repo 

**Description:** There are unused files: `IVaultGuardians`, `InvestableUniverseAdapter`

**Impact:** Can increase audit complexity

**Recommended Mitigation:** Consider deleting unused files and data


### [I-2] Insufficient test coverage 

![alt text](image.png)

**Recommended Mitigation:** Aim to get test coverage up to over 90% for all files and improve Branch testing.


### [G-1] Functions marked `public` are not used internally

**Description:** A function is declared as `public` when it can be declared as external. The `public` visibility forces the compiler to generate code that copies all function arguments from calldata to memory (specifically, into the free memory pointer region) when the function is called.

This copying operation generates a significant gas consumption for every function call. When the function is only intended to be called by external accounts (EOAs) or other contracts, and not internally by other functions within the same contract. 

**Impact:** Using `public` leads to waste of gas, directly increasing the transaction cost for the user.

**Recommended Mitigation:** Change visibilty from `public` to `external`, if not used internally.