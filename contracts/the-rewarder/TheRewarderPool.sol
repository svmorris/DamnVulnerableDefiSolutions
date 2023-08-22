// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "solady/src/utils/FixedPointMathLib.sol";
import "solady/src/utils/SafeTransferLib.sol";
import { RewardToken } from "./RewardToken.sol";
import { AccountingToken } from "./AccountingToken.sol";

/**
 * @title TheRewarderPool
 * @author Damn Vulnerable DeFi (https://damnvulnerabledefi.xyz)
 */
contract TheRewarderPool {
    using FixedPointMathLib for uint256;

    // Minimum duration of each round of rewards in seconds
    uint256 private constant REWARDS_ROUND_MIN_DURATION = 5 days;
    
    uint256 public constant REWARDS = 100 ether;

    // Token deposited into the pool by users
    address public immutable liquidityToken;

    // Token used for internal accounting and snapshots
    // Pegged 1:1 with the liquidity token
    AccountingToken public immutable accountingToken;

    // Token in which rewards are issued
    RewardToken public immutable rewardToken;

    uint128 public lastSnapshotIdForRewards;
    uint64 public lastRecordedSnapshotTimestamp;
    uint64 public roundNumber; // Track number of rounds
    mapping(address => uint64) public lastRewardTimestamps;

    error InvalidDepositAmount();

    constructor(address _token) {
        // Assuming all tokens have 18 decimals
        // many funny looking tokens
        liquidityToken = _token;
        accountingToken = new AccountingToken();
        rewardToken = new RewardToken();

        _recordSnapshot();
    }

    /**
     * @notice Deposit `amount` liquidity tokens into the pool, minting accounting tokens in exchange.
     *         Also distributes rewards if available.
     * @param amount amount of tokens to be deposited
     */
    function deposit(uint256 amount) external {
        // the amount cannot be 0. With unsigned it cannot be negative either
        if (amount == 0) {
            revert InvalidDepositAmount();
        }

        // mint the correct amount of accounting tokens
        accountingToken.mint(msg.sender, amount);
        // distribute the rewards
        distributeRewards();

        // Take the liquidity token money from the sender
        // Presumably some of this has to be approved
        SafeTransferLib.safeTransferFrom(
            liquidityToken,
            msg.sender,
            address(this),
            amount
        );
    }

    function withdraw(uint256 amount) external {
        // Withdrawing tokens involves burning the accounting token and sending
        // the caller their the same amount of liquidity tokens
        accountingToken.burn(msg.sender, amount);
        SafeTransferLib.safeTransfer(liquidityToken, msg.sender, amount);
    }

    function distributeRewards() public returns (uint256 rewards) {
        // If its time for a new reward, then create some sort of snapshot
        if (isNewRewardsRound()) {
            _recordSnapshot();
        }

        // if I understand correctly, this takes the total pot and the callers deposit
        // the last time a snapshot was called.

        // In other words, if the caller deposits when its not time yet, the new deposits
        // will not be counted towards their rewards
        uint256 totalDeposits = accountingToken.totalSupplyAt(lastSnapshotIdForRewards);
        uint256 amountDeposited = accountingToken.balanceOfAt(msg.sender, lastSnapshotIdForRewards);

        if (amountDeposited > 0 && totalDeposits > 0) {
            // Use some sort of algorithm to figure out how gets how much deposits
            // if we want to get the most, presumably we must have the most amount
            // of accounting tokens.
            rewards = amountDeposited.mulDiv(REWARDS, totalDeposits);

            // If the rewards are greater than 0 and the user hasn't received them yet
            if (rewards > 0 && !_hasRetrievedReward(msg.sender)) {
                // mint some of the tokens for the caller and set the last time 
                // they were rewarded
                rewardToken.mint(msg.sender, rewards);
                lastRewardTimestamps[msg.sender] = uint64(block.timestamp);
            }
        }
    }

    function _recordSnapshot() private {
        // create a snapshot of all accounts and store it in this variable
        lastSnapshotIdForRewards = uint128(accountingToken.snapshot());
        lastRecordedSnapshotTimestamp = uint64(block.timestamp);
        // this prevents the over-underflow checker from running
        // this might be useful
        unchecked {
            ++roundNumber;
        }
    }

    function _hasRetrievedReward(address account) public view returns (bool) { // change back to private
        return (
            lastRewardTimestamps[account] >= lastRecordedSnapshotTimestamp
                && lastRewardTimestamps[account] <= lastRecordedSnapshotTimestamp + REWARDS_ROUND_MIN_DURATION
        );
    }

    function isNewRewardsRound() public view returns (bool) {
        // its only last snapshot if its been 5 days since the last snapshot
        return block.timestamp >= lastRecordedSnapshotTimestamp + REWARDS_ROUND_MIN_DURATION;
    }
}
