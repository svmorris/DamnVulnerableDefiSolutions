// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../DamnValuableToken.sol";

/**
 * @title TrusterLenderPool
 * @author Damn Vulnerable DeFi (https://damnvulnerabledefi.xyz)
 */
contract TrusterLenderPool is ReentrancyGuard {
    using Address for address;

    DamnValuableToken public immutable token;

    error RepayFailed();

    constructor(DamnValuableToken _token) {
        token = _token;
    }

    // interestingly the borrower and target are different accounts
    function flashLoan(uint256 amount, address borrower, address target, bytes calldata data)
        external
        nonReentrant
        returns (bool)
    {
        // get the balance before loaning
        uint256 balanceBefore = token.balanceOf(address(this));

        // transfer tokens to the player
        token.transfer(borrower, amount);
        // call their flashloan function
        // This allows us to call any function on the target, the function signiture/name has to be in the data variable
        target.functionCall(data);

        // make sure the balance currently is no less than the balance before lending
        if (token.balanceOf(address(this)) < balanceBefore)
            revert RepayFailed();

        return true;
    }
}
