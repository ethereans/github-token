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

import "./Bank.sol";
import "../management/EpochLocker.sol";
import "../token/LockerToken.sol";

contract CollaborationBank is Bank, EpochLocker {

    LockerToken public token;
    //used for calculating balance and for checking if account withdrawn
    uint256 public currentPayEpoch;
    //stores the balance from the lock time
    uint256 public epochBalance;
    //used for hecking if account withdrawn
    mapping (address => uint) lastPaidOutEpoch;
    //events
    event Withdrawn(address tokenHolder, uint256 amountPaidOut);
    event Deposited(address donator,uint256 value);

    function CollaborationBank(LockerToken _token) EpochLocker(8 minutes, 12 minutes){
        token = _token;
        
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
    function safeMultiply(uint256 _a, uint256 _b) private {
        if (!(_b == 0 || ((_a * _b) / _b) == _a)) throw;
    }
    
    //allow deposit and call event
    function ()
     payable {
        deposit();
    }

    //withdraw if locked and not paid, updates epoch
    function withdrawal()
     external
     check_lock(true)
     update_epoch
     not_paid {
        uint256 _tokenBalance = token.balanceOf(msg.sender);
        uint256 _tokenSupply = token.totalSupply();
        safeMultiply(_tokenBalance, epochBalance);
        lastPaidOutEpoch[msg.sender] = currentPayEpoch; 
        if (this.balance >= epochBalance || _tokenBalance == 0 || _tokenSupply == 0) throw;
        super.withdrawal(msg.sender, (_tokenBalance * epochBalance) / _tokenSupply);
    }

    //if this coin owns tokens of other CollaborationBank, allow withdraw
    function withdrawalFrom(CollaborationBank _otherCollaborationToken) {
        _otherCollaborationToken.withdrawal();
    }

    //return expected payout in lock or estimated when not locked
    function expectedPayout(address _tokenHolder)
     external
     constant 
     returns (uint256 payout) {
        if (now < NEXT_LOCK) //unlocked, estimate
            payout = (token.balanceOf(_tokenHolder) * this.balance) / token.totalSupply(); 
        else
            payout = (token.balanceOf(_tokenHolder) * epochBalance) / token.totalSupply();
    }


}
