// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IUniswapV2Router01} from "../../../src/vendor/IUniswapV2Router01.sol";
import {IUniswapV2Factory} from "../../../src/vendor/IUniswapV2Factory.sol";
import {UniswapV2PairMockInvariant} from "./UniswapV2PairMockInvariant.sol";

contract UniswapV2RouterMockInvariant is IUniswapV2Router01 {
    address public override factory;
    address public override WETH;

    constructor(address _factory, address _weth) {
        factory = _factory;
        WETH = _weth;
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256, // amountAMin
        uint256, // amountBMin
        address to,
        uint256 // deadline
    )
        external
        override
        returns (uint256 amountA, uint256 amountB, uint256 liquidity)
    {
        address pair = IUniswapV2Factory(factory).getPair(tokenA, tokenB);
        require(pair != address(0), "Pair does not exist");

        // Move tokens from vault into pair
        IERC20(tokenA).transferFrom(msg.sender, pair, amountADesired);
        IERC20(tokenB).transferFrom(msg.sender, pair, amountBDesired);

        // Mint LP tokens
        liquidity = UniswapV2PairMockInvariant(pair).mintLiquidity(
            amountADesired,
            amountBDesired,
            to
        );

        return (amountADesired, amountBDesired, liquidity);
    }

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256,
        uint256,
        address to,
        uint256
    ) external override returns (uint256 amountA, uint256 amountB) {
        address pair = IUniswapV2Factory(factory).getPair(tokenA, tokenB);
        require(pair != address(0), "Pair does not exist");

        // Burn LP tokens and return underlying
        (amountA, amountB) = UniswapV2PairMockInvariant(pair).burnLiquidity(
            liquidity,
            msg.sender,
            to
        );
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256
    ) external override returns (uint256[] memory amounts) {
        require(path.length == 2, "Only simple pairs");

        address tokenIn = path[0];
        address tokenOut = path[1];

        // take tokenIn
        IERC20(tokenIn).transferFrom(msg.sender, to, amountIn);

        // "mint" output for user
        IERC20(tokenOut).transfer(to, amountOutMin);

        amounts = new uint256[](2);
        amounts[0] = amountIn;
        amounts[1] = amountOutMin;
    }

    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256
    ) external override returns (uint256[] memory amounts) {
        require(path.length == 2, "Only simple pairs");

        address tokenIn = path[0];
        address tokenOut = path[1];

        // take max input
        IERC20(tokenIn).transferFrom(msg.sender, to, amountInMax);

        // deliver exact output
        IERC20(tokenOut).transfer(to, amountOut);

        amounts = new uint256[](2);
        amounts[0] = amountInMax;
        amounts[1] = amountOut;
    }
}
