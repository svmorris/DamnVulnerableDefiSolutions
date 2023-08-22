// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../DamnValuableTokenSnapshot.sol";
import "./ISimpleGovernance.sol"
;
/**
 * @title SimpleGovernance
 * @author Damn Vulnerable DeFi (https://damnvulnerabledefi.xyz)
 */
contract SimpleGovernance is ISimpleGovernance {

    uint256 private constant ACTION_DELAY_IN_SECONDS = 2 days;
    DamnValuableTokenSnapshot private _governanceToken;
    uint256 private _actionCounter;
    mapping(uint256 => GovernanceAction) private _actions;

    constructor(address governanceToken) {
        // the governance token is different from the loan token
        _governanceToken = DamnValuableTokenSnapshot(governanceToken);
        _actionCounter = 1;
    }

    function queueAction(address target, uint128 value, bytes calldata data) external returns (uint256 actionId) {
        if (!_hasEnoughVotes(msg.sender))
            revert NotEnoughVotes(msg.sender);

        // the target can be the pool
        if (target == address(this))
            revert InvalidTarget();
        
        // the target has to be an address (pool is good)
        if (data.length > 0 && target.code.length == 0)
            revert TargetMustHaveCode();

        actionId = _actionCounter;

        // queue the action?
        _actions[actionId] = GovernanceAction({
            target: target,
            value: value,
            proposedAt: uint64(block.timestamp),
            executedAt: 0,
            data: data
        });

        unchecked { _actionCounter++; }

        emit ActionQueued(actionId, msg.sender);
    }

    function executeAction(uint256 actionId) external payable returns (bytes memory) {
        if(!_canBeExecuted(actionId))
            revert CannotExecute(actionId);

        GovernanceAction storage actionToExecute = _actions[actionId];
        actionToExecute.executedAt = uint64(block.timestamp);

        emit ActionExecuted(actionId, msg.sender);

        (bool success, bytes memory returndata) = actionToExecute.target.call{value: actionToExecute.value}(actionToExecute.data);
        if (!success) {
            if (returndata.length > 0) {
                assembly {
                    revert(add(0x20, returndata), mload(returndata))
                }
            } else {
                revert ActionFailed(actionId);
            }
        }

        return returndata;
    }

    function getActionDelay() external pure returns (uint256) {
        return ACTION_DELAY_IN_SECONDS;
    }

    function getGovernanceToken() external view returns (address) {
        return address(_governanceToken);
    }

    function getAction(uint256 actionId) external view returns (GovernanceAction memory) {
        return _actions[actionId];
    }

    function getActionCounter() external view returns (uint256) {
        return _actionCounter;
    }

    /**
     * @dev an action can only be executed if:
     * 1) it's never been executed before and
     * 2) enough time has passed since it was first proposed
     */
    function _canBeExecuted(uint256 actionId) public view returns (bool) {// Function made public just for debugging
        GovernanceAction memory actionToExecute = _actions[actionId];
        
        if (actionToExecute.proposedAt == 0) // early exit
            return false;

        uint64 timeDelta;
        unchecked {
            timeDelta = uint64(block.timestamp) - actionToExecute.proposedAt;
        }

        // since an action can only be executed every 2 days, we should probably user
        // the trick with speeding up time again
        return actionToExecute.executedAt == 0 && timeDelta >= ACTION_DELAY_IN_SECONDS;
    }

    // A 'user' will only have enough votes if they have more than 50 percent of
    // of the governance tokens
    function _hasEnoughVotes(address who) public view returns (bool) { // Function made public just for debugging
        uint256 balance = _governanceToken.getBalanceAtLastSnapshot(who);
        uint256 halfTotalSupply = _governanceToken.getTotalSupplyAtLastSnapshot() / 2;
        return balance > halfTotalSupply;
    }
}



// My instinct is to say that we can somehow borrow governance
// tokens from the flash loan pool to push an action forwards
// that would emergency exit the pool and give us all the funds.

// Not sure if these are the same token though

// YES -- it is the same token

// In that case this plan should work. We just need to figure out how to interact with
// with the governance contract

// We need to figure out some stuff about this snapshot business. It only checks the number
// of governance tokens you had at the last snapshot, so we somehow have to borrow money
// when a snapshot is happening.

// Then we can even just send the money back bc we don't actually need it currently to queue
// the action


// There does not seem to be any restrictions on who can take snapshots?
