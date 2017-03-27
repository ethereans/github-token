pragma solidity ^0.4.9;

import "lib/oraclize/oraclizeAPI_0.4.sol";
import "lib/StringLib.sol";
import "lib/JSONLib.sol";
import "lib/ethereans/management/Owned.sol";


contract GitHubAPI{
     function register(address _sender, string _github_user, string _gistid) payable;
     function claimCommit(string _repository, string _commitid) payable;
     function addRepository(string _repository) payable;
     function updateIssue(string _repository, string issue) payable;
}

contract DGitI {
    function __register(address addrLoaded, uint256 userId, string login);
    function __setRepository(uint256 projectId, string full_name, uint256 watchers, uint256 subscribers);
    function __claimCommit(string repository, bytes20 commitid, uint userid, uint total);
}

contract GitHubAPIOraclize is GitHubAPI, Owned, usingOraclize{
  using StringLib for string;
  
    DGitI dGit;
    function GitHubAPIOraclize(){
        dGit = DGitI(msg.sender);
    }
    string private credentials = ""; //store encrypted values of api access credentials
    string private secret = "";
    string private client = "";
    string private script = "QmS3kHrUQ12ovovKPk9vxKjDPm7kVWcieaMcZc9w8JbNQt";
    
    enum OracleType { SET_REPOSITORY, SET_USER, CLAIM_COMMIT, UPDATE_ISSUE }
    mapping (bytes32 => OracleType) claimType; //temporary db enumerating oraclize calls
    mapping (bytes32 => CommitClaim) commitClaim; //temporary db for oraclize commit token claim calls
    mapping (bytes32 => UserClaim) userClaim; //temporary db for oraclize user register queries

    //stores temporary data for oraclize user register request
    struct UserClaim {
        address sender;
        string githubid;
    }
    //stores temporary data for oraclize repository commit claim
    struct CommitClaim {
        string repository;
        bytes20 commitid;
    }
  //register or change a github user ethereum address. 100000000000000000
  
    function register(address _sender, string _github_user, string _gistid)
     payable only_owner{
        bytes32 ocid = oraclize_query("nested", StringLib.concat("[identity] ${[URL] https://gist.githubusercontent.com/",_github_user,"/",_gistid,"/raw/}, ${[URL] json(https://api.github.com/gists/").concat(_gistid,credentials,").owner.[id,login]}"));
        claimType[ocid] = OracleType.SET_USER;
        userClaim[ocid] = UserClaim({sender: _sender, githubid: _github_user});
    }
    
    function claimCommit(string _repository, string _commitid)
     payable only_owner{
       //uint256 repoid = db.getRepositoryId(_repository);
        //if (repoid == 0) throw;
        bytes20 commitid = _commitid.parseBytes20();
        //if(db.getClaimed(repoid,commitid) == 0) throw;
        bytes32 ocid = oraclize_query("URL", StringLib.concat("json(https://api.github.com/repos/",_repository,"/commits/", _commitid, credentials).concat(").[author,stats].[id,total]"));
        claimType[ocid] = OracleType.CLAIM_COMMIT;
        commitClaim[ocid] = CommitClaim( { repository: _repository, commitid:commitid});
    }
    
    function addRepository(string _repository)
     payable only_owner{
        bytes32 ocid = oraclize_query("URL", StringLib.concat("json(https://api.github.com/repos/",_repository,credentials,").$.id,full_name,watchers,subscribers_count"),4000000);
        claimType[ocid] = OracleType.SET_REPOSITORY;
    }  

    function updateIssue(string _repository, string issue) payable only_owner{
         bytes32 ocid = oraclize_query("computation", [script, StringLib.concat("--reponame ",_repository, " --issueid ", issue, " --script issue-status").concat(" --client ", client, " --secret ", secret)]);
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

    function _register(bytes32 myid, string result) 
     internal {
        uint256 userId; string memory login; address addrLoaded; 
        uint8 utype; //TODO
        bytes memory v = bytes(result);
        uint8 pos = 0;
        (addrLoaded,pos) = JSONLib.getNextAddr(v,pos);
        (userId,pos) = JSONLib.getNextUInt(v,pos);
        (login,pos) = JSONLib.getNextString(v,pos);
        if(userClaim[myid].sender == addrLoaded){
            dGit.__register(addrLoaded, userId, login);
        }
        delete userClaim[myid]; //should always be deleted
    }
    
    function _setRepository(bytes32 myid, string result) internal //[83725290, "ethereans/github-token", 4, 2]
    {
        uint256 projectId; string memory full_name; uint256 watchers; uint256 subscribers; 
        //uint256 ownerId; string memory name; //TODO
        bytes memory v = bytes(result);
        uint8 pos = 0;
        (projectId,pos) = JSONLib.getNextUInt(v,pos);
        (full_name,pos) = JSONLib.getNextString(v,pos);
        (watchers,pos) = JSONLib.getNextUInt(v,pos);
        (subscribers,pos) = JSONLib.getNextUInt(v,pos);
        dGit.__setRepository(projectId,full_name,watchers,subscribers);
    }

    function _claimCommit(bytes32 myid, string result)
     internal {
        uint256 total; uint256 userId;
        bytes memory v = bytes(result);
        uint8 pos = 0;
        (userId,pos) = JSONLib.getNextUInt(v,pos);
		(total,pos) = JSONLib.getNextUInt(v,pos);
		dGit.__claimCommit(commitClaim[myid].repository,commitClaim[myid].commitid,userId,total);
        delete commitClaim[myid]; 
    }
    
    //owner management
    function setAPICredentials(string _client_id, string _client_secret)
     only_owner {
         client = _client_id;
         secret = _client_secret;
         credentials = StringLib.concat("?client_id=${[decrypt] ", _client_id,"}&client_secret=${[decrypt] ", _client_secret,"}");
    }
    
      
    function setScript(string _script) only_owner{
        script = _script;
    }

    
    
    function clearAPICredentials()
     only_owner {
         credentials = "";
     }

}

library QueryFactory {

    function newGitHubAPI() returns (GitHubAPI){
        return new GitHubAPIOraclize();
    }

}