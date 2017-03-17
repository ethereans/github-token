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
import "lib/ethereans/util/StringLib.sol";
import "lib/ethereans/util/JSONLib.sol";
import "lib/ethereans/migrations/Owned.sol";
import "./GitRepositoryFactoryI.sol";
import "./GitHubOracleStorage.sol";



contract GitHubOracle is Owned, usingOraclize {
    using StringLib for string;
    using JSONLib for JSONLib.JSON;
    
    GitRepositoryFactoryI public gitRepositoryFactoryI;
    GitHubOracleStorage public db;
    
    
    enum OracleType { SET_REPOSITORY, SET_USER, CLAIM_COMMIT, UPDATE_ISSUE }
    mapping (bytes32 => OracleType) claimType; //temporary db enumerating oraclize calls
    mapping (bytes32 => CommitClaim) commitClaim; //temporary db for oraclize commit token claim calls
    mapping (bytes32 => UserClaim) userClaim; //temporary db for oraclize user register queries

    string private credentials = ""; //store encrypted values of api access credentials
    
    //stores temporary data for oraclize user register request
    struct UserClaim {
        address sender;
        string githubid;
    }
    //stores temporary data for oraclize repository commit claim
    struct CommitClaim {
        string repository;
        string commitid;
    }
    
    function GitHubOracle(GitRepositoryFactoryI _gitRepositoryFactoryI){
       gitRepositoryFactoryI = _gitRepositoryFactoryI; // 0x17956bA5f4291844bc25aEDb27e69bc11B5Bda39;
       db = new GitHubOracleStorage();
    }
    
    //register or change a github user ethereum address 100000000000000000
    function register(string _github_user, string _gistid)
     payable {
        bytes32 ocid = oraclize_query("nested", StringLib.str("[identity] ${[URL] https://gist.githubusercontent.com/").concat(_github_user,"/",_gistid,"/raw/}, ${[URL] json(https://api.github.com/gists/").concat(_gistid,credentials,").owner.[id,login]}"));
        claimType[ocid] = OracleType.SET_USER;
        userClaim[ocid] = UserClaim({sender: msg.sender, githubid: _github_user});
    }
    
    function claimCommit(string _repository, string _commitid)
     payable {
        bytes32 ocid = oraclize_query("URL", StringLib.str("json(https://api.github.com/repos/").concat(_repository,"/commits/", _commitid, credentials).concat(").[author,stats].[id,total]"));
        claimType[ocid] = OracleType.CLAIM_COMMIT;
        commitClaim[ocid] = CommitClaim( { repository: _repository, commitid:_commitid});
    }
    
    function addRepository(string _repository)
     payable {
        bytes32 ocid = oraclize_query("URL", StringLib.str("json(https://api.github.com/repos/").concat(_repository,").$.id,full_name,watchers,subscribers_count"),3000000);
        claimType[ocid] = OracleType.SET_REPOSITORY;
    }  
    
    function setAPICredentials(string _client_id, string _client_secret)
     only_owner {
         credentials = StringLib.str("?client_id=${[decrypt] ").concat(_client_id,"}&client_secret=${[decrypt] ",_client_secret,"}");
    }
    
    function clearAPICredentials()
     only_owner {
         credentials = "";
     }


    event OracleEvent(bytes32 myid, string result, bytes proof);
    //oraclize response callback

    function __callback(bytes32 myid, string result, bytes proof) {
        OracleEvent(myid,result,proof);
        if (msg.sender != oraclize.cbAddress()){
          throw;  
        }else if(claimType[myid]==OracleType.SET_USER){
            _register(myid, result);
        }else if(claimType[myid]==OracleType.CLAIM_COMMIT){ 
            _claimCommit(myid, result);
        }else if(claimType[myid] == OracleType.SET_REPOSITORY){
            _setRepository(myid, result);
        }
        delete claimType[myid];  //should always be deleted
    }

    event UserSet(string githubLogin);
    function _register(bytes32 myid, string result) 
     internal {
        uint256 userId; string memory login; address addrLoaded;
        JSONLib.JSON memory v = JSONLib.json(result);
        (addrLoaded,v) = v.getNextAddr();
        (userId,v) = v.getNextUInt();
        (login,v) = v.getNextString();
        if(userClaim[myid].sender == addrLoaded && userClaim[myid].githubid.compare(login) == 0){
            UserSet(login);
            db.setUserAddress(userId, addrLoaded);
            db.setUserName(userId, login);
        }
        delete userClaim[myid]; //should always be deleted
    }
    
    event GitRepositoryRegistered(uint256 projectId, string full_name, uint256 watchers, uint256 subscribers);    
    function _setRepository(bytes32 myid, string result)
     internal {
        uint256 projectId; string memory full_name; uint256 watchers; uint256 subscribers;
        JSONLib.JSON memory v = JSONLib.json(result);
        (projectId,v) = v.getNextUInt();
        (full_name,v) = v.getNextString();
        (watchers,v) = v.getNextUInt();
        (subscribers,v) = v.getNextUInt();
        GitRepositoryI repository = GitRepositoryI(db.repositories(projectId));
        if(address(repository) == 0x0){
            GitRepositoryRegistered(projectId,full_name,watchers,subscribers);
            db.setRepositoryName(projectId,full_name);
            if(!gitRepositoryFactoryI.delegatecall(bytes4(sha3("newGitRepository(address,uint256)")),db,projectId)) throw;
            repository = GitRepositoryI(db.repositories(projectId));
        }
        repository.setStats(subscribers,watchers);
    }

    event NewClaim(string repository, string commitid, uint userid, uint total );
    function _claimCommit(bytes32 myid, string result)
     internal {
        uint256 total; uint256 userId;
        JSONLib.JSON memory v = JSONLib.json(result);
        (userId,v) = v.getNextUInt();
		(total,v) = v.getNextUInt();
		NewClaim(commitClaim[myid].repository,commitClaim[myid].commitid,userId,total);
		GitRepositoryI repository = GitRepositoryI(db.repositories(db.getRepositoryId(commitClaim[myid].repository)));
		repository.claim(commitClaim[myid].commitid.parseBytes20(), db.users(userId), total);
        delete commitClaim[myid]; //should always be deleted
    }


    function getGitRepository(uint projectId) constant returns (address){
        return db.repositories(projectId);
    }
    function getGitRepository(string full_name) constant returns (address){
        return db.repositories(getGitRepositoryId(full_name));
    }
    function getGitRepositoryId(string full_name) constant returns (uint256){
        return db.getRepositoryId(full_name);
    }
    
}