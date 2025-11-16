// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ITrap {
    /// @notice Collect any on-chain data the trap needs
    function collect() external view returns (bytes memory);

    /// @notice Decide whether to respond based on one or more prior collect blobs
    function shouldRespond(bytes[] calldata data) external returns (bool, bytes memory);
}

