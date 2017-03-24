pragma solidity ^0.4.8;

/**
 * Contract that mint tokens by github commit stats
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

import "lib/ethereans/token/LockerToken.sol";
import "lib/ethereans/management/Owned.sol";

contract GitRepositoryToken is LockerToken {

    function GitRepositoryToken(string _repository) {
        setAttribute("name", _repository);
        setAttribute("symbol", "GIT");
        setDecimalBase(0);
    }
    
    function mint(address _who, uint256 _value)
     only_owner when_locked(false)) {
        _mint(_who,_value);
    }

}
