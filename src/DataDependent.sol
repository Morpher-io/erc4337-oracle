//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IOracleEntrypoint} from "./IOracleEntrypoint.sol";

// defines a standardized call to know if contract functions requires oralce data

abstract contract DataDependent {
    struct DataRequirement {
        address provider;
        address requester;
        bytes32 dataKey;
    }
    struct ResponseWithExpenses {
        uint value;
        uint expenses;
    }

    function requirements(
        bytes4 _selector
    ) external virtual view returns (DataRequirement[] memory);


    //todo: potentially limit the timestamp
    function _invokeOracle(address oracle, address _provider, bytes32 _key) internal returns (ResponseWithExpenses memory) {
        uint expenses = IOracleEntrypoint(oracle).prices(_provider, _key);
        // pay the oracle now, then get the funds later from sender as you wish (eg. deduct from msg.value)
        bytes32 response = IOracleEntrypoint(oracle).consumeData{value: expenses}(_provider, _key);
        uint256 asUint = uint256(response);
        uint256 timestamp = asUint >> (26 * 8);
        // in this example we want the price to be fresh
        require(timestamp > 1000 * (block.timestamp - 30), "MorpherOracle-DataDependent: Timestamp too small, data too old, aborting!");
        uint8 decimals = uint8((asUint >> (25 * 8)) - timestamp * (2 ** 8));
        // in this example we expect a response with 18 decimals
        require(decimals == 18, "MorpherOracle-DataDependent: Oracle response with wrong decimals, aborting!");
        uint256 price = uint256(
            asUint - timestamp * (2 ** (26 * 8)) - decimals * (2 ** (25 * 8))
        );
        return ResponseWithExpenses(price, expenses);
    }
}
