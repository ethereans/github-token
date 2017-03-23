pragma solidity ^0.4.8;

/**
 * By Ricardo Guilherme Schmidt
 * Released under GPLv3 License
 */

import "./GitRepository.sol";
import "./GitRepositoryFactoryI.sol";

contract GitRepositoryFactory is GitRepositoryFactoryI {

    function newGitRepository(uint256 _uid, string _name) external returns (GitRepositoryI){
        GitRepository repo = new GitRepository(_uid,_name);
        repo.setOwner(msg.sender);
        return GitRepositoryI(repo);
    }

}