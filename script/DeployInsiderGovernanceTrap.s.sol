// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {InsiderGovernanceManipulationTrap} from "../src/InsiderGovernanceManipulationTrap.sol";
import {InsiderGovernanceResponder} from "../src/InsiderGovernanceResponder.sol";

contract DeployInsiderGovernanceTrapScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Replace with deployed feeder OR deploy feeder here
        address feederAddress = 0x0000000000000000000000000000000000000001;

        // 1. Deploy trap (FIXED)
        InsiderGovernanceManipulationTrap trap =
            new InsiderGovernanceManipulationTrap(feederAddress);

        // 2. Deploy responder (no args)
        InsiderGovernanceResponder responder =
            new InsiderGovernanceResponder();

        vm.stopBroadcast();

        console2.log("Trap deployed at:", address(trap));
        console2.log("Responder deployed at:", address(responder));
    }
}
