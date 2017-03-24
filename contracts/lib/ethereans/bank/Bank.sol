pragma solidity  ^0.4.9;


contract Bank {
    
    event Withdrawn(address reciever, uint256 amount);
    event Deposited(address sender,uint256 value);
    //allow deposit and call event
    function deposit() payable {
        Deposited(msg.sender, msg.value);
    }

    //withdraw if locked and not paid, updates epoch
    function withdrawal(address dest, uint amount)
     internal {
        if(!dest.send(amount)) throw;
        Withdrawn(msg.sender, amount);
    }
}