pragma solidity ^0.4.8;

/**
 * By Ricardo Guilherme Schmidt
 * Released under GPLv3 License
 */

import "./GitRepository.sol";
import "./GitHubOracleStorage.sol";
import "./GitRepositoryFactoryI.sol";

contract GitRepositoryFactory is GitRepositoryFactoryI {

    /*function newGitRepository(uint256 _uid, string _name) external returns (address){
        GitRepository repo = new GitRepository(_uid,_name);
        return address(repo);
    }*/
    
    function newGitRepository(address db, uint256 _uid) external returns (bool) {
        GitHubOracleStorage dbs = GitHubOracleStorage(db);
        dbs.setRepositoryAddress(_uid, new GitRepository(_uid,""));
        return true;
    }
    
}