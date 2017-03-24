pragma solidity ^0.4.8;

/**
 * DO NOT USE: under development
 */

import "lib/ethereans/management/Owned.sol" ;
 
contract GitBountyBank is Owned {
     
    mapping (uint => Bounty) bounties;
    uint lockPeriod = 1 month;
    struct Bounty {
        bool open;
        uint closedAt; 
        uint stats;
        uint statsClaimed;
        
        mapping (uint=>Account) deposits;
        uint depositIndex;
        uint deposited;
        mapping (bytes20=>Account) claims;
        uint claimed;

    }
    
    struct Account {
        address owner;
        uint amount;
    }
     
    
    function balanceOf(uint num) constant returns(uint){
        return bounties[num].deposited - bounties[num].claimed;
    }
     
    function setState(uint num, uint stats, bool open, uint closedAt){
        if (bounties[num].stats >= stats) throw;
        bounties[num].stats = stats;
        bounties[num].open = open;
        bounties[num].closedAt = closedAt;
    } 
    
    function deposit(uint num, address account) 
     payable returns (uint reciept) {
        if (!bounties[num].open) throw;
        reciept = bounties[num].depositIndex;
        bounties[num].deposits[reciept] = { owner: account, amount: msg.value };
        bounties[num].depositIndex++;
        bounties[num].balance += msg.value;
        return reciept;
    }
     
    function withdraw(uint num, uint reciept, address account) internal {
    if (!bounties[num].open || now < bounties[num].closedAt+lockPeriod) throw;    
        if(bounties[num].deposits[reciept].owner != account) throw;
        uint avaliable = bounties[num].deposits[reciept].amount;
        delete bounties[num].deposits[reciept];
        bounties[num].balance -= avaliable;
        if(!account.send(avaliable)) throw;
    }
   
    function claim(uint num, uint stats, bytes20 commitid, address beneficiary) internal {
        if (bounties[num].open || now < bounties[num].closedAt+lockPeriod) throw;
        uint balance = bounties[num].deposited - bounties[num].claimed;
        uint remainingStats = bounties[num].stats - bounties[num].statsClaimed;
        bounties[num].claims[commitid] = { owner: account, amount: stats };
        
    }
     
 }