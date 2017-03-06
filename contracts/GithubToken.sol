pragma solidity ^0.4.8;

/**
 * Contract that mint tokens by github commit stats
 * This file contain two contracts: GitHubOracle and GitHubToken
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
 
import "lib/oraclizeAPI_0.4.sol";
import "Owned.sol";
import "CollaborationToken.sol";

contract GitHubToken is CollaborationToken, usingOraclize {

    //stores repository name, used for claim calls
    string private repository;
    //stores repository name in sha3, used by GitHubOracle
    bytes32 public sha3repository;
    //permanent storage of recipts of all commits
    mapping (bytes32 => CommitReciept) public commits;
    //Address of the oracle, used for github login address lookup
    GitHubOracle public oracle;
    //claim event
    event Claim(string claimer, string commitid, uint total);

    //stores the total and user, and if claimed (used against double claiming)
    struct CommitReciept {
        uint256 total;
        address user;
        bool claimed;
    }
    
    //protect against double claiming
    modifier not_claimed(string commitid) {
        if(isClaimed(commitid)) throw;
        _;
    }
    
    modifier only_oracle {
        if (msg.sender != address(oracle)) throw;
        _;
    }
    
    function GitHubToken(string _repository, GitHubOracle _oracle) 
     payable {
        oracle = _oracle;
        repository = _repository;
        sha3repository = sha3(_repository);
    }
    
    //checks if a commit is already claimed
    function isClaimed(string _commitid) 
     constant 
     returns (bool) {
        return commits[sha3(_commitid)].claimed;
    }   

    //oracle claim request
    function _claim(string _commitid, string _login, uint _total) 
     only_oracle {
        if(_total > 0 && !lock){
            bytes32 shacommit = sha3(_commitid); 
            address user = oracle.getUserAddress(_login);
            if(!commits[shacommit].claimed && user != 0x0){
                commits[shacommit].claimed = true;
                commits[shacommit].user = user;
                commits[shacommit].total = _total;
                accounts[user].balance += _total;
                totalSupply += _total;
                Claim(_login,_commitid,_total); 
            }
        }
    }
    
    //claims a commitid
    function claim(string _commitid) 
     payable 
     not_locked
     not_claimed(_commitid) {
        oracle.claimCommit(repository, _commitid);
   }

}

contract GitHubOracle is Owned, usingOraclize {
    //constant for oraclize commits callbacks
    uint8 constant CLAIM_USER = 0;
    //constant for oraclize commits callbacks
    uint8 constant CLAIM_COMMIT = 1;
    //temporary storage enumerating oraclize calls
    mapping (bytes32 => uint8) claimType;
    //temporary storage for oraclize commit token claim calls
    mapping (bytes32 => CommitClaim) commitClaim;
    //temporary storage for oraclize user register queries
    mapping (bytes32 => UserClaim) userClaim;
    //permanent storage of sha3(login) of github users
    mapping (bytes32 => address) users;
    //permanent storage of registered repositories
    mapping (bytes32 => Repository) repositories;
    //store encrypted values of api access credentials
    string private credentials = "";
    //events
    event UserSet(string githubLogin, address account);
    event RepositoryAdd(string repository, address account);
    
    //stores the address of githubtoken and registered is used for overwriting previous registered
    struct Repository {
        GitHubToken account;
        bool registered;
    }
    
    //stores temporary data for oraclize user register request
    struct UserClaim {
        address sender;
        bytes32 githubid;
        string login;
    }
    //stores temporary data for oraclize repository commit claim
    struct CommitClaim {
        bytes32 repository;
        string commitid;
    }
    
    //return the address of a github login
    function getUserAddress(string _login) 
     external 
     constant 
     returns (address) {
        return users[sha3(_login)];
    }

    //oraclize response callback
    function __callback(bytes32 _ocid, string _result) {
        if (msg.sender != oraclize_cbAddress()) throw;
        uint8 callback_type = claimType[_ocid];
        if(callback_type==CLAIM_USER){
            if(strCompare(_result,"404: Not Found") != 0){    
                address githubowner = parseAddr(_result);
                if(userClaim[_ocid].sender == githubowner){
                    _register(userClaim[_ocid].githubid,userClaim[_ocid].login,githubowner);
                }
            }
            delete userClaim[_ocid]; //should always be deleted
        }else if(callback_type==CLAIM_COMMIT){ 
            var (login,total) = extractCommit(_result);
            repositories[commitClaim[_ocid].repository].account._claim(commitClaim[_ocid].commitid,login,total);
            delete commitClaim[_ocid]; //should always be deleted
        }
        delete claimType[_ocid]; //should always be deleted
    }


    function _register(bytes32 githubid, string login, address githubowner) 
     internal {
        users[githubid] = githubowner;
        UserSet(login, githubowner);
    }
    
    //register or change a github user ethereum address
    function register(string _github_user, string _gistid)
     payable {
        bytes32 ocid = oraclize_query("URL", strConcat("https://gist.githubusercontent.com/",_github_user,"/",_gistid,"/raw/"));
        claimType[ocid] = CLAIM_USER;
        userClaim[ocid] = UserClaim({sender: msg.sender, githubid: sha3(_github_user), login: _github_user});
    }
    
    function claimCommit(string _repository, string _commitid)
     payable {
        bytes32 ocid = oraclize_query("URL", strConcat(strConcat("json(https://api.github.com/repos/", _repository,"/commits/", _commitid, credentials),").[author,stats].[login,total]"));
        claimType[ocid] = CLAIM_COMMIT;
        commitClaim[ocid] = CommitClaim({repository: sha3(_repository), commitid: _commitid });
    }
    
    //creates a new GitHubToken contract to _repository
    function addRepository(string _repository) 
     returns (GitHubToken) {
        bytes32 repo = sha3(_repository);
        if(repositories[repo].registered) throw;
        repositories[repo] = Repository({account: new GitHubToken(_repository, this), registered: true});
        RepositoryAdd(_repository, repositories[repo].account);
        return repositories[repo].account;
    }  
    
    //register a contract deployed outside Oracle
    function addRepository(string _repository, GitHubToken _addr)
     returns (GitHubToken) {
        bytes32 repo = sha3(_repository);
        if(repositories[repo].registered || _addr.sha3repository() != repo) throw;
        repositories[repo] = Repository({account: _addr, registered: true});
        RepositoryAdd(_repository, repositories[repo].account);
        return repositories[repo].account;
    }  
    
    //return the contract address of the repository (or 0x0 if none registered)
    function getRepository(string _repository) 
     constant 
     returns (GitHubToken) {
        return repositories[sha3(_repository)].account;
    }
    
    
    //extract login name and total of changes in commit
    function extractCommit(string _s)
     internal
     constant 
     returns (string login,uint total) {
        bytes memory v = bytes(_s);
        uint comma = 0;
        uint quot = 0;
        uint quot2 = 0;
        for (uint i =0;v.length > i;i++) {
            if (v[i] == '"'){ //Find first quotation mark
                quot=i;
                break;
                }
            }
        
        for (;v.length > i;i++) {
            if (v[i] == '"') { //find second quotation mark
                quot2=i;
            }else if (v[i] == ',') { //find comma
                comma=i;
                break;
            }
        }
        if(comma>0 && quot>0 && quot2 >0) {
            bytes memory user = new bytes(quot2-quot-1);
            for(i=0; i<user.length; i++){
                user[i] = v[quot+i+1];
            }
            login = string(user); //user
            for(i=comma+1; i<v.length-1; i++){
                if ((v[i] >= 48)&&(v[i] <= 57)){ //only ASCII numbers
                    total *= 10;
                    total += uint(v[i]) - 48;
                }
            }
        }
    }
            
    function setAPICredentials(string _client_id, string _client_secret)
     only_owner {
         credentials = strConcat("?client_id=${[decrypt] ",_client_id,"}&client_secret=${[decrypt] ",_client_secret,"}");
    }
    
    function clearAPICredentials()
     only_owner {
         credentials = "";
     }
}
