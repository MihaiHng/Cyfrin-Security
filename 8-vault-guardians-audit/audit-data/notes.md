Commit hash: 0600272180b6b6103f523b0ef65b070064158303

Scope: src/

Roles: Vault Guardian 
       User

Test Coverage: Ok, Branches 56.52% - can be better

![alt text](image.png)

slither:

INFO:Detectors:
AaveAdapter._aaveDivest(IERC20,uint256) (src/protocol/investableUniverseAdapters/AaveAdapter.sol#42-48) ignores return value by i_aavePool.withdraw({asset:address(token),amount:amount,to:address(this)}) (src/protocol/investableUniverseAdapters/AaveAdapter.sol#43-47)
Reference: https://github.com/crytic/slither/wiki/Detector-Documentation#unused-return

=>=>=> Check for emiting event on any state change
=>=>=> Check DAO contracts for highs!!!
=>=>=> Check where the vault guardians can move funds, to what addresses
=>=>=> Check for proposal execution delays, otherwise might be space for ill intended proposals instant execution`

Can a vault have more than 1 guardian?

Low: Clean repo before submitting data for audit/review


