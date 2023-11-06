// SPDX-License-Identifier: None
pragma solidity ^0.8.19;

import {TimelockController as OZTimelockController} from "../node_modules/@openzeppelin/contracts/governance/TimelockController.sol";

contract Timelock is OZTimelockController {
    constructor(
        uint256 minDelay,
        address[] memory proposers,
        address[] memory executors,
        address admin
    ) OZTimelockController(minDelay, proposers, executors, admin) {}
}
