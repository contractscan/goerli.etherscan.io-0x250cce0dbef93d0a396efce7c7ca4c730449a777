// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

// https://mirror.xyz/0x3dbb624861C0f62BdE573a33640ca016E4c65Ff7/q7C21iEF1eZkXrlZvgXN_1xSYiKZXBvrB2yFkSknsYU
contract BatcherXY {
    // https://github.com/ethereum/EIPs/blob/master/EIPS/eip-1167.md
    address public immutable original;
    address public immutable deployer;
    uint256 public n;

    bytes32 byteCode;

    event LogCreateProxy(address proxy);

    constructor(uint256 _n) {
        original = address(this);
        deployer = msg.sender;
        createProxies(_n);
    }

    function createProxies(uint256 _n) internal {
        bytes memory miniProxy = bytes.concat(
            bytes20(0x3D602d80600A3D3981F3363d3d373d3D3D363d73),
            bytes20(address(this)),
            bytes15(0x5af43d82803e903d91602b57fd5bf3)
        );
        byteCode = keccak256(abi.encodePacked(miniProxy));
        address proxy;
        uint256 oldN = n;
        for (uint256 i = 0; i < _n; i++) {
            bytes32 salt = keccak256(abi.encodePacked(msg.sender, i + oldN));
            assembly {
                proxy := create2(0, add(miniProxy, 32), mload(miniProxy), salt)
            }

            emit LogCreateProxy(proxy);
        }
        // update n
        n = oldN + _n;
    }

    function callback(address target, bytes memory data) external {
        require(
            msg.sender == original,
            "Only original can call this function."
        );
        (bool success, ) = target.call(data);
        require(success, "Transaction failed.");
    }

    function proxyFor(address sender, uint256 i)
        public
        view
        returns (address proxy)
    {
        bytes32 salt = keccak256(abi.encodePacked(sender, i));
        proxy = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(hex"ff", address(this), salt, byteCode)
                    )
                )
            )
        );
    }

    // increase proxy count
    function increase(uint256 _n) external {
        require(
            msg.sender == deployer,
            "Only deployer can call this function."
        );
        createProxies(_n);
    }

    function execute(
        uint256 _start,
        uint256 _count,
        address target,
        bytes memory data
    ) external {
        require(
            msg.sender == deployer,
            "Only deployer can call this function."
        );
        for (uint256 i = _start; i < _start + _count; i++) {
            address proxy = proxyFor(msg.sender, i);
            BatcherXY(proxy).callback(target, data);
        }
    }
}