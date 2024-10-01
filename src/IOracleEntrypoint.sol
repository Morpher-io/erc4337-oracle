// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

interface IOracleEntrypoint {
    function consumeData(
        address _provider,
        bytes32 _dataKey
    ) external payable returns (bytes32);

    function prices(address _provider, bytes32 _dataKey) external view returns(uint256);
}