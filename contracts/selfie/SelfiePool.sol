// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";
import "@openzeppelin/contracts/interfaces/IERC3156FlashLender.sol";
import "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";
import "./SimpleGovernance.sol";

/**
 * @title SelfiePool
 * @author Damn Vulnerable DeFi (https://damnvulnerabledefi.xyz)
 */
contract SelfiePool is ReentrancyGuard, IERC3156FlashLender {

    ERC20Snapshot public immutable token;
    SimpleGovernance public immutable governance;
    bytes32 private constant CALLBACK_SUCCESS = keccak256("ERC3156FlashBorrower.onFlashLoan");

    error RepayFailed();
    error CallerNotGovernance();
    error UnsupportedCurrency();
    error CallbackFailed();

    event FundsDrained(address indexed receiver, uint256 amount);

    modifier onlyGovernance() {
        if (msg.sender != address(governance))
            revert CallerNotGovernance();
        _;
    }

    constructor(address _token, address _governance) {
        token = ERC20Snapshot(_token);
        governance = SimpleGovernance(_governance);
    }

    function maxFlashLoan(address _token) external view returns (uint256) {
        // there is only one token available so idk why we want this
        if (address(token) == _token)
            // we can loan as much as the contract has
            return token.balanceOf(address(this));
        return 0;
    }

    // I have no idea whether this does anything
    function flashFee(address _token, uint256) external view returns (uint256) {
        if (address(token) != _token)
            revert UnsupportedCurrency();
        return 0;
    }

    function flashLoan(
        IERC3156FlashBorrower _receiver,
        address _token,
        uint256 _amount,
        bytes calldata _data
    ) external nonReentrant returns (bool) {
        // tf they need this check every 2 lines of code :joy:
        if (_token != address(token))
            revert UnsupportedCurrency();

        // give the money
        token.transfer(address(_receiver), _amount);
        // call the flashloan function
        if (_receiver.onFlashLoan(msg.sender, _token, _amount, 0, _data) != CALLBACK_SUCCESS)
            revert CallbackFailed();

        // get the tokens back
        // NOTE: tokens need to be approved for it to take them back
        if (!token.transferFrom(address(_receiver), address(this), _amount))
            revert RepayFailed();
        
        return true;
    }

    // Governance can drain the token
    // Assuming that if we can hack governance it will be the easiest
    // way to get all these tokens.
    function emergencyExit(address receiver) external onlyGovernance {
        uint256 amount = token.balanceOf(address(this));
        token.transfer(receiver, amount);

        emit FundsDrained(receiver, amount);
    }
}
