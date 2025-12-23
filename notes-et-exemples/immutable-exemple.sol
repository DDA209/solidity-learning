// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract Example {
    address public immutable deployer;
    uint256 public immutable deploymentTime;
    
    constructor(uint256 _time) {
        deployer = msg.sender;  // Déterminé au déploiement
        deploymentTime = _time;  // Paramètre du constructeur
    }
}