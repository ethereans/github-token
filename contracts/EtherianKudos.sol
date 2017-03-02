pragma solidity ^0.4.1;

/**
 * Mintable coin with register of reason of minting
 * Accept donations and can be withdrawn by token holders
 * 
 * By Ricardo Guilherme Schmidt
 * Released under GPLv3 License
 */
 
import "LockableCoin.sol";

contract EtherianKudos is LockableCoin {
    event NewMinter(address minter, address newMinter);
    event TokenMint(address minter, address beneficiary, string data);
    event Verified(address minter, address newMinter);
    mapping (uint => Receipt) public receipts;
    mapping (address => bool) public minters;

    // storage of minting reason
    struct Receipt {  
        address minter;
        address beneficiary;
        string data;
    }
    
    // the balance should be available
    modifier when_minter(address _minter) {
        if (!minters[_minter]) throw;
        _;
    }

    function EtherianKudos(address _minter) {
        _add_minter(0x0,_minter);
    }

    function mint(address _beneficiary, string _data) 
     not_locked
     when_minter(msg.sender) {
        totalSupply++;
        accounts[_beneficiary].balance++;
        receipts[totalSupply].minter = msg.sender;
        receipts[totalSupply].beneficiary = _beneficiary;
        receipts[totalSupply].data = _data;
        TokenMint(msg.sender, _beneficiary, _data);
    }

    function setMinter(address _newMinter) 
     when_minter(msg.sender) {
        _add_minter(msg.sender, _newMinter);
    }
    
    function _add_minter(address _minter, address _newMinter) 
     internal {
        minters[_newMinter] = true;    
        NewMinter(_minter,_newMinter);
    }
}
