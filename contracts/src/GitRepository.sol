pragma solidity ^0.4.8;

/**
 * Contract that mint tokens by github commit stats
 * 
 * GitHubOracle register users and create GitHubToken contracts
 * Registration requires user create a gist with only their account address
 * GitHubOracle will create one GitHubToken contract per repository
 * GitHubToken mint tokens by commit only for registered users in GitHubOracle
 * GitHubToken is a LockableCoin, that accept donatations and can be withdrawn by Token Holders
 * The lookups are done by Oraclize that charge a small fee
 * The contract itself will never charge any fee
 * 
 * By Ricardo Guilherme Schmidt
 * Released under GPLv3 License
 */
 
import "lib/ethereans/bank/CollaborationBank.sol";
import "lib/ethereans/management/Owned.sol";
import "./BountyBank.sol";
import "./GitRepositoryToken.sol";


contract GitRepositoryI {
    function isClaimed(bytes20 _commitid) constant returns (bool);
    function claim(bytes20 _commitid, address _user, uint _total);
    function setStats(uint256 _subscribers, uint256 _watchers);
}

contract GitRepository is GitRepositoryI, Owned {

    GitRepositoryToken public token;
    CollaborationBank public donationBank;
    BountyBank public bountyBank;
    mapping (address=>uint) donators;

    string public name;
    uint256 public uid;
    mapping (bytes20 => bool) public commits;
    
    uint256 public subscribers;
    uint256 public watchers;
    //claim event
    event Claim(bytes32 commit);

    //protect against double claiming
    modifier not_claimed(bytes20 commitid) {
        if(isClaimed(commitid)) throw;
        _;
    }
    
    function () payable {
        donationBank.deposit();
        donators[msg.sender] += msg.value;
    }

    function GitRepository(uint256 _uid, string _name) {
       uid = _uid;
       name = _name;
       token = new GitRepositoryToken(_name);
       donationBank = new CollaborationBank(token);
       token.linkLocker(donationBank);
       bountyBank = new BountyBank();
    }
    
    //checks if a commit is already claimed
    function isClaimed(bytes20 _commitid) 
     constant 
     returns (bool) {
        return commits[_commitid];
    }   

    //oracle claim request
    function claim(bytes20 _commitid, address _user, uint _total) 
     only_owner {
        if(_total > 0 && !token.lock() && _user != 0x0 && !commits[_commitid]){
            Claim(_commitid);
            commits[_commitid] = true;
            token.mint(_user, _total);
        }
    }
    
    function setStats(uint256 _subscribers, uint256 _watchers)
     only_owner {
        subscribers = _subscribers;
        watchers = _watchers;
    }
    
    function bountyState(uint issue, bool open) only_owner {
       if (open) bountyBank.open(issue);
       else bountyBank.close(issue);
    }
    
    function bountyState(uint issue, address claimer, uint points) only_owner {
       bountyBank.setClaimer(issue,claimer,points);
    }
    
}

library GitFactory {

    function newGitRepository(uint256 _uid, string _name) returns (GitRepositoryI){
        GitRepository repo = new GitRepository(_uid,_name);
        return repo;
    }

}