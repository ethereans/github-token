pragma solidity ^0.4.8;

/**
 * Contract that oracle github API
 * 
 * GitHubOracle register users and create GitHubToken contracts
 * Registration requires user create a gist with only their account address
 * GitHubOracle will create one GitHubToken contract per repository
 * GitHubToken mint tokens by commit only for registered users in GitHubOracle
 * GitHubToken is a LockableCoin, that accept donatations and can be withdrawn by Token Holders
 * The lookups are done by Oraclize that charge a small fee
 * The contract itself will never charge any fee
 * 
 * By Ricardo Guilherme Schmidt
 * Released under GPLv3 License
 */
 
import "lib/oraclize/oraclizeAPI_0.4.sol";
import "lib/ethereans/management/Owned.sol";
import "./DGitDB.sol";
import "./GitHubAPI.sol";
import "./GitRepository.sol";

contract DGit is Owned, DGitI {

    DGitDBI public db;
    GitHubAPI public gitHubApi;

    function initialize() only_owner {
        db = DBFactory.newStorage();
        gitHubApi = QueryFactory.newGitHubAPI();
    }

    function register(string _github_user, string _gistid) payable{
        gitHubApi.register.value(msg.value)(msg.sender,_github_user,_gistid);
    }
    function updateCommits(string _repository) payable{
        gitHubApi.updateCommits.value(msg.value)(_repository,db.getClaimedHead(_repository));
    }
    function addRepository(string _repository) payable{
        gitHubApi.addRepository.value(msg.value)(_repository);
    }
    function updateIssue(string _repository, string issue) payable{
        gitHubApi.updateIssue.value(msg.value)(_repository,issue);
    }
    function getRepository(uint projectId) constant returns (address){
        return db.getRepositoryAddress(projectId);
    } 
    function getRepository(string full_name) constant returns (address){
        return db.getRepositoryAddress(full_name);
    } 

    modifier only_gitapi{
        if (msg.sender != address(gitHubApi)) throw;
        _;
    }
    
    event UserSet(string githubLogin);
    function __register(address addrLoaded, uint256 userId, string login) 
     only_gitapi {
        UserSet(login); 
        db.addUser(userId, login, 0, addrLoaded);
    }
    
    event GitRepositoryRegistered(uint256 projectId, string full_name, uint256 watchers, uint256 subscribers);    
    function __setRepository(uint256 projectId, string full_name, uint256 watchers, uint256 subscribers) only_gitapi //[83725290, "ethereans/github-token", 4, 2]
    {
        uint256 ownerId; string memory name; //TODO
        address repository = db.getRepositoryAddress(projectId);
        if(repository == 0x0){            
            GitRepositoryRegistered(projectId,full_name,watchers,subscribers);
            repository = GitFactory.newGitRepository(projectId,full_name);
            db.addRepository(projectId,ownerId,name,full_name,repository);
        }
        GitRepositoryI(repository).setStats(subscribers,watchers);
    }

    event NewPoints(string repository, uint userId, uint total);
    function __newPoints(string repository, uint userId, uint total)
     only_gitapi {
		NewPoints(repository,userId,total); 
		GitRepositoryI repoaddr = GitRepositoryI(db.getRepositoryAddress(repository));
		if(!repoaddr.claim(db.getUserAddress(userId), total)){ //try to claim points
		    db.setPending(repository, userId, total); //set as a pending points
		}
    }
    
    //claims pending points
    function claimPending(uint repoId, uint userId){
        GitRepositoryI repoaddr = GitRepositoryI(db.getRepositoryAddress(repoId));
        uint total = db.claimPending(repoId,userId);
        if(!repoaddr.claim(db.getUserAddress(userId), total)) throw;
        
    }

}