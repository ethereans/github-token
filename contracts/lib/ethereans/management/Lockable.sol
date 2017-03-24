pragma solidity ^0.4.8;

import "./Owned.sol";

contract Lockable {
    bool public lock = true;
    event Locked(bool lock);
    
    fuction setLock(bool _lock) internal {
        Locked(_lock);
        lock = _lock;
    }
    
}