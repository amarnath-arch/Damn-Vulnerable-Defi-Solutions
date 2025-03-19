// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {IERC3156FlashBorrower} from "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";
import {WETH, NaiveReceiverPool} from "./NaiveReceiverPool.sol";

contract FlashLoanReceiver is IERC3156FlashBorrower {
    address private pool;

    constructor(address _pool) {
        pool = _pool;
    }

    function onFlashLoan(address, address token, uint256 amount, uint256 fee, bytes calldata)
        external
        returns (bytes32)
    {
        // did not account for the msg.sender //@audit // or did they account for it

        // sequence of operations:
        // 1. check if the msg.sender is pool or not
        // 2. token is weth or not
        // 3. return amoiunt is amount + fee
        // 4. action
        // 5. approve the pool contract

        assembly {
            // gas savings
            if iszero(eq(sload(pool.slot), caller())) {
                mstore(0x00, 0x48f5c3ed)
                revert(0x1c, 0x04)
            }
        }
        // check if the msg.sender is th is the pool contract or not

        if (token != address(NaiveReceiverPool(pool).weth())) revert NaiveReceiverPool.UnsupportedCurrency();

        uint256 amountToBeRepaid;
        unchecked {
            amountToBeRepaid = amount + fee;
        }

        _executeActionDuringFlashLoan();

        // Return funds to pool
        WETH(payable(token)).approve(pool, amountToBeRepaid);

        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }

    // Internal function where the funds received would be used
    // middle ware when the money will be received
    function _executeActionDuringFlashLoan() internal {}
}
