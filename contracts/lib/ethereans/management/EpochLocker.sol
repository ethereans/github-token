pragma solidity ^0.4.8;

/**
 * Abstract contract that locks and unlock in period of a time.
 * 
 */

import "lib/ethereans/management/Lockable.sol";

contract EpochLocker is Lockable {

    uint256 public creationTime = now;
    uint256 public unlockedTime = 25 days; 
    uint256 public lockedTime = 5 days; 
    uint256 public constant EPOCH_LENGTH = unlockedTime + lockedTime;
    uint256 public constant CURRENT_EPOCH = (now - creationTime) / EPOCH_LENGTH + 1;    
    uint256 public constant NEXT_LOCK = (creationTime + CURRENT_EPOCH * unlockedTime) + (CURRENT_EPOCH - 1) * lockedTime;


    function EpochLocker(uint256 _unlockedTime, uint256 _lockedTime){ 
        unlockedTime = _unlockedTime;
        lockedTime = _lockedTime;
    }
    
    //update lock value if needed or throw if unexpected lock
    modifier check_lock(bool lockedOnly) {
        if(lockedOnly){ //method allowed when locked
            if (NEXT_LOCK < now) { //is locked!
                if (!lock) setLock(true); //storage says other thing, update it.
                _; //continue
            }
            else { //is not locked!
                if (!lock) throw; //unlocked and storage already say so, throw to prevent event flood.
                setLock(false); //update storage
                return; //prevent method from running post states.
            }  
        }else{ //method allowed when unlocked.
             if (NEXT_LOCK < now) { //is locked!
                if (lock) throw; //no need to update storage.
                setLock(true); //update storage
                return; //prevent method from running post states.
            }
            else { //is not locked!
                if (lock) setLock(false); //storage says other thing, update it.
                _; //continue
            }  
        }
    }
    

}