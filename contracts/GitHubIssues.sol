pragma solidity ^0.4.8;

/**
 * DO NOT USE: under development
 */
 import "./GitHubOracle.sol";
 import "./AbstractBounty.sol";
 
 contract GitHubIssues is AbstractBounty {
     
    //Address of the oracle, used for github login address lookup
    GitHubOracle public oracle;
    //stores repository name, used for claim calls
    string private repository;
    //stores repository name in sha3, used by GitHubOracle
    bytes32 public sha3repository;
    
    modifier only_oracle {
        if (msg.sender != address(oracle)) throw;
        _;
    }
    
    function GitHubIssues(string _repository, GitHubOracle _oracle) {
        oracle = _oracle;
        repository = _repository;
        sha3repository = sha3(_repository);
    }
    
    function update(uint num){
                
    }
 }