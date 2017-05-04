pragma solidity ^0.4.8;

/**
 * Contract that oracle github API
 * 
 * GitHubRegistry is a storage contract
 * 
 * By Ricardo Guilherme Schmidt
 * Released under GPLv3 License
 */

import "lib/ethereans/management/Owned.sol";

contract DGitDBI {
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
    function getClaimedHead(uint256 _repoid) constant returns (bytes20);
    function getClaimedHead(string _full_name) constant returns (bytes20);
    function getClaimedTail(uint256 _repoid) constant returns (bytes20);
    function setClaimed(uint256 _repoid, bytes20 _head, bytes20 _tail, uint points);
    function setPending(uint256 _repoid, uint256 _userid, uint256 _points);
    function setPending(string _full_name, uint256 _userid, uint256 _points);
    function claimPending(uint256 _repoid, uint256 _userid) returns (uint256 points);
}

contract DGitDB is DGitDBI, Owned {
    
    mapping (string => uint256) repositoryNames;
    mapping (string => uint256) userNames;
    mapping (uint256 => Repository) repositories;
    mapping (uint256 => User) users;

    struct Repository {
        uint256 owner;
        string name;
        string full_name;
        address addr;
        uint points;
        bytes20 head;
        bytes20 tail;
        mapping (uint256 => uint256) pending;
    }
    

    struct User {
        string login;
        uint8 utype;
        address addr;
    }

     function setClaimed(uint256 _repoid, bytes20 _head, bytes20 _tail, uint _points)
     only_owner {
        repositories[_repoid].head = _head;
        repositories[_repoid].tail = _tail;
        repositories[_repoid].points += _points;
    }
    function setPending(uint256 _repoid, uint256 _userid, uint256 _points){
        repositories[_repoid].pending[_userid] += _points;
    }
    function setPending(string _full_name, uint256 _userid, uint256 _points){
        repositories[repositoryNames[_full_name]].pending[_userid] += _points;
    }
    function claimPending(uint256 _repoid, uint256 _userid) returns (uint256 points){
        points = repositories[_repoid].pending[_userid];
        delete repositories[_repoid].pending[_userid];
    }
    
    function getClaimedHead(uint256 _repoid) constant returns (bytes20){
        return repositories[_repoid].head;
    }
    function getClaimedHead(string _full_name) constant returns (bytes20){
        return repositories[repositoryNames[_full_name]].head;
    }
    function getClaimedTail(uint256 _repoid) constant returns (bytes20){
        return repositories[_repoid].tail;
    }

    function addRepository(uint256 _id, uint256 _owner, string _name, string _full_name, address _addr) only_owner {
        repositories[_id] = Repository({owner:_owner,name:_name,full_name:_full_name,addr:_addr,points:0,head:0,tail:0});
        repositoryNames[_full_name] = _id;
    }
    
    function addUser(uint256 _id, string _login, uint8 _utype, address _addr) only_owner{
        users[_id] = User({login:_login,utype:_utype,addr:_addr});
        userNames[_login] = _id;
    }
    
    function setRepositoryAddress(uint256 _repositoryId, address _repositoryAddress) 
     only_owner {
        repositories[_repositoryId].addr = _repositoryAddress;
    }
    
    function setUserAddress(uint userId, address account)
     only_owner{
        users[userId].addr = account;
    }
    function setRepositoryName(uint256 _repositoryId, string _full_name, string _name) 
     only_owner {
        delete repositoryNames[repositories[_repositoryId].full_name]; 
        repositoryNames[_full_name] = _repositoryId;
        repositories[_repositoryId].full_name = _full_name;
        repositories[_repositoryId].name = _full_name;
    }
    
    function setUserName(uint256 _userId, string _name) 
     only_owner {
        delete userNames[users[_userId].login];
        userNames[_name] = _userId;
        users[_userId].login = _name;
    }
    
    function getUserAddress(uint256 _id) constant returns(address){
        return users[_id].addr;
    }
    function getUserAddress(string _login) constant returns(address){
        return users[userNames[_login]].addr;
    }
    function getRepositoryAddress(uint256 _id) constant returns(address){
        return repositories[_id].addr;
    }
    function getRepositoryAddress(string _full_name) constant returns(address){
        return repositories[repositoryNames[_full_name]].addr;
    }
    function getRepositoryId(string _full_name)  constant returns (uint256){
        return repositoryNames[_full_name];
    }
    function getRepositoryName(uint256 _id)  constant returns (string){
        return repositories[_id].full_name;
    }
    
}

library DBFactory {
    function newStorage() returns (DGitDBI){
        return new DGitDB();
    }
}
