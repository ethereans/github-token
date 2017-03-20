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
 
import "lib/ethereans/management/Owned.sol";
import "./GitRepositoryI.sol";
import "./GitRepositoryToken.sol";
import "./GitRepositoryStorage.sol";

contract GitRepository is GitRepositoryI, Owned {

    //Address of the oracle, used for github login address lookup
    GitRepositoryStorage public db;
    GitRepositoryToken public token;
    
    uint256 public subscribers;
    uint256 public watchers;
    //claim event
    event Claim(bytes32 commit);

    //protect against double claiming
    modifier not_claimed(bytes20 commitid) {
        if(isClaimed(commitid)) throw;
        _;
    }
    
    function GitRepository(uint256 _uid, string _name) {
       db = new GitRepositoryStorage(_uid,_name);
       token = new GitRepositoryToken(_name);
    }
    
    //checks if a commit is already claimed
    function isClaimed(bytes20 _commitid) 
     constant 
     returns (bool) {
        return db.commits(_commitid) != 0x0;
    }   

    //oracle claim request
    function claim(bytes20 _commitid, address _user, uint _total) 
     only_owner {
        if(_total > 0 && !token.lock()){
            if(_user != 0x0 && db.commits(_commitid) != 0x0){
                Claim(_commitid);
                db.setClaimed(_commitid,_user);
                token.mint(_user, _total);
            }
        }
    }
    
    function setStats(uint256 _subscribers, uint256 _watchers)
     only_owner {
        subscribers = _subscribers;
        watchers = _watchers;
    }
    
}
