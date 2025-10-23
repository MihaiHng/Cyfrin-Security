---
title: Vault Guardians Audit Report
author: mhng
date: October 7, 2025
header-includes:
  - \usepackage{titling}
  - \usepackage{graphicx}
---
\begin{titlepage}
    \centering
    \begin{figure}[h]
        \centering
        \includegraphics[width=0.5\textwidth]{logo.pdf} 
    \end{figure}
    \vspace*{2cm}
    {\Huge\bfseries Boss Bridge Initial Audit Report\par}
    \vspace{1cm}
    {\Large Version 0.1\par}
    \vspace{2cm}
    {\Large\itshape Cyfrin.io\par}
    \vfill
    {\large \today\par}
\end{titlepage}

\maketitle

# Vault Guardians Audit Report

Prepared by: mhng
Lead Auditors: mhng

- [mhng](https://github.com/MihaiHng)

Assisting Auditors:

- None

# Table of contents
<details>

<summary>See table</summary>

- [Vault Guardians Audit Report](#vault-guardians-audit-report)
- [Table of contents](#table-of-contents)
- [About mhng](#about-mhng)
- [Disclaimer](#disclaimer)
- [Risk Classification](#risk-classification)
- [Audit Details](#audit-details)
  - [Scope](#scope)
- [Protocol Summary](#protocol-summary)
  - [Roles](#roles)
- [Executive Summary](#executive-summary)
  - [Issues found](#issues-found)
- [Findings](#findings)
  - [High](#high)
    - [\[H-1\] Users who give tokens approvals to `L1BossBridge` may have those assest stolen](#h-1-users-who-give-tokens-approvals-to-l1bossbridge-may-have-those-assest-stolen)
    

</details>
</br>

# About mhng

# Disclaimer

We are making all efforts to find as many vulnerabilities in the code in the given time period, but we are not holding any  responsibilities for the the findings provided in this document. A security audit is not an endorsement of the underlying business or product. The audit was time-boxed and the review of the code was solely on the security aspects of the solidity implementation of the contracts.

# Risk Classification

|            |        | Impact |        |     |
| ---------- | ------ | ------ | ------ | --- |
|            |        | High   | Medium | Low |
|            | High   | H      | H/M    | M   |
| Likelihood | Medium | H/M    | M      | M/L |
|            | Low    | M      | M/L    | L   |

# Audit Details

**The findings described in this document correspond the following commit hash:**
```
0600272180b6b6103f523b0ef65b070064158303
```

## Scope 

```
./src/
#-- abstract
|   #-- AStaticTokenData.sol
|   #-- AStaticUSDCData.sol
|   #-- AStaticWethData.sol
#-- dao
|   #-- VaultGuardianGovernor.sol
|   #-- VaultGuardianToken.sol
#-- interfaces
|   #-- IVaultData.sol
|   #-- IVaultGuardians.sol
|   #-- IVaultShares.sol
|   #-- InvestableUniverseAdapter.sol
#-- protocol
|   #-- VaultGuardians.sol
|   #-- VaultGuardiansBase.sol
|   #-- VaultShares.sol
|   #-- investableUniverseAdapters
|       #-- AaveAdapter.sol
|       #-- UniswapAdapter.sol
#-- vendor
    #-- DataTypes.sol
    #-- IPool.sol
    #-- IUniswapV2Factory.sol
    #-- IUniswapV2Router01.sol
```

- Solc Version: 0.8.20
- Chain(s) to deploy contract to: Ethereum
- Tokens:
  - weth: https://etherscan.io/token/0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2
  - link: https://etherscan.io/token/0x514910771af9ca656af840dff83e8264ecf986ca
  - usdc: https://etherscan.io/token/0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48

# Protocol Summary

This protocol allows users to deposit certain ERC20s into an [ERC4626 vault](https://eips.ethereum.org/EIPS/eip-4626) managed by a human being, or a `vaultGuardian`. The goal of a `vaultGuardian` is to manage the vault in a way that maximizes the value of the vault for the users who have despoited money into the vault.

You can think of a `vaultGuardian` as a fund manager.

To prevent a vault guardian from running off with the funds, the vault guardians are only allowed to deposit and withdraw the ERC20s into specific protocols. 

- [Aave v3](https://aave.com/) 
- [Uniswap v2](https://uniswap.org/) 
- None (just hold) 

These 2 protocols (plus "none" makes 3) are known as the "investable universe".

The guardian can move funds in and out of these protocols as much as they like, but they cannot move funds to any other address.

The goal of a vault guardian, is to move funds in and out of these protocols to gain the most yield. Vault guardians charge a performance fee, the better the guardians do, the larger fee they will earn. 

Anyone can become a Vault Guardian by depositing a certain amount of the ERC20 into the vault. This is called the `guardian stake`. If a guardian wishes to stop being a guardian, they give out all user deposits and withdraw their guardian stake.

Users can then move their funds between vault managers as they see fit. 

The protocol is upgradeable so that if any of the platforms in the investable universe change, or we want to add more, we can do so.

## User flow

1. User deposits an ERC20 into a guardian's vault
2. The guardian automatically move the funds based on their strategy 
3. The guardian can update the settings of their strategy at any time and move the funds
4. To leave the pool, a user just calls `redeem` or `withdraw`

## The DAO

Guardians can earn DAO tokens by becoming guardians. The DAO is responsible for:
- Updating pricing parameters
- Getting a cut of all performance of all guardians

## Summary

Users can stake some ERC20s to become a vault guardian. Other users can allocate them funds in order to maximize yield. The guardians can move the funds between Uniswap, Aave, or just hold the funds. The guardians are incentivized to maximize yield, as they earn a performance fee.

## Roles

- User: Someone that wants to deposit assets in a vault to maximize yield
- Guardian: Someone that stakes an ERC20 amount to become a Vault Guardian by creating a new vault and are incentivized to maximize yield, by earning a fee.
- Vault Guardian DAO: Organization that controls Vault operations and earns a fee as incentive

# Executive Summary

## Issues found

| Severity | Number of issues found |
| -------- | ---------------------- |
| High     | 0                      |
| Medium   | 0                      |
| Low      | 0                      |
| Info     | 0                      |
| Gas      | 0                      |
| Total    | 0                      |

# Findings