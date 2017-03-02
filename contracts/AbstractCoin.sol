pragma solidity ^0.4.1;

/**
 * AbstractCoin ECR20-compliant token contract
 * Child should implement initial supply or minting and overwite base
 * Based on BasicCoin by Parity Team (Ethcore), 2016.
 * By Ricardo Guilherme Schmidt
 * Released under the Apache Licence 2.
 */

import "Token.sol";

// AbstractCoin, ECR20 tokens that all belong to the owner for sending around
contract AbstractCoin is Token {
    // the base, tokens denoted in micros
    uint constant public base = 0;

    // storage and mapping of all balances & allowances
    mapping (address => Account) accounts; 

    // this is as basic as can be, only the associated balance & allowances
    struct Account {
        uint balance;
        mapping (address => uint) allowanceOf;
    }

    // the balance should be available
    modifier when_owns(address _owner, uint _amount) {
        if (accounts[_owner].balance < _amount) throw;
        _;
    }

    // an allowance should be available
    modifier when_has_allowance(address _owner, address _spender, uint _amount) {
        if (accounts[_owner].allowanceOf[_spender] < _amount) throw;
        _;
    }
    
    // A helper to notify if overflow occurs
    modifier safe_add(uint a, uint b)  {
        if (a + b < a && a + b < b) throw;
        _;
    } 

    // balance of a specific address
    function balanceOf(address _who) 
     constant 
     returns (uint256) {
        return accounts[_who].balance;
    }

    // transfer
    function transfer(address _to, uint256 _value) 
      when_owns(msg.sender, _value) 
     safe_add(accounts[_to].balance, _value) 
     returns (bool) {
        Transfer(msg.sender, _to, _value);
        accounts[msg.sender].balance -= _value;
        accounts[_to].balance += _value;
        return true;
    }

    // transfer via allowance
    function transferFrom(address _from, address _to, uint256 _value) 
     when_owns(_from, _value) 
     when_has_allowance(_from, msg.sender, _value) 
     safe_add(accounts[_to].balance, _value)
     returns (bool) {
        Transfer(_from, _to, _value);
        accounts[_from].allowanceOf[msg.sender] -= _value;
        accounts[_from].balance -= _value;
        accounts[_to].balance += _value;
        return true;
    }

    // approve allowances
    function approve(address _spender, uint256 _value) 
     returns (bool) {
        Approval(msg.sender, _spender, _value);
        accounts[msg.sender].allowanceOf[_spender] += _value;
        return true;
    }

    // available allowance
    function allowance(address _owner, address _spender) 
     constant 
     returns (uint256) {
        return accounts[_owner].allowanceOf[_spender];
    }

}
