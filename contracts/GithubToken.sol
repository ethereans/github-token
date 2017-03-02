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
import "LockableCoin.sol";

contract GitHubToken is LockableCoin, usingOraclize {
    //constant for oraclize commits callbacks
    uint8 constant CALLBACK_CLAIMCOMMIT = 1;
    //stores repository name, used for claim calls
    string private repository;
    //stores repository name in sha3, used by GitHubOracle
    bytes32 public sha3repository;
    //temporary storage enumerating oraclize calls
    mapping (bytes32 => uint8) oraclize_type;
    //temporary storage for oraclize commit token claim calls
    mapping (bytes32 => string) oraclize_claim;
    //permanent storage of recipts of all commits
    mapping (bytes32 => CommitReciept) public commits;
    //Address of the oracle, used for github login address lookup
    GitHubOracle public oracle;
    //claim event
    event Claim(address claimer, string commitid, uint total);

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

    //oraclize response callback
    function __callback(bytes32 _ocid, string _result) {
        if (msg.sender != oraclize_cbAddress()) throw;
        uint8 callback_type = oraclize_type[_ocid];
        if(callback_type==CALLBACK_CLAIMCOMMIT && !lock){
            _claim(_ocid,_result);
        }
        delete oraclize_type[_ocid];
    }
    
    //oraclize callback claim request
    function _claim(bytes32 _ocid, string _result) 
     internal {
        var (login,total) = extract(_result);
        address user = oracle.getUserAddress(login);
        if(user != 0x0){
            commits[sha3(oraclize_claim[_ocid])].user = user;
            if(total > 0){
                bytes32 shacommit = sha3(oraclize_claim[_ocid]);
                commits[shacommit].total = total;
                if(commits[shacommit].user != 0x0 && !commits[shacommit].claimed){
                    commits[shacommit].claimed = true;
                    accounts[user].balance += total;
                    totalSupply += total;
                    Claim(user,oraclize_claim[_ocid],total);
                }
            }
        }
        delete oraclize_claim[_ocid];
    }
    
    //claims a commitid
    function claim(string _commitid) 
     payable 
     not_locked
     not_claimed(_commitid) {
        bytes32 ocid = oraclize_query("URL", strConcat("json(https://api.github.com/repos/", repository,"/commits/", _commitid,").[author,stats].[login,total]"));
        oraclize_type[ocid] = CALLBACK_CLAIMCOMMIT;
        oraclize_claim[ocid] = _commitid;
   }

    //extract login name and total of changes in commit
    function extract(string _s)
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
}

contract GitHubOracle is usingOraclize {
    //constant for oraclize commits callbacks
    uint8 constant CALLBACK_REGISTER = 0;
    //temporary storage enumerating oraclize calls
    mapping (bytes32 => uint8) oraclize_type;
    //temporary storage for oraclize user register queries
    mapping (bytes32 => VerifyRequest) oraclize_register;
    //permanent storage of sha3(login) of github users
    mapping (bytes32 => address) github_users;
    //permanent storage of registered repositories
    mapping (bytes32 => Repository) repositories;
    //events
    event UserSet(string githubLogin, address account);
    event RepositoryAdd(string repository, address account);
    
    //stores the address of githubtoken and registered is used for overwriting previous registered
    struct Repository {
        GitHubToken account;
        bool registered;
    }
    
    //stores data for oraclize user register request
    struct VerifyRequest {
        address sender;
        bytes32 githubid;
        string login;
    }
    
    //return the address of a github login
    function getUserAddress(string _login) 
     external 
     constant 
     returns (address) {
        return github_users[sha3(_login)];
    }

    //oraclize response callback
    function __callback(bytes32 _ocid, string result) {
        if (msg.sender != oraclize_cbAddress()) throw;
        uint8 callback_type = oraclize_type[_ocid];
        if(callback_type==CALLBACK_REGISTER){
            if(strCompare(result,"404: Not Found") != 0){    
                address githubowner = parseAddr(result);
                if(oraclize_register[_ocid].sender == githubowner){
                    github_users[oraclize_register[_ocid].githubid] = githubowner;
                    UserSet(oraclize_register[_ocid].login, githubowner);
                }
            }
            delete oraclize_register[_ocid];
        }
        delete oraclize_type[_ocid];
    }

    //register or change a github user ethereum address
    function register(string _github_user, string _gistid)
     payable {
        bytes32 ocid = oraclize_query("URL", strConcat("https://gist.githubusercontent.com/",_github_user,"/",_gistid,"/raw/"));
        oraclize_type[ocid] = CALLBACK_REGISTER;
        oraclize_register[ocid] = VerifyRequest({sender: msg.sender, githubid: sha3(_github_user), login: _github_user});
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
}
