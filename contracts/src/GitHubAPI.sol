pragma solidity ^0.4.9;

import "lib/oraclize/oraclizeAPI_0.4.sol";
import "lib/StringLib.sol";
import "lib/JSONLib.sol";
import "lib/ethereans/management/Owned.sol";


contract GitHubAPI{
     function register(address _sender, string _github_user, string _gistid) payable;
     function updateCommits(string _full_name, string _branch, bytes20 _commitid) payable;
     function addRepository(string _full_name) payable;
     function updateIssue(string _full_name, string _issue) payable;
}

contract DGitI {
    function __register(address addrLoaded, uint256 userId, string login);
    function __addRepository(uint256 projectId, string full_name, string default_branch);
    function __setHead(uint256 projectId, string branch, bytes20 head);
    function __setTail(uint256 projectId, string branch, bytes20 tail);
    function __newPoints(uint256 projectId, uint256 userId, uint total);
    function __setIssue(uint256 projectId, uint256 issueId, bool state, uint256 closedAt);
    function __setIssuePoints(uint256 projectId, uint256 issueId, uint256 userId, uint256 points);
}

contract GitHubAPIOraclize is GitHubAPI, Owned, usingOraclize{
    using StringLib for string;
    DGitI dGit
    
    string private cred = "f94095ba1d48038d4a81,36ae0e8b1bc5ad261c936e8f7f730f6c827c221f"; 
    string private credentials = "?client_id=f94095ba1d48038d4a81&client_secret=36ae0e8b1bc5ad261c936e8f7f730f6c827c221f";
    string private script = "QmU6pSQMDSg8do9eZLAfjzZYcC9JpsMZeB4ZoteGkSe94y";
    
    enum OracleType { ADD_REPOSITORY, SET_USER, CLAIM_COMMIT, CLAIM_CONTINUE, UPDATE_ISSUE }
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
    
    function GitHubAPIOraclize(){
        dGit = DGitI(msg.sender);
        oraclize_setProof(proofType_TLSNotary | proofStorage_IPFS);
    }
    
    //register or change a github user ethereum address. 100000000000000000
    function register(address _sender, string _github_user, string _gistid)
         payable only_owner{
            bytes32 ocid = oraclize_query("nested", StringLib.concat("[identity] ${[URL] https://gist.githubusercontent.com/",_github_user,"/",_gistid,"/raw/}, ${[URL] json(https://api.github.com/gists/").concat(_gistid,credentials,").owner.[id,login]}"));
            claimType[ocid] = OracleType.SET_USER;
            userClaim[ocid] = UserClaim({sender: _sender, githubid: _github_user});
    }
    
    function addRepository(string _repository)
     payable only_owner{
        bytes32 ocid = oraclize_query("URL", StringLib.concat("json(https://api.github.com/repos/",_repository,credentials,").$.id,full_name,default_branch"),4000000);
        claimType[ocid] = OracleType.ADD_REPOSITORY;
    }
    
    function updateCommits(string _repository, string _branch, bytes20 _commitid)
     payable only_owner{
        bytes32 ocid = oraclize_query("computation", [script, "update-new",_repository.concat(",", _branch,",",toString(_commitid)),cred]);
        claimType[ocid] = OracleType.CLAIM_COMMIT;
        commitClaim[ocid] = CommitClaim( { repository: _repository, commitid:_commitid});
    }
    
    function continueUpdateCommits(string _repository, string _branch, bytes20 _lastCommit,bytes20 _limitCommit)
     payable only_owner{
        bytes32 ocid = oraclize_query("computation", [script, "update-old",_repository.concat(",", _branch,",",toString(_lastCommit)).concat(",",toString(_limitCommit)),cred]);
        claimType[ocid] = OracleType.CLAIM_CONTINUE;
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
        }else if(claimType[myid] == OracleType.ADD_REPOSITORY){
            _addRepository(myid, result);
        }else if(claimType[myid]==OracleType.CLAIM_COMMIT){ 
            _updateCommits(myid, result, false);
        }else if(claimType[myid]==OracleType.CLAIM_CONTINUE){ 
            _updateCommits(myid, result, true);
        }else if(claimType[myid] == OracleType.UPDATE_ISSUE){
            _updateIssue(myid, result);
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
    

    function _addRepository(bytes32 myid, string result) internal //[85743750, "ethereans/TheEtherian", "master"]
    {
        bytes memory v = bytes(result);
        uint8 pos = 0;
        string memory temp;
        uint256 projectId; 
        (projectId,pos) = JSONLib.getNextUInt(v,pos);
        string memory full_name;
        (full_name,pos) = JSONLib.getNextString(v,pos);
        string memory default_branch;
        (default_branch,pos) = JSONLib.getNextString(v,pos);
        dGit.__addRepository(projectId,full_name,default_branch);
     }
    
    function _updateCommits(bytes32 myid, string result, bool continuing)
     internal {
        bytes memory v = bytes(result);
        uint8 pos = 0;
        string memory temp;
        uint256 projectId; 
        (projectId,pos) = JSONLib.getNextUInt(v,pos);
        string memory branch;
        (branch,pos) = JSONLib.getNextString(v,pos);
        (temp,pos) = JSONLib.getNextString(v,pos);
        bytes20 head = temp.toBytes20();
        (temp,pos) = JSONLib.getNextString(v,pos);
        bytes20 tail = temp.toBytes20();
        uint numAuthors;
        (numAuthors,pos) = JSONLib.getNextUInt(v,pos);
        uint userId;
        uint points;
        dGit.__setHead(projectId,branch,head);
        if(continuing){
            dGit.__setTail(projectId,branch,tail);    
        }else{
            bytes20 oldCommit = commitUpdate[myid].commitid;
            if(oldCommit == 0x0){
                dGit.__setTail(projectId,branch,tail);    
            }else if (oldCommit != tail){
                //TODO: acceptContinueUpdateUntilLimit(tail,oldCommit)
            }
        }
        for(uint i; i < numAuthors; i++){
            (userId,pos) = JSONLib.getNextUInt(v,pos);
            (points,pos) = JSONLib.getNextUInt(v,pos);
            dGit.__newPoints(projectId,userId,points);
        }
    }
    
    function _updateIssue(bytes32 myid, string result) 
     internal {
        bytes memory v = bytes(result);
        uint8 pos = 0;
        string memory temp;
        uint256 projectId; 
        (projectId,pos) = JSONLib.getNextUInt(v,pos);
        uint256 issueId; 
        (issueId,pos) = JSONLib.getNextUInt(v,pos);
        bool state;
        (temp,pos) = JSONLib.getNextString(v,pos);
        state = (temp.compare("open") == 0);
        uint256 closedAt; 
        (closedAt,pos) = JSONLib.getNextUInt(v,pos);
        uint numAuthors;
        (numAuthors,pos) = JSONLib.getNextUInt(v,pos);
        uint userId;
        uint points;
        dGit.__setIssue(projectId,issueId,state,closedAt);
        for(uint i; i < numAuthors; i++){
            (userId,pos) = JSONLib.getNextUInt(v,pos);
            (points,pos) = JSONLib.getNextUInt(v,pos);
            dGit.__setIssuePoints(projectId,issueId,userId,points);
        }
    }
    
    //owner management
    function setAPICredentials(string _client_id, string _client_secret)
     only_owner {
         cred = StringLib.concat(_client_id,",", _client_secret);
         credentials = StringLib.concat("?client_id=",_client_id,"&client_secret="+_client_secret);
    }
    
    function setScript(string _script) only_owner{
        script = _script;
    }

    function clearAPICredentials()
     only_owner {
         cred = "";
         credentials = "";
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