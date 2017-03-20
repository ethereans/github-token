pragma solidity ^0.4.8;

contract Secret {
    
    /**
     * @var token (stores the current token)
     */
    bytes32 private token;    
    mapping (bytes32 => bool) tokens;
    /**
     * @param secret the revealed secret
     * @param _token the keccak256 hash of next secret
     */
    modifier secret(bytes32 secret, bytes32 _token){ 
        setToken(secret,_token);
        _;
    }
    
    /**
     * @param _token the keccak256 hash of next secret
     */    
    function Secret(bytes32 _token){
        token = _token;
    }
    
    /**
     * @notice secret use current token to replace it by new _token
     * @param secret the revealed secret
     * @param _token the keccak256 hash of next secret
     */
    function setToken(bytes32 secret, bytes32 _token){
        if(tokens[_token] == true) throw; 
        if(keccak256(secret) != token) throw;
        tokens[token] = true;
        token = _token; 
    }
    

}