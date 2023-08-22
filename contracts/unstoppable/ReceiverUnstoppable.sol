// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";
import "solmate/src/auth/Owned.sol";
import { UnstoppableVault, ERC20 } from "../unstoppable/UnstoppableVault.sol";

/**
 * @title ReceiverUnstoppable
 * @author Damn Vulnerable DeFi (https://damnvulnerabledefi.xyz)
 */
contract ReceiverUnstoppable is Owned, IERC3156FlashBorrower {
    UnstoppableVault private immutable pool;

    error UnexpectedFlashLoan();

    constructor(address poolAddress) Owned(msg.sender) {
        // Get an instance of the unstoppable vault
        pool = UnstoppableVault(poolAddress);
    }

    // when a flashloan is called
    function onFlashLoan(
        address initiator,
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata
    ) external returns (bytes32) {
        // 'initiator' has to be this address
        // The sender has to be the vault 'pool'
        //    in other words, only the UnstoppableVault can call this function
        // The token to be borrowed has to be the one that the pool returns when asset() is called
        // The borrow fee cannot be 0
        if (initiator != address(this) || msg.sender != address(pool) || token != address(pool.asset()) || fee != 0)
            revert UnexpectedFlashLoan();


        // give the pool permission to withdraw some from my erc20 tokens?
        ERC20(token).approve(address(pool), amount);

        // return the magic value
        return keccak256("IERC3156FlashBorrower.onFlashLoan");
    }

    // this function is probably called by the contract owner to get a flashloan
    // from the pool
    function executeFlashLoan(uint256 amount) external onlyOwner {
        address asset = address(pool.asset());
        pool.flashLoan(
            this,
            asset,
            amount,
            bytes("")
        );
    }
}
