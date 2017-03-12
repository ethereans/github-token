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

import "lib/ethereans/abstract-token/CollaborationToken.sol";
import "GitHubOracle.sol";

contract GitHubToken is CollaborationToken {

    //stores repository name, used for claim calls
    string private repository;
    //stores repository name in sha3, used by GitHubOracle
    bytes32 public sha3repository;
    //permanent storage of recipts of all commits
    mapping (bytes32 => CommitReciept) public commits;
    //Address of the oracle, used for github login address lookup
    GitHubOracle public oracle;
    //claim event
    event Claim(bytes32 shacommit);

    //stores the total and user, and if claimed (used against double claiming)
    struct CommitReciept {
        uint256 total;
        address user;
        bool claimed;
    }
    
    //protect against double claiming
    modifier not_claimed(string commitid) {
        if(isClaimed(commitid)) throw;
        _;
    }
    
    modifier only_oracle {
        if (msg.sender != address(oracle)) throw;
        _;
    }
    
    function GitHubToken(string _repository, GitHubOracle _oracle) {
        oracle = _oracle;
        repository = _repository;
        sha3repository = sha3(_repository);
    }
    
    //checks if a commit is already claimed
    function isClaimed(string _commitid) 
     constant 
     returns (bool) {
        return commits[sha3(_commitid)].claimed;
    }   

    //oracle claim request
    function _claim(string _commitid, string _login, uint _total) 
     only_oracle {
        if(_total > 0 && !lock){
            bytes32 shacommit = sha3(_commitid); 
            address user = oracle.getUserAddress(_login);
            if(!commits[shacommit].claimed && user != 0x0){
                commits[shacommit].claimed = true;
                commits[shacommit].user = user;
                commits[shacommit].total = _total;
                mint(user, _total);
                Claim(shacommit);
            }
        }
    }
    
    //claims a commitid
    function claim(string _commitid) 
     payable 
     not_locked
     not_claimed(_commitid) {
        oracle.claimCommit(repository, _commitid);
   }

}
