pragma solidity ^0.4.8;

/**
 * Contract that oracle github API
 * 
 * GitHubRegistry is a storage contract
 * 
 * By Ricardo Guilherme Schmidt
 * Released under GPLv3 License
 */

import "./GitRepositoryI.sol";
import "lib/ethereans/migrations/Owned.sol";

contract GitHubOracleStorage is Owned {
    
    mapping (string => uint256) repositoryNames;
    mapping (uint256 => address) public repositories;
    mapping (uint256 => address) public users;
    mapping (string => uint256) userNames;

 
    function setRepositoryAddress(uint256 _repositoryId, address _repositoryAddress) 
     external
     only_owner {
        repositories[_repositoryId] = _repositoryAddress;
    }
    
    function setRepositoryName(uint256 _repositoryId, string _name) 
     external 
     only_owner {
        repositoryNames[_name] = _repositoryId;
    }
    
    function setUserAddress(uint userId, address account)
     external
     only_owner{
        users[userId] = account;
    }

    function setUserName(uint256 _userId, string _name) 
     external 
     only_owner {
        userNames[_name] = _userId;
    }
 
    function getRepositoryId(string _full_name) 
     constant returns (uint256){
        return repositoryNames[_full_name];
    }
    
}