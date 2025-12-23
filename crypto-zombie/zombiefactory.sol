// SPDX-License-Identifier: cryptozombie 
// Version de Solidity à utiliser >, >=, =, <=, < peuvent être utilisés
pragma solidity ^0.8.33;

// Import de ownable
import "./ownable.sol";

// Déclaration du contrat
// "is" permet l'héritage de "ownable" dans "ZombieFactory", ici nous avons accès aux éléments disponibles dans ownable
contract ZombieFactory is Ownable {

    event NewZombie(uint zombieId, string name, uint dna);

    // entiers non signés uint == uint256 (uint8, uint16, uint32... uint%8)
    uint dnaDigits = 16;
    uint dnaModulus = 10 ** dnaDigits;

    // comme un objet TypeScript
    struct Zombie {
        string name;
        uint dna;
    }

    // "zombies" est un tableau dynamique remplis de Zombie. On peut donner une taille définie aux tableaux avec "uint32[100] public myLimitedNumbers;" "myLimitedNumbers" ne pourra contenir que 100 nombres de type "uint32"
    Zombie[] public zombies;

    mapping (uint => address) public zombieToOwner;
    mapping (address => uint) ownerZombieCount;

    // déclaration et construction d'une fonction avec le mot clé "function"
    function _createZombie(string _name, uint _dna) internal {
        uint id = zombies.push(Zombie(_name, _dna)) - 1;
        // msg.sender est le déployeur du contrat
        zombieToOwner[id] = msg.sender;
        ownerZombieCount[msg.sender]++;
        NewZombie(id, _name, _dna);
    }

    function _generateRandomDna(string _str) private view returns (uint) {
        uint rand = uint(keccak256(_str));
        return rand % dnaModulus;
    }

    function createRandomZombie(string _name) public {
        require(ownerZombieCount[msg.sender] == 0);
        uint randDna = _generateRandomDna(_name);
        randDna = randDna - randDna % 100;
        _createZombie(_name, randDna);
    }

}
