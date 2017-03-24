pragma solidity ^0.4.0;

/**
 * Abstract contract used for recieving donations or profits
 * Withdraw is divided by total tokens each account owns
 * Unlock period allows transfers
 * Lock period allow withdraws
 * Child contract that implement minting should use modifier not_locked in minting function
 * Inspired by ProfitContainer and Lockable by vDice
 * 
 * By Ricardo Guilherme Schmidt
 * Released under GPLv3 License
 */

import "./AbstractToken.sol";
import "../management/Lockable.sol";

contract LockerToken is AbstractToken, Lockable, Owned {
    Lockable public locker = this;
    
    
    function unlinkLocker() only_owner {
        locker = this;
    }
    function linkLocker(Lockable _locker) only_owner {
        locker = _locker;
    }
    function lock(bool _lock) only_owner {
        setLock(_lock);
    }
    
    modifier when_locked(bool value){
        if (lock != value && locker.lock() != value) throw;
        _;
    }
    
    //overwrite not allow transfer during lock
    function transfer(address _to, uint256 _value) when_locked(true);
     returns (bool ok) {
        return super.transfer(_to,_value);
    }
    
    //overwrite not allow transfer during lock
    function transferFrom(address _from, address _to, uint256 _value) 
     returns (bool ok)  when_locked(true) {
        return super.transferFrom(_from,_to,_value);
    }
    
}
