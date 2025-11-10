// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Governor} from "@openzeppelin/contracts/governance/Governor.sol";
import {GovernorCountingSimple} from "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import {GovernorVotes, IVotes} from "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import {GovernorVotesQuorumFraction} from "@openzeppelin/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";

contract VaultGuardianGovernor is
    Governor,
    GovernorCountingSimple,
    GovernorVotes,
    GovernorVotesQuorumFraction
{
    constructor(
        IVotes _voteToken
    )
        Governor("VaultGuardianGovernor")
        GovernorVotes(_voteToken)
        // w@audit-issue Isn't 4% too low? Can someone with a 3-4% allocation make bad intended proposals and execute them?
        GovernorVotesQuorumFraction(4)
    {}

    // w@audit-issue Returns days instead of blocks, Solidity reads seconds => different return value
    function votingDelay() public pure override returns (uint256) {
        return 1 days;
    }

    // w@audit-issue Returns days instead of blocks, Solidity reads seconds => different return value
    function votingPeriod() public pure override returns (uint256) {
        return 7 days;
    }

    // The following functions are overrides required by Solidity.

    function quorum(
        uint256 blockNumber
    )
        public
        view
        override(Governor, GovernorVotesQuorumFraction)
        returns (uint256)
    {
        return super.quorum(blockNumber);
    }
}
