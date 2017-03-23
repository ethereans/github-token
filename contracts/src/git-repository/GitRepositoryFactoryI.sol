pragma solidity ^0.4.8;

/**
 * By Ricardo Guilherme Schmidt
 * Released under GPLv3 License
 */

import "./GitRepositoryI.sol";

contract GitRepositoryFactoryI {
    function newGitRepository(uint256 _uid, string _name) external returns (GitRepositoryI);
}
