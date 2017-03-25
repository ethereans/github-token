pragma solidity ^0.4.8;

/**
 * DO NOT USE: under development
 */
 import "./GitHubOracle.sol";

 
 contract GitHubIssues {
     
    //Address of the oracle, used for github login address lookup
    GitHubOracle public oracle;
    //stores repository name, used for claim calls
    string private repository;
    uint private uid;
    mapping (uint => Issue) issues;
     
    struct Issue {
        bool state;
        uint balance;
        uint unlock;
        address claimer;
        bool claimed;
    }
    
    
    modifier only_oracle {
        if (msg.sender != address(oracle)) throw;
        _;
    }
    
    function GitHubIssues(uint _uid, string _repository, GitHubOracle _oracle) {
        uid = _uid;
        oracle = _oracle;
        repository = _repository;
    }
    
    function setState(uint num, bool open){
        //issues[num] = open;
    }
    
    function placeBounty(uint num){
        
    }
 }