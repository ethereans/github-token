pragma solidity ^0.4.8;

/**
 * AbstractToken ECR20-compliant token contract
 * Child should implement initial supply or minting and overwite base
 * Based on BasicCoin by Parity Team (Ethcore), 2016.
 * By Ricardo Guilherme Schmidt
 * Released under the Apache Licence 2.
 */

import "./Token.sol";

// AbstractToken, ECR20 tokens that all belong to the owner for sending around
contract AbstractToken is Token {
    
    uint256 private decimalBase = 0;
    mapping (bytes => bytes) private attributes;
    mapping (address => Account) private accounts; 
    event Base(uint256 decimalBase);
    event SetAttribute(string name, string value);
    event Mint(address to, uint256 value);
    event Destroy(address from, uint256 value);
    
    
    struct Decimal {
        uint256 value;
        uint256 base;
    }
    
    struct Account {
        Decimal balance;
        mapping (address => Decimal) allowanceOf;
    }
    
    // the balance should be available
    modifier when_owns(address _owner, uint256 _amount) {
        if (balanceOf(_owner) < _amount) throw;
        _;
    }

    // an allowance should be available
    modifier when_has_allowance(address _owner, address _spender, uint256 _amount) {
        if (allowance(_owner,_spender) < _amount) throw;
        _;
    }

    //correct base and balance if needed    
    function _safeDecimals(Decimal _decimal) 
     internal
     constant returns(Decimal){
        if(_decimal.base != decimalBase) { 
            if(_decimal.value > 0){
                int256 baseDiff = int256(_decimal.base) - int256(decimalBase); 
                if(baseDiff > 0){
                    _decimal.value *= 10**uint256(baseDiff);
                }else if(baseDiff < 0){
                    uint256 oldv = _decimal.value;
                    uint256 newv = _decimal.value/(10**uint256(baseDiff*-1));
                    _decimal.value = oldv > newv ? newv : 0; 
                }
            }
            _decimal.base = decimalBase; //update base of account
        }
        return _decimal;
    }
    
    //_safeDecimals wrapper for safe add;
    function _safeDecimalsAdd(Decimal _decimal, uint256 _value) 
     internal
     constant returns(Decimal){
        _decimal = _safeDecimals(_decimal);
        _decimal.value += _value;
        return _decimal;
    }
    
    function _safeDecimalsSub(Decimal _decimal, uint256 _value) 
     internal
     constant returns(Decimal){
        _decimal = _safeDecimals(_decimal);
        _decimal.value -= _value;
        return _decimal;
    } 
    //_safeDecimals wrapper for safe sub;
    function base() 
     constant returns(uint256) { 
        return decimalBase;
    }
    
    //child may override this function to trigger changes in balance dependent storage
    function _balanceUpdated(address _from) 
     internal {
        
    }
    
    /**
     * changes the decimal base
     * lowereing base remove precision of most significant digits
     * rising base remove precision of last significant digits
     */
    function setDecimalBase(uint256 _decimalBase)
     internal {
        Base(_decimalBase);
        decimalBase = _decimalBase;
    }
    
    //sets attributes for wallet usage
    function setAttribute(string _name, string _value)
     internal {
        SetAttribute(_name,_value);
        if (bytes(_value).length > 0) attributes[bytes(_name)] = bytes(_value);
        else delete attributes[bytes(_name)];
    }
    
    //read an attribute from storage
    function getAttribute(string _name)
     constant returns (string){
        return string(attributes[bytes(_name)]);
    }

    // add tokens to a balance
    function _mint(address _to, uint256 _value)
     internal {
        if (totalSupply + _value < totalSupply) throw; //overflow: maximum totalSupply in the current base;
        Mint(_to, _value);
        totalSupply += _value;
        accounts[_to].balance = _safeDecimalsAdd(accounts[_to].balance,_value); 
        _balanceUpdated(_to);
    }

    // remove tokens from a balance    
    function _destroy(address _from, uint256 _value)
     internal {
        Destroy(_from, _value);
        totalSupply -= _value;
        accounts[_from].balance = _safeDecimalsSub(accounts[_from].balance,_value);   
        if(accounts[_from].balance.value == 0){ 
            delete accounts[_from]; //to reduce gas in mapping accounts
        }
        _balanceUpdated(_from);
    }

    // balance of a specific address
    function balanceOf(address _who) 
     constant 
     returns (uint256) {
        return _safeDecimals(accounts[_who].balance).value;
    }

    // transfer
    function transfer(address _to, uint256 _value) 
     when_owns(msg.sender, _value) 
     returns (bool) {
        Transfer(msg.sender, _to, _value);
        accounts[msg.sender].balance = _safeDecimalsSub(accounts[msg.sender].balance, _value);
        accounts[_to].balance = _safeDecimalsAdd(accounts[_to].balance, _value);
        _balanceUpdated(msg.sender);
        _balanceUpdated(_to);
        return true;
    }

    // transfer via allowance
    function transferFrom(address _from, address _to, uint256 _value) 
     when_owns(_from, _value) 
     when_has_allowance(_from, msg.sender, _value) 
     returns (bool) {
        Transfer(_from, _to, _value);
        accounts[_from].allowanceOf[msg.sender] = _safeDecimalsSub(accounts[_from].allowanceOf[msg.sender], _value);
        accounts[_from].balance = _safeDecimalsSub(accounts[msg.sender].balance, _value);
        accounts[_to].balance = _safeDecimalsAdd(accounts[_to].balance, _value);
        _balanceUpdated(_from);
        _balanceUpdated(_to);
        return true;
    }

    // set allowance
    function approve(address _spender, uint256 _totalAllowed) 
     returns (bool) {
        Approval(msg.sender, _spender, _totalAllowed);
        accounts[msg.sender].allowanceOf[_spender].value = _totalAllowed;
        accounts[msg.sender].allowanceOf[_spender].base = decimalBase;
        if(_totalAllowed == 0){ 
            delete accounts[msg.sender].allowanceOf[_spender]; //lower gas in interactions
        }
        return true;
    }

    // available allowance
    function allowance(address _owner, address _spender) 
     constant 
     returns (uint256) {
        return _safeDecimals(accounts[_owner].allowanceOf[_spender]).value;
    }

}
