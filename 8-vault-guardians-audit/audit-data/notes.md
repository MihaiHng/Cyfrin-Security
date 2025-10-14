Commit hash: 0600272180b6b6103f523b0ef65b070064158303

Scope: src/

Test Coverage: Ok, Branches 56.52% - can be better

![alt text](image.png)

slither:

INFO:Detectors:
AaveAdapter._aaveDivest(IERC20,uint256) (src/protocol/investableUniverseAdapters/AaveAdapter.sol#42-48) ignores return value by i_aavePool.withdraw({asset:address(token),amount:amount,to:address(this)}) (src/protocol/investableUniverseAdapters/AaveAdapter.sol#43-47)
Reference: https://github.com/crytic/slither/wiki/Detector-Documentation#unused-return
