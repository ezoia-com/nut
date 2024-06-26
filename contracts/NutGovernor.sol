// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "../node_modules/@openzeppelin/contracts/governance/Governor.sol";
import "../node_modules/@openzeppelin/contracts/governance/extensions/GovernorSettings.sol";
import "../node_modules/@openzeppelin/contracts/governance/compatibility/GovernorCompatibilityBravo.sol";
import "../node_modules/@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import "../node_modules/@openzeppelin/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";
import "../node_modules/@openzeppelin/contracts/governance/extensions/GovernorTimelockControl.sol";

/// Based on https://docs.openzeppelin.com/contracts/4.x/governance
contract NutGovernor is
  Governor,
  GovernorCompatibilityBravo,
  GovernorSettings,
  GovernorVotes,
  GovernorVotesQuorumFraction,
  GovernorTimelockControl
{
  constructor(
    IVotes _token, 
    TimelockController _timelock
  ) 
    Governor("NutGovernor") 
    GovernorSettings(3, 7, 1e18) // uint48 initialVotingDelay, uint32 initialVotingPeriod, uint256 initialProposalThreshold
    GovernorVotes(_token) 
    GovernorVotesQuorumFraction(4) 
    GovernorTimelockControl(_timelock) 
  {}
  
  // The functions below are overrides required by Solidity.

  function state(
    uint256 proposalId
  ) public view override(Governor, IGovernor, GovernorTimelockControl) returns (ProposalState) {
    return super.state(proposalId);
  }

  function propose(
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    string memory description
  ) public override(Governor, GovernorCompatibilityBravo, IGovernor) returns (uint256) {
    return super.propose(targets, values, calldatas, description);
  }

  function cancel(
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    bytes32 descriptionHash
  ) public override(Governor, GovernorCompatibilityBravo, IGovernor) returns (uint256) {
    return super.cancel(targets, values, calldatas, descriptionHash);
  }

  function _execute(
    uint256 proposalId,
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    bytes32 descriptionHash
  ) internal override(Governor, GovernorTimelockControl) {
    super._execute(proposalId, targets, values, calldatas, descriptionHash);
  }

  function _cancel(
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    bytes32 descriptionHash
  ) internal override(Governor, GovernorTimelockControl) returns (uint256) {
    return super._cancel(targets, values, calldatas, descriptionHash);
  }

  function _executor() internal view override(Governor, GovernorTimelockControl) returns (address) {
    return super._executor();
  }

  function supportsInterface(
    bytes4 interfaceId
  ) public view override(Governor, IERC165, GovernorTimelockControl) returns (bool) {
    return super.supportsInterface(interfaceId);
  }
  
  function proposalThreshold() public view override(Governor, GovernorSettings) returns (uint256) {
    return super.proposalThreshold();
  }
}
