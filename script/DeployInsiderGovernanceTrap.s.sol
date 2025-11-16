// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {InsiderGovernanceManipulationTrap} from "../src/InsiderGovernanceManipulationTrap.sol";
import {InsiderGovernanceResponder} from "../src/InsiderGovernanceResponder.sol";

contract DeployInsiderGovernanceTrapScript is Script {
    function run() external {
        // Load private key from env: PRIVATE_KEY
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy trap
        InsiderGovernanceManipulationTrap trap = new InsiderGovernanceManipulationTrap();

        // 2. Deploy responder (pass a guardian address, or zero if none yet)
        // Replace with your guardian / pauser contract if available
        address guardianAddress = address(0);
        InsiderGovernanceResponder responder = new InsiderGovernanceResponder(guardianAddress);

        vm.stopBroadcast();

        console2.log("InsiderGovernanceManipulationTrap deployed at:", address(trap));
        console2.log("InsiderGovernanceResponder deployed at:", address(responder));
    }
}

