//SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import {DemoStablecoin} from "../src/example/DemoStablecoin.sol";
import {DataDependent} from "../src/DataDependent.sol";
import {OracleEntrypoint} from "../src/OracleEntrypoint.sol";
error ErrMaxMintingLimit(uint remaining, uint exceeded);

contract USPDTokenTest is Test {
    DemoStablecoin stablecoinToken;
    OracleEntrypoint oracle;
    Account provider; // = bundler

    function setUp() public {
        oracle = new OracleEntrypoint();
        provider = makeAccount("provider");
        // emit log_address(provider.addr);
        stablecoinToken = new DemoStablecoin(address(oracle), provider.addr);

        // set price for bid data
        bytes memory prefix = "\x19Oracle Signed Price Change:\n148";
        bytes32 prefixedHashMessage = keccak256(
            abi.encodePacked(
                prefix,
                abi.encodePacked(
                    block.chainid,
                    provider.addr,
                    uint256(0),
                    stablecoinToken.ETH_USDT(),
                    uint256(0.001 ether)
                )
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            provider.key,
            prefixedHashMessage
        );
         
        vm.prank(provider.addr);
        oracle.setPrice(provider.addr, 0, stablecoinToken.ETH_USDT(), 0.001 ether, r, s, v);

        // set price for ask data
        bytes32 prefixedHashMessage2 = keccak256(
            abi.encodePacked(
                prefix,
                abi.encodePacked(
                    block.chainid,
                    provider.addr,
                    uint256(1),
                    stablecoinToken.ETH_USDT(),
                    uint256(0.001 ether)
                )
            )
        );

        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(
            provider.key,
            prefixedHashMessage2
        );

        vm.prank(provider.addr);
        oracle.setPrice(provider.addr, 1, stablecoinToken.ETH_USDT(), 0.001 ether, r2, s2, v2);
    }

    function testMinting() public {
        vm.warp(100000000);
        // first, we get the data requirements for the mint call
        DataDependent.DataRequirement[] memory dataSources = stablecoinToken.requirements(
            bytes4(keccak256("mint(address)"))
        ); // mint selector

        // now, for each requirement the bundler will push the data in
        for (uint256 i = 0; i < dataSources.length; i++) {
            assertEq(dataSources[i].provider, provider.addr); // provider should be the bundler :)
            uint256 value = block.timestamp * 1000 * 2 ** (8 * 26); // timestamp
            value += 18 * 2 ** (8 * 25); // decimals
            value += 3000 * 10 ** 18; // price

            bytes memory prefix = "\x19Oracle Signed Data Op:\n168";
           bytes32 prefixedHashMessage = keccak256(
            abi.encodePacked(
                prefix,
                abi.encodePacked(
                    block.chainid,
                    provider.addr,
                    uint256(2),
                    dataSources[i].requester,
                    dataSources[i].dataKey,
                    bytes32(value)
                )
            ));

            (uint8 v, bytes32 r, bytes32 s) = vm.sign(
                provider.key,
                prefixedHashMessage
            );

            vm.prank(provider.addr);
            oracle.storeData(provider.addr, dataSources[i].requester, 2, dataSources[i].dataKey, bytes32(value), r, s, v);
        }

        address alice = makeAddr("alice");
        // emit log_address(alice);
        vm.deal(alice, 1 ether);
        vm.startPrank(alice);
        stablecoinToken.mint{value: 1 ether}(alice);
        assertEq(
            stablecoinToken.balanceOf(alice),
            (0.999 ether * 3000)
        );
    }
}
