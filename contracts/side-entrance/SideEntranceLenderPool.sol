// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "solady/src/utils/SafeTransferLib.sol";

interface IFlashLoanEtherReceiver {
    function execute() external payable;
}

/**
 * @title SideEntranceLenderPool
 * @author Damn Vulnerable DeFi (https://damnvulnerabledefi.xyz)
 */
contract SideEntranceLenderPool {
    // A mapping that shows how much balance each user has
    mapping(address => uint256) private balances;

    error RepayFailed();

    // some events we could use for debugging maybe?
    event Deposit(address indexed who, uint256 amount);
    event Withdraw(address indexed who, uint256 amount);

    // you can deposit money and that adds to your balance
    function deposit() external payable {
        unchecked {
            balances[msg.sender] += msg.value;
        }
        emit Deposit(msg.sender, msg.value);
    }

    // You can withdraw all of your money at once
    function withdraw() external {
        uint256 amount = balances[msg.sender];

        delete balances[msg.sender];
        emit Withdraw(msg.sender, amount);

        SafeTransferLib.safeTransferETH(msg.sender, amount);
    }

    // you can take out a flashloan
    function flashLoan(uint256 amount) external {
        // checks the balance before of the contract
        uint256 balanceBefore = address(this).balance;

        // does the loan
        IFlashLoanEtherReceiver(msg.sender).execute{value: amount}();

        // checks the balance after the contract
        if (address(this).balance < balanceBefore)
            revert RepayFailed();
    }
}


// Exploit notes
// This seems pretty simple.
// you simply take out the maximum flash loan you could possibly take, and immediately deposit it into your own account
// this makes your balance high, but because the loan just checks its own balance, it will not reject the transaction
// finally you can just withdraw your money
