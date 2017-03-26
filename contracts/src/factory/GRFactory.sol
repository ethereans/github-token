pragma solidity ^0.4.8;

/**
 * By Ricardo Guilherme Schmidt
 * Released under GPLv3 License
 */

import "../git-repository/GitRepository.sol";
//import "./GitRepositoryFactoryI.sol";

library GRFactory {

    function newGitRepository(uint256 _uid, string _name) returns (GitRepositoryI){
        GitRepository repo = new GitRepository(_uid,_name);
        return repo;
    }

    

}