pragma solidity ^0.4.9; 
 
import "lib/ethereans/management/Owned.sol";
 
contract BountyBank is Owned {
    
    enum State {CLOSED, OPEN, CLAIMED}
    
    struct Bounty {
        State state;
        uint closedAt;
        mapping (address => uint) deposits;
        mapping (address => uint) claimers;
        uint balance;
        uint points;
     }
     
    mapping (uint => Bounty) bounties;
    uint count = 0;

    function deposit(uint num) payable {
         if(bounties[num].state != State.OPEN || msg.value == 0) throw;
         bounties[num].deposits[msg.sender] += msg.value;
         bounties[num].balance += msg.value;
    }

    function withdraw(uint num) {
         uint value = bounties[num].deposits[msg.sender];
         if(bounties[num].state != State.OPEN || value == 0) throw;
         delete bounties[num].deposits[msg.sender];
         if(!msg.sender.send(value)) throw;
    }

    function open(uint num) only_owner {
         if(bounties[num].state == State.CLAIMED) throw;
         bounties[num].state = State.OPEN;
    }

    function setClaimer(uint num, address claimer, uint points) only_owner {
        if(bounties[num].state == State.CLAIMED) throw;
        bounties[num].claimers[claimer] += points;
        bounties[num].points += points;
    }

    function close(uint num) only_owner {
         if(bounties[num].state == State.CLAIMED) throw;
         bounties[num].state = State.CLOSED;
         bounties[num].closedAt = now;
    }
     
    function claim(uint num){
        if (bounties[num].state == State.OPEN) throw;
        uint totalPoints = bounties[num].points;
        if(totalPoints == 0) throw;
        uint points = bounties[num].claimers[msg.sender];
        if (points == 0) throw;
        delete bounties[num].claimers[msg.sender];
        uint award = (bounties[num].balance / totalPoints)*points;
        bounties[num].points -= points;
        bounties[num].balance -= award;
        if(!msg.sender.send(award)) throw;
    }

 }