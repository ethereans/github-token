 pragma solidity ^0.4.8;

/**
 * Contract that oracle github API
 * 
 * GitHubRegistry is a storage contract
 * 
 * By Ricardo Guilherme Schmidt
 * Released under GPLv3 License
 */
import "lib/ethereans/migrations/Owned.sol";

contract GitRepositoryStorage is Owned {
  
    string public name;
    uint256 public uid;
 
    //storage of sha3(login) of github users
    mapping (bytes32 => address) users;
    
    mapping (bytes20 => address) public commits;
    
    function setClaimed(bytes20 _commitid, address _claimer)
     only_owner {
        commits[_commitid] = _claimer;
    }
    
    function setUser(bytes32 _user, address _account)
     only_owner {
        users[_user] = _account;
        if(_account == 0x0){
            delete users[_user];
        }
    }
    
    function GitRepositoryStorage(uint256 _uid, string _name){
       uid = _uid;
       name = _name;
    }

}