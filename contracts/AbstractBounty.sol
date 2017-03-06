pragma solidity ^0.4.8;

/**
 * 
 */
 
contract AbstractBounty {
     
    uint public constant LOCKED_TIME = 30 days;
     
    mapping (address => mapping(uint => uint)) deposits;
    mapping (uint => Issue) issues;
     
    struct Issue {
        uint balance;
        uint unlock;
        address claimer;
        bool claimed;
    }
     
    modifier only_unlocked(uint num){
        if(issues[num].unlock == 0 || issues[num].unlock > now) throw;
    }
     
    modifier only_unclaimed(uint num){
        if(issues[num].claimed) throw;
    }
     
    function deposit(uint num) 
     only_unclaimed(num) 
     payable {
        deposits[msg.sender][num] += msg.value;
        issues[num].balance += msg.value;
    }
     
    function withdraw(uint num)
     only_unlocked(num)
     only_unclaimed(num) {
        uint avaliable = deposits[msg.sender][num];
        deposits[msg.sender][num] -= avaliable;
        issues[num].balance -= avaliable;
        msg.sender.send(avaliable);
    }
     
    function open(uint num) 
     only_unlocked(num)
     internal {
          issues[num].unlock=0;
    }
    function close(uint num)
     only_unlocked(num)
     internal {
         issues[num].unlock=now+LOCKED_TIME;
    }
     
    function claim(uint num)
     only_unlocked(num)
     only_unclaimed(num) {
        issues[num].claimer = msg.sender;
        issues[num].claimed = true;
        if(!msg.sender.send(issues[num].balance)) throw;
    }
     
 }