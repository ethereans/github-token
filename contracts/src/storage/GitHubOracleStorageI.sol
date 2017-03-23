pragma solidity ^0.4.8;

/**
 * Contract that oracle github API
 * 
 * GitHubRegistry is a storage contract
 * 
 * By Ricardo Guilherme Schmidt
 * Released under GPLv3 License
 */

contract GitHubOracleStorageI {
    
    function addRepository(uint256 _id, uint256 _owner, string _name, string _full_name, address _addr);
    function addUser(uint256 _id, string _login, uint8 _type, address _addr);
    function setRepositoryAddress(uint256 _repositoryId, address _repositoryAddress);
    function setRepositoryName(uint256 _repositoryId, string _full_name, string _name);
    function setUserAddress(uint userId, address account);
    function setUserName(uint256 _userId, string _name);
    function getRepositoryId(string _full_name) constant returns (uint256);
    function getRepositoryName(uint256 _id)  constant returns (string);
    function getRepositoryAddress(uint256 _id) constant returns(address);
    function getRepositoryAddress(string _full_name) constant returns(address);
    function getUserAddress(uint256 _id) constant returns(address);
    function getUserAddress(string _login) constant returns(address);
    
}