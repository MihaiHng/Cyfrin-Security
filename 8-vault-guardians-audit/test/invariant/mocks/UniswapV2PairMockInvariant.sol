// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract UniswapV2PairMockInvariant {
    IERC20 public token0;
    IERC20 public token1;

    uint112 private reserve0;
    uint112 private reserve1;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;

    event Mint(address indexed to, uint256 liquidity);
    event Burn(address indexed from, uint256 liquidity);

    constructor(address _token0, address _token1) {
        token0 = IERC20(_token0);
        token1 = IERC20(_token1);
    }

    //    Mint LP Tokens
    function mintLiquidity(
        uint256 amount0,
        uint256 amount1,
        address to
    ) external returns (uint256 liquidity) {
        require(amount0 > 0 || amount1 > 0, "No liquidity");

        // Basic pricing: liquidity = sum
        liquidity = amount0 + amount1;

        reserve0 += uint112(amount0);
        reserve1 += uint112(amount1);

        totalSupply += liquidity;
        balanceOf[to] += liquidity;

        emit Mint(to, liquidity);
    }

    //    Burn LP Tokens
    function burnLiquidity(
        uint256 liquidity,
        address from,
        address to
    ) external returns (uint256 amount0, uint256 amount1) {
        require(balanceOf[from] >= liquidity, "Not enough LP");

        balanceOf[from] -= liquidity;
        totalSupply -= liquidity;

        // Return proportional reserves
        amount0 = (uint256(reserve0) * liquidity) / (totalSupply + liquidity);
        amount1 = (uint256(reserve1) * liquidity) / (totalSupply + liquidity);

        reserve0 -= uint112(amount0);
        reserve1 -= uint112(amount1);

        token0.transfer(to, amount0);
        token1.transfer(to, amount1);

        emit Burn(from, liquidity);
    }

    // Uniswap-required view helpers
    function getReserves() external view returns (uint112, uint112, uint32) {
        return (reserve0, reserve1, 0);
    }
}
