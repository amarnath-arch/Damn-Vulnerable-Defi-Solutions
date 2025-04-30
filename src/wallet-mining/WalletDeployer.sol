// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeProxyFactory} from "@safe-global/safe-smart-account/contracts/proxies/SafeProxyFactory.sol";

/**
 * @notice A contract that allows deployers of Gnosis Safe wallets to be rewarded.
 *         Includes an optional authorization mechanism to ensure only expected accounts
 *         are rewarded for certain deployments.
 */
contract WalletDeployer {
    // Addresses of a Safe factory and copy on this chain
    SafeProxyFactory public immutable cook; // it is the proxy factorty
    address public immutable cpy; // singleton copy ??

    uint256 public constant pay = 1 ether; // pay is 1 ether
    address public immutable chief = msg.sender; // is the deployer of the wallet factoryt
    address public immutable gem; // don't know ( gem is the token address )

    address public mom;
    address public hat;

    error Boom();

    constructor(address _gem, address _cook, address _cpy) {
        gem = _gem;
        cook = SafeProxyFactory(_cook);
        cpy = _cpy;
    }

    /**
     * @notice Allows the chief to set an authorizer contract.
     */
    function rule(address _mom) external {
        //@audit-info mom can only be set once
        if (msg.sender != chief || _mom == address(0) || mom != address(0)) {
            revert Boom();
        }
        mom = _mom; // this is to set the mom variable in the contract
    }

    /**
     * @notice Allows the caller to deploy a new Safe account and receive a payment in return. //@audit-info so there should be upgradable authorization.
     *         If the authorizer is set, the caller must be authorized to execute the deployment
     */
    function drop(address aim, bytes memory wat, uint256 num) external returns (bool) {
        if (mom != address(0) && !can(msg.sender, aim)) {
            return false;
        }
        // cpy - singleton copy, wat -> initlaizer data , num -> nonce
        // aim is the address that is to be aimed.

        if (address(cook.createProxyWithNonce(cpy, wat, num)) != aim) {
            return false;
        }

        // balance of address(this) >= pay

        if (IERC20(gem).balanceOf(address(this)) >= pay) {
            IERC20(gem).transfer(msg.sender, pay);
        }
        return true;
    }

    function canI(address u, address a) public view returns (bool y) {
        assembly {
            let m := sload(0)
            if iszero(extcodesize(m)) { stop() }
            let ptr := mload(0x40)
            mstore(0x40, add(ptr, 0x44))
            mstore(ptr, shl(0xe0, 0x4538c4eb))
            mstore(add(ptr, 0x04), u)
            mstore(add(ptr, 0x24), a)
            if iszero(staticcall(gas(), m, ptr, 0x44, ptr, 0x20)) { stop() }
            y := mload(ptr)
        }
    }

    function can(address u, address a) public view returns (bool y) {
        // u-> my address, a-> to be aime
        assembly {
            let m := sload(0) // this is mom
            if iszero(extcodesize(m)) { stop() } // checking if mom is deployed or not
            let p := mload(0x40) // free mem pointer
            mstore(0x40, add(p, 0x44)) // we are updating the free mem pointer
            mstore(p, shl(0xe0, 0x4538c4eb))
            mstore(add(p, 0x04), u)
            mstore(add(p, 0x24), a)
            if iszero(staticcall(gas(), m, p, 0x44, p, 0x20)) { stop() }
            y := mload(p)
        }
    }
}
