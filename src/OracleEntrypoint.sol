//SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

contract OracleEntrypoint {
    mapping(address => uint256) public deposits;
    mapping(address => uint256) public nonces;

    // provider => requester => data_key => data_value
    // data_value encoding standard is managed by provider and requester contract
    // eg. for price data: 6 bytes timestamp, 1 byte decimals, 25 bytes price integer
    mapping(address => mapping(address => mapping(bytes32 => bytes32))) data;

    // provider => data_key => wei
    mapping(address => mapping(bytes32 => uint256)) public prices;

    event DataConsumed(address provider, address requester, bytes32 dataKey);

    mapping(address => bool) public providerIsBurned;

    function deposit(address _target) public payable {
        deposits[_target] += msg.value;
    }

    // a one way functionality to burn a provider.
    // in case a privat key gets compromised
    // nobody can use that anymore in the oracle to
    // write new data points.
    function setProviderIsBurned() public {
        providerIsBurned[msg.sender] = true;
    }

    function setPrice(
        address _provider,
        uint256 _nonce,
        bytes32 _dataKey,
        uint256 _price,
        bytes32 _r,
        bytes32 _s,
        uint8 _v
    ) public {
        require(
            nonces[_provider] == _nonce,
            "OracleEntrypoint: Invalid nonce for provider!"
        );
        require(
            providerIsBurned[_provider] == false,
            "OracleEntrypoint: Provider is burned, cannot update"
        );
        nonces[_provider]++;
        bytes memory prefix = "\x19Oracle Signed Price Change:\n148";
        bytes32 prefixedHashMessage = keccak256(
            abi.encodePacked(
                prefix,
                abi.encodePacked(
                    block.chainid,
                    _provider,
                    _nonce,
                    _dataKey,
                    _price
                )
            )
        );
        address signer = ecrecover(prefixedHashMessage, _v, _r, _s);

        require(
            _provider == signer,
            "OracleEntrypoint: Invalid price change signatures"
        );
        prices[_provider][_dataKey] = _price;
    }

    // _requester is not the end user but the consuming contract (eg. trading contract)
    // so the end user will need to specify the consuming contract in the signed request
    // _provider is the provider EOA which signs the data (NOT HIS SMART WALLET!),
    // the message.sender here is the ERC4337 entrypoint address
    function storeData(
        address _provider,
        address _requester,
        uint256 _nonce,
        bytes32 _dataKey,
        bytes32 _dataValue,
        bytes32 _r,
        bytes32 _s,
        uint8 _v
    ) public {
        require(
            nonces[_provider] == _nonce,
            "OracleEntrypoint: Invalid nonce for provider!"
        );
        require(
            providerIsBurned[_provider] == false,
            "OracleEntrypoint: Provider is burned, cannot update"
        );

        nonces[_provider]++;
        bool verified = _checkProviderSignature(
            _provider,
            _requester,
            _nonce,
            _dataKey,
            _dataValue,
            _v,
            _r,
            _s
        );
        require(verified, "OracleEntrypoint: Invalid provider signature!");
        data[_provider][_requester][_dataKey] = _dataValue;
    }

    function consumeData(
        address _provider,
        bytes32 _dataKey
    ) public payable returns (bytes32) {
        deposits[msg.sender] += msg.value;
        uint256 price = prices[_provider][_dataKey];
        require(
            deposits[msg.sender] >= price,
            "OracleEntrypoint: Not enough money to pay for data!"
        );
        payable(_provider).transfer(price);
        deposits[msg.sender] = uint256(deposits[msg.sender] - price);
        emit DataConsumed(_provider, msg.sender, _dataKey);
        return data[_provider][msg.sender][_dataKey];
    }

    function _checkProviderSignature(
        address _provider,
        address _requester,
        uint256 _nonce,
        bytes32 _dataKey,
        bytes32 _dataValue,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) public view returns (bool) {
        bytes memory prefix = "\x19Oracle Signed Data Op:\n168";
        bytes32 prefixedHashMessage = keccak256(
            abi.encodePacked(
                prefix,
                abi.encodePacked(
                    block.chainid,
                    _provider,
                    _nonce,
                    _requester,
                    _dataKey,
                    _dataValue
                )
            )
        );
        address signer = ecrecover(prefixedHashMessage, _v, _r, _s);
        return signer == _provider;
    }
}
