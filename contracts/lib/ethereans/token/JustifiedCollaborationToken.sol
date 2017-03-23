pragma solidity ^0.4.1;

/**
 * Mintable Collaboration coin with register of reason of minting
 * 
 * By Ricardo Guilherme Schmidt
 * Released under GPLv3 License
 */

import "../management/Owned.sol"; 
import "./CollaborationToken.sol";

contract JustifiedCollaborationToken is CollaborationToken, Owned {
    event Claim(bytes32 _data);
    mapping (bytes32 => Receipt) public receipts;
    mapping (address => bool) public minters;
    
    // storage of minting reason
    struct Receipt {  
        address beneficiary;
        uint256 value;
        bool claimed;
    }
    
    function claim(address _beneficiary, uint256 _value, bytes32 _data) 
     not_locked
     only_owner {
        if(receipts[_data].claimed) throw;
        receipts[_data] = Receipt ({beneficiary: _beneficiary, value: _value, claimed: true});
        _mint(_beneficiary,_value);
        Claim(_data);
    }

}
