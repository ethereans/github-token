pragma solidity ^0.4.8;

contract Owned {
    address public owner= msg.sender;
    event NewOwner(address owner);
    
    function Owned(){
        NewOwner(owner);
    }
    
    modifier only_owner {
        if (msg.sender != owner) throw;
        _;
    }
    
    function setOwner(address _owner)
     only_owner {
        owner = _owner;
        NewOwner(_owner);
    }
}