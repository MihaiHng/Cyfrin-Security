// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {VaultGuardians} from "../../../src/protocol/VaultGuardians.sol";
import {VaultGuardianToken} from "../../../src/dao/VaultGuardianToken.sol";
import {VaultGuardianGovernor} from "../../../src/dao/VaultGuardianGovernor.sol";
import {UniswapV2PairMockInvariant} from "../mocks/UniswapV2PairMockInvariant.sol";
import {UniswapV2FactoryMockInvariant} from "../mocks/UniswapV2FactoryMockInvariant.sol";
import {UniswapV2RouterMockInvariant} from "../mocks/UniswapV2RouterMockInvariant.sol";
import {AavePoolMockInvariant} from "../mocks/AavePoolMockInvariant.sol";
import {ERC20Mock} from "../../mocks/ERC20Mock.sol";

abstract contract Base_Test_Invariant is Test {
    VaultGuardians public vaultGuardians;
    VaultGuardianGovernor public vaultGuardianGovernor;
    VaultGuardianToken public vaultGuardianToken;

    ERC20Mock public weth;
    ERC20Mock public usdc;
    ERC20Mock public link;

    UniswapV2PairMockInvariant public pairMock;
    UniswapV2RouterMockInvariant public routerMock;
    UniswapV2FactoryMockInvariant public factoryMock;
    AavePoolMockInvariant public aavePoolMock;
    ERC20Mock public aTokenUSDC;
    ERC20Mock public aTokenWETH;

    function setUp() public virtual {
        // Deploy token mocks
        weth = new ERC20Mock();
        usdc = new ERC20Mock();
        link = new ERC20Mock();

        // Deploy ATokens + Aave mock
        aTokenUSDC = new ERC20Mock();
        aTokenWETH = new ERC20Mock();
        aavePoolMock = new AavePoolMockInvariant();
        aavePoolMock.updateAtokenAddress(address(usdc), address(aTokenUSDC));
        aavePoolMock.updateAtokenAddress(address(weth), address(aTokenWETH));

        // Deploy Uniswap mocks
        factoryMock = new UniswapV2FactoryMockInvariant();
        pairMock = new UniswapV2PairMockInvariant(address(usdc), address(weth));
        factoryMock.updatePairToReturn(
            address(usdc),
            address(weth),
            address(pairMock)
        );

        routerMock = new UniswapV2RouterMockInvariant(
            address(factoryMock),
            address(weth)
        );

        // Deploy VaultGuardians
        vaultGuardianToken = new VaultGuardianToken();
        vaultGuardianGovernor = new VaultGuardianGovernor(vaultGuardianToken);

        vaultGuardians = new VaultGuardians(
            address(aavePoolMock),
            address(routerMock),
            address(weth),
            address(usdc),
            address(link),
            address(vaultGuardianToken)
        );

        vaultGuardians.transferOwnership(address(vaultGuardianGovernor));
        vaultGuardianToken.transferOwnership(address(vaultGuardians));

        // Labels for debugging
        vm.label(address(weth), "WETH_Mock");
        vm.label(address(usdc), "USDC_Mock");
        vm.label(address(link), "LINK_Mock");

        vm.label(address(routerMock), "RouterMockInvariant");
        vm.label(address(factoryMock), "FactoryMockInvariant");
        vm.label(address(pairMock), "PairMockInvariant");
        vm.label(address(aavePoolMock), "AavePoolMockInvariant");
        vm.label(address(aTokenUSDC), "aUSDC_Mock");
    }
}
