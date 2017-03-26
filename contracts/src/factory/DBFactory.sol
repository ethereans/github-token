pragma solidity ^0.4.8;

/**
 * By Ricardo Guilherme Schmidt
 * Released under GPLv3 License
 */

import "../storage/GitHubOracleStorage.sol";


library DBFactory {

    function newStorage() returns (GitHubOracleStorageI){
        GitHubOracleStorage db = new GitHubOracleStorage();
        return db;
    }

}