pragma solidity ^0.4.9;

import "lib/oraclize/oraclizeAPI_0.4.sol";
import "lib/StringLib.sol";
import "lib/JSONLib.sol";
import "lib/ethereans/management/Owned.sol";


contract GitHubAPI{
     function register(address _sender, string _github_user, string _gistid) payable;
     function updateCommits(string _repository, bytes20 _commitid) payable;
     function addRepository(string _repository) payable;
     function updateIssue(string _repository, string issue) payable;
}

contract DGitI {
    function __register(address addrLoaded, uint256 userId, string login);
    function __setRepository(uint256 projectId, string full_name, uint256 watchers, uint256 subscribers);
    function __newPoints(string repository, uint userId, uint total);
}

contract GitHubAPIOraclize is GitHubAPI, Owned, usingOraclize{
  using StringLib for string;
  
    DGitI dGit;
    function GitHubAPIOraclize(){
        dGit = DGitI(msg.sender);
        oraclize_setProof(proofType_TLSNotary | proofStorage_IPFS);
    }
    string private cred = "f94095ba1d48038d4a81,36ae0e8b1bc5ad261c936e8f7f730f6c827c221f"; 
    string private script = "QmU6pSQMDSg8do9eZLAfjzZYcC9JpsMZeB4ZoteGkSe94y";
    
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
    
    function updateCommits(string _repository, bytes20 _commitid)
     payable only_owner{
        bytes32 ocid = oraclize_query("computation", [script, "repo-update",_repository.concat(",", toString(_commitid)),cred]);
        claimType[ocid] = OracleType.CLAIM_COMMIT;
        commitClaim[ocid] = CommitClaim( { repository: _repository, commitid:_commitid});
    }
    
    function addRepository(string _repository)
     payable only_owner{
        bytes32 ocid = oraclize_query("URL", StringLib.concat("json(https://api.github.com/repos/",_repository,credentials,").$.id,full_name,watchers,subscribers_count"),4000000);
        claimType[ocid] = OracleType.SET_REPOSITORY;
    }
    
    function updateIssue(string _repository, string issue) payable only_owner{
         bytes32 ocid = oraclize_query("computation", [script, "issue-update",_repository.concat(",",issue),cred]);
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
            _updateCommits(myid, result);
        }else if(claimType[myid] == OracleType.SET_REPOSITORY){
            _setRepository(myid, result);
        }else if(claimType[myid] == OracleType.UPDATE_ISSUE){
            _updateIssue(myid, result);
        }
        delete claimType[myid];  //should always be deleted
    }

    function _updateIssue(bytes32 myid, string result) 
     internal {
         
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
    
    function _updateCommits(bytes32 myid, string result)
     internal {
        bytes memory v = bytes(result);
        uint8 pos = 0;
        string memory temp;
        uint numAuthors;
        (temp,pos) = JSONLib.getNextString(v,pos);
        bytes20 head = temp.toBytes20();
        (temp,pos) = JSONLib.getNextString(v,pos);
        bytes20 tail = temp.toBytes20();
        (numAuthors,pos) = JSONLib.getNextUInt(v,pos);
        uint userId;
        uint points;
        for(uint i; i < numAuthors; i++){
            (userId,pos) = JSONLib.getNextUInt(v,pos);
            (points,pos) = JSONLib.getNextUInt(v,pos);
            dGit.__newPoints(commitClaim[myid].repository,userId,points);
        }
        delete commitClaim[myid]; 
    }
    
    //owner management
    function setAPICredentials(string _client_id, string _client_secret)
     only_owner {
         cred = StringLib.concat(_client_id,",", _client_secret);
    }
    
    function setScript(string _script) only_owner{
        script = _script;
    }

    function clearAPICredentials()
     only_owner {
         cred = "";
     }

    function toString(bytes20 self) internal constant returns (string) {
        bytes memory bytesString = new bytes(20);
        uint charCount = 0;
        for (uint j = 0; j < 20; j++) {
            byte char = byte(bytes20(uint(self) * 2 ** (8 * j)));
            if (char != 0) {
                bytesString[charCount] = char;
                charCount++;
            }
        }
        bytes memory bytesStringTrimmed = new bytes(charCount);
        for (j = 0; j < charCount; j++) {
            bytesStringTrimmed[j] = bytesString[j];
        }
        return string(bytesStringTrimmed);
    }

}

library QueryFactory {

    function newGitHubAPI() returns (GitHubAPI){
        return new GitHubAPIOraclize();
    }

}