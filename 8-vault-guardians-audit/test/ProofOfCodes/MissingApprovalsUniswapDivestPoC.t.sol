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

contract UniswapLP is ERC20Mock {
    // Inherit ERC20Mock: free mint/burn helpers already available
}

contract UniswapFactory {
    address public immutable pair;

    constructor(address pair_) {
        pair = pair_;
    }

    function getPair(address, address) external view returns (address) {
        return pair;
    }
}

// This router is Uniswap-V2-shaped enough for VaultShares.UniswapAdapter
contract UniswapRouter {
    address private _factory;
    UniswapLP private _lp;

    constructor(address factory_, address lp_) {
        _factory = factory_;
        _lp = UniswapLP(lp_);
    }

    function factory() external view returns (address) {
        return _factory;
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 /* amountOutMin */,
        address[] calldata path,
        address to,
        uint256 /* deadline */
    ) external returns (uint256[] memory amounts) {
        // pull input
        ERC20Mock(path[0]).transferFrom(msg.sender, address(this), amountIn);

        // use mint to avoid needing pre-funding
        ERC20Mock(path[1]).mint(amountIn, to);

        amounts = new uint256[](path.length);
        amounts[0] = amountIn;
        amounts[1] = amountIn;
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 /* amountAMin */,
        uint256 /* amountBMin */,
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

        _lp.mint(100 ether, to);

        return (amountADesired, amountBDesired, 100 ether);
    }

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 /* amountAMin */,
        uint256 /* amountBMin */,
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
        // For the PoC we don’t simulate any lending, just acknowledge the call.
        if (amount > 0) {
            ERC20Mock(aTokenAddr).mint(amount, onBehalfOf);
        }
    }
}

// ---------------------------
//       Test Contract
// ---------------------------

contract MissingApprovalsUniswapDivestPoC_Test is Test {
    VaultShares private vault;
    ERC20Mock private asset;
    ERC20Mock private tokenOne;
    ERC20Mock private mockWETH; // distinct mock WETH
    ERC20Mock private awethTokenMock;

    UniswapRouter router;
    UniswapLP lp;

    error ERC20InsufficientAllowance(address, uint256, uint256);

    function setUp() public {
        asset = new ERC20Mock();
        tokenOne = new ERC20Mock();
        mockWETH = new ERC20Mock(); // distinct mock WETH
        awethTokenMock = new ERC20Mock();

        MockAavePool pool = new MockAavePool(address(awethTokenMock));

        // LP + Factory + Router
        lp = new UniswapLP();
        UniswapFactory factory = new UniswapFactory(address(lp));
        router = new UniswapRouter(address(factory), address(lp));

        // Build constructor data
        IVaultShares.ConstructorData memory c = IVaultShares.ConstructorData({
            asset: asset,
            vaultName: "PoC Vault",
            vaultSymbol: "POC",
            guardian: address(this),
            allocationData: IVaultData.AllocationData({
                holdAllocation: 0,
                uniswapAllocation: 1000,
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
        vm.label(address(factory), "Factory");
        vm.label(address(router), "Router");
        vm.label(address(lp), "LP");
    }

    function test_MissingApprovalsUniswapDivestResultsInRevert() public {
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
        vault.deposit(depositAmt, user);
        vm.stopPrank();

        uint256 currentAllowance = lp.allowance(
            address(vault),
            address(router)
        );
        uint256 requiredAllowance = lp.balanceOf(address(vault));

        console.log("Current allowance:", currentAllowance);
        console.log("Required allowance:", requiredAllowance);

        // If we call redeem(), expectRevert wont's be able to pick up the revert, because it happens during a nested call
        // expectRevert checks the top level call for revert
        // removeLiquidity() and swapExactTokensForTokens() are nested calls inside redeem() which is the top call, that's why removeLiquidity() is simulated separatelly here

        // Next removeLiquidity() attempt should revert because of insufficient allowance
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC20InsufficientAllowance.selector,
                address(router),
                currentAllowance,
                requiredAllowance
            )
        );

        vm.startPrank(address(vault));
        router.removeLiquidity(
            address(asset),
            address(mockWETH),
            depositAmt,
            0,
            0,
            user,
            1
        );
        vm.stopPrank();
    }
}
