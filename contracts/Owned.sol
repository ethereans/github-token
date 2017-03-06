pragma solidity ^0.4.8;

contract Owned {

    address public owner= msg.sender;

    modifier only_owner {
        if (msg.sender != owner) throw;
        _;
    }
}