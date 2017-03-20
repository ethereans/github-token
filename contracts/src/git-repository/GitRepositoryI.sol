pragma solidity ^0.4.8;

/**
 * By Ricardo Guilherme Schmidt
 * Released under GPLv3 License
 */

contract GitRepositoryI {
    function isClaimed(bytes20 _commitid) constant returns (bool);
    function claim(bytes20 _commitid, address _user, uint _total);
    function setStats(uint256 _subscribers, uint256 _watchers);
}