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

contract CollaborationToken is AbstractToken {
    //creation time, defined when contract is created
    uint256 public creationTime = now;
    //time constants, defines epoch size and periods
    uint256 public constant UNLOCKED_TIME = 25 days;
    uint256 public constant LOCKED_TIME = 5 days;
    uint256 public constant EPOCH_LENGTH = UNLOCKED_TIME + LOCKED_TIME;
    //current epoch constant formula, recalculated in any contract call
    uint256 public constant CURRENT_EPOCH = (now - creationTime) / EPOCH_LENGTH + 1;    
    //next lock constant formula, recalculated in any contract call
    uint256 public constant NEXT_LOCK = (creationTime + CURRENT_EPOCH * UNLOCKED_TIME) + (CURRENT_EPOCH - 1) * LOCKED_TIME;
    //used for calculating balance and for checking if account withdrawn
    uint256 public currentPayEpoch;
    //stores the balance from the lock time
    uint256 public epochBalance;
    //stores lock state, used for events
    bool public lock;
    //used for hecking if account withdrawn
    mapping (address => uint) lastPaidOutEpoch;
    //events
    event Withdrawn(address tokenHolder, uint256 amountPaidOut);
    event Deposited(address donator,uint256 value);
    event Locked();
    event Unlocked();
    
    //checks if not locked and call event on change
    modifier not_locked {
        if (NEXT_LOCK < now) {
            if (lock) throw;
            lock = true;
            Locked();
            return;
        }
        else {
            if (lock) {
                lock = false;
                Unlocked();
            }
        }
        _;
    }
    
    //checks if is locked and call event on change
    modifier locked {
        if (NEXT_LOCK < now) {
            if (!lock){
                lock = true;
                Locked();
            }
        }
        else {
            if (!lock) throw;
            lock = false;
            Unlocked();
            return;
        }
        _;
    }
    
    //update the balance and payout epoch
    modifier update_epoch {
        if(currentPayEpoch < CURRENT_EPOCH) {
            currentPayEpoch = CURRENT_EPOCH;
            epochBalance = this.balance;
        }
        _;
    }

    //checks if user already withdrawn
    modifier not_paid {
        if (lastPaidOutEpoch[msg.sender] == currentPayEpoch) throw;
        _;
    }
    
    //check overflow in multiply
    modifier safe_multiply(uint256 _a, uint256 _b) {
        if (!(_b == 0 || ((_a * _b) / _b) == _a)) throw;
        _;
    }
    
    //allow deposit and call event
    function ()
     payable {
        Deposited(msg.sender, msg.value);
    }

    //withdraw if locked and not paid, updates epoch
    function withdrawal()
     external
     locked
     update_epoch
     not_paid
     safe_multiply(balanceOf(msg.sender), epochBalance) {
        uint256 _currentEpoch = CURRENT_EPOCH;
        uint256 _tokenBalance = balanceOf(msg.sender);
        uint256 _totalSupply = totalSupply;
        if (this.balance == 0 || _tokenBalance == 0) throw;
        lastPaidOutEpoch[msg.sender] = currentPayEpoch;
        uint256 amountToPayOut = (_tokenBalance * epochBalance) / _totalSupply;
        if(!msg.sender.send(amountToPayOut)) {
            throw;
        }
        Withdrawn(msg.sender, amountToPayOut);
    }

    //if this coin owns tokens of other lockablecoin, allow withdraw
    function withdrawalFrom(CollaborationToken _otherCollaborationToken) {
        _otherCollaborationToken.withdrawal();
    }

    //return expected payout in lock or estimated when not locked
    function expectedPayout(address _tokenHolder)
     external
     constant 
     returns (uint256 payout) {
        if (now < NEXT_LOCK) //unlocked, estimate
            payout = (balanceOf(_tokenHolder) * this.balance) / totalSupply; 
        else
            payout = (balanceOf(_tokenHolder) * epochBalance) / totalSupply;
    }

    //overwrite not allow transfer during lock
    function transfer(address _to, uint256 _value) 
     not_locked
     returns (bool ok) {
        return super.transfer(_to,_value);
    }
    
    //overwrite not allow transfer during lock
    function transferFrom(address _from, address _to, uint256 _value) 
     not_locked
     returns (bool ok) {
        return super.transferFrom(_from,_to,_value);
    }
    
    //overwrite not allow transfer during lock
    function approve(address _spender, uint256 _value)
     returns (bool ok) {
        return super.approve(_spender,_value);
    }

}
