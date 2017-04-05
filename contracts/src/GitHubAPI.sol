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
    string private cred = ""; 
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
    
    function updateCommits(string _repository, bytes20 _commitid)
     payable only_owner{
        string memory cred = StringLib.concat(" -c ${[decrypt] ", _client_id,"} -s ${[decrypt] ", _client_secret,"}");
        string memory commit_url = StringLib.concat("-S update-commits -r",_repository," -H ", toString(_commitid), cred);
        bytes32 ocid = oraclize_query("computation", ['']);
        claimType[ocid] = OracleType.CLAIM_COMMIT;
        commitClaim[ocid] = CommitClaim( { repository: _repository, commitid:_commitid});
    }
    
    function addRepository(string _repository)
     payable only_owner{
        bytes32 ocid = oraclize_query("URL", StringLib.concat("json(https://api.github.com/repos/",_repository,credentials,").$.id,full_name,watchers,subscribers_count"),4000000);
        claimType[ocid] = OracleType.SET_REPOSITORY;
    }  

    function updateIssue(string _repository, string issue) payable only_owner{
         bytes32 ocid = oraclize_query("computation", [script, StringLib.concat("--reponame ",_repository, " --issueid ", issue, " --script issue-update").concat(" --client ", client, " --secret ", secret)]);
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
    //034dacf29ac24ca92691d1ae2520882cc93a4df7,"a6690859cc20e27d2aad9ce1278778be10b7cc5a",  4,  [('adrian-tiberius', 10), ('kagel', 10854), ('tpatja', 14509), ('jarradh', 1367)]
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
            dGit._setCommiter(commitClaim[myid].repository,userId,points);
        }
        delete commitClaim[myid]; 
    }
    
    //owner management
    function setAPICredentials(string _client_id, string _client_secret)
     only_owner {
         client = _client_id;
         secret = _client_secret;
         cred = StringLib.concat(" -c ${[decrypt] ", _client_id,"} -s ${[decrypt] ", _client_secret,"}");
         credentials = StringLib.concat("?client_id=${[decrypt] ", _client_id,"}&client_secret=${[decrypt] ", _client_secret,"}");
    }
    
      
    function setScript(string _script) only_owner{
        script = _script;
    }

    
    
    function clearAPICredentials()
     only_owner {
         credentials = "";
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