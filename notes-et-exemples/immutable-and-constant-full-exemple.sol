// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/**
 * @title RealisticTokenVesting
 * @notice Contrat de vesting de tokens avec toutes les utilisations de constant et immutable
 */
contract RealisticTokenVesting {
    
    // ========== CONSTANTS ==========
    // Valeurs fixes, connues à la compilation
    
    uint256 public constant SECONDS_PER_DAY = 86400;
    uint256 public constant DAYS_PER_MONTH = 30;
    uint256 public constant VESTING_DURATION_DAYS = 365; // 1 an
    uint256 public constant CLIFF_DURATION_DAYS = 90;    // 3 mois
    
    // Pourcentages (base 10000 pour 2 décimales)
    uint256 public constant INITIAL_RELEASE_PERCENT = 1000;  // 10%
    uint256 public constant BASIS_POINTS = 10000;            // 100%
    
    // Limites du protocole
    uint256 public constant MIN_VESTING_AMOUNT = 1000 * 10**18;  // 1000 tokens
    uint256 public constant MAX_VESTING_AMOUNT = 10000000 * 10**18; // 10M tokens
    uint256 public constant MAX_BENEFICIARIES = 1000;
    
    // Adresses fixes du protocole
    address public constant TREASURY = 0x1234567890123456789012345678901234567890;
    address public constant BURN_ADDRESS = address(0);
    
    // Identifiants de rôles
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    
    
    // ========== IMMUTABLES ==========
    // Valeurs fixées au déploiement, dépendent du contexte
    
    address public immutable token;              // Adresse du token ERC20
    address public immutable deployer;           // Qui a déployé le contrat
    address public immutable feeCollector;       // Collecteur de frais
    uint256 public immutable deploymentTime;     // Timestamp de déploiement
    uint256 public immutable vestingStartTime;   // Début du vesting
    uint256 public immutable protocolFee;        // Frais du protocole (en basis points)
    uint256 public immutable chainId;            // ID de la blockchain
    bool public immutable isTestnet;             // Mode testnet ou mainnet
    
    // Paramètres calculés au déploiement
    uint256 public immutable cliffEndTime;
    uint256 public immutable vestingEndTime;
    uint256 public immutable minClaimInterval;
    
    
    // ========== VARIABLES D'ÉTAT ==========
    // Données qui changent pendant l'exécution
    
    struct VestingSchedule {
        uint256 totalAmount;
        uint256 releasedAmount;
        uint256 startTime;
        uint256 lastClaimTime;
        bool revoked;
    }
    
    mapping(address => VestingSchedule) public vestingSchedules;
    address[] public beneficiaries;
    uint256 public totalVestedAmount;
    bool public paused;
    
    
    // ========== EVENTS ==========
    
    event VestingCreated(address indexed beneficiary, uint256 amount, uint256 startTime);
    event TokensClaimed(address indexed beneficiary, uint256 amount);
    event VestingRevoked(address indexed beneficiary, uint256 unvestedAmount);
    event FeePaid(address indexed payer, uint256 amount);
    
    
    // ========== CONSTRUCTOR ==========
    
    constructor(
        address _token,
        address _feeCollector,
        uint256 _vestingStartTime,
        uint256 _protocolFee,
        bool _isTestnet
    ) {
        require(_token != address(0), "Invalid token address");
        require(_feeCollector != address(0), "Invalid fee collector");
        require(_protocolFee <= 1000, "Fee too high"); // Max 10%
        require(_vestingStartTime >= block.timestamp, "Start time in past");
        
        // Initialisation des immutables avec paramètres
        token = _token;
        feeCollector = _feeCollector;
        vestingStartTime = _vestingStartTime;
        protocolFee = _protocolFee;
        isTestnet = _isTestnet;
        
        // Initialisation des immutables avec valeurs du contexte
        deployer = msg.sender;
        deploymentTime = block.timestamp;
        chainId = block.chainid;
        
        // Calculs basés sur constants et immutables
        cliffEndTime = _vestingStartTime + (CLIFF_DURATION_DAYS * SECONDS_PER_DAY);
        vestingEndTime = _vestingStartTime + (VESTING_DURATION_DAYS * SECONDS_PER_DAY);
        
        // Intervalle minimum différent selon testnet/mainnet
        minClaimInterval = _isTestnet ? 1 hours : 1 days;
    }
    
    
    // ========== FONCTIONS PRINCIPALES ==========
    
    /**
     * @notice Crée un calendrier de vesting pour un bénéficiaire
     */
    function createVesting(address beneficiary, uint256 amount) external {
        require(msg.sender == deployer, "Only deployer");
        require(!paused, "Contract paused");
        require(beneficiary != address(0), "Invalid beneficiary");
        require(beneficiary != BURN_ADDRESS, "Cannot vest to burn address");
        
        // Utilisation des constants pour validation
        require(amount >= MIN_VESTING_AMOUNT, "Amount too low");
        require(amount <= MAX_VESTING_AMOUNT, "Amount too high");
        require(beneficiaries.length < MAX_BENEFICIARIES, "Max beneficiaries reached");
        require(vestingSchedules[beneficiary].totalAmount == 0, "Vesting exists");
        
        // Calcul des frais avec constant et immutable
        uint256 fee = (amount * protocolFee) / BASIS_POINTS;
        uint256 netAmount = amount - fee;
        
        vestingSchedules[beneficiary] = VestingSchedule({
            totalAmount: netAmount,
            releasedAmount: 0,
            startTime: vestingStartTime, // immutable
            lastClaimTime: 0,
            revoked: false
        });
        
        beneficiaries.push(beneficiary);
        totalVestedAmount += netAmount;
        
        emit VestingCreated(beneficiary, netAmount, vestingStartTime);
        if (fee > 0) {
            emit FeePaid(msg.sender, fee);
        }
    }
    
    /**
     * @notice Calcule le montant disponible pour claim
     */
    function getVestedAmount(address beneficiary) public view returns (uint256) {
        VestingSchedule memory schedule = vestingSchedules[beneficiary];
        
        if (schedule.revoked || schedule.totalAmount == 0) {
            return 0;
        }
        
        // Avant la cliff (utilise immutable)
        if (block.timestamp < cliffEndTime) {
            return 0;
        }
        
        // Release initial après cliff (utilise constant)
        uint256 initialRelease = (schedule.totalAmount * INITIAL_RELEASE_PERCENT) / BASIS_POINTS;
        
        // Après la fin du vesting (utilise immutable)
        if (block.timestamp >= vestingEndTime) {
            return schedule.totalAmount;
        }
        
        // Calcul linéaire entre cliff et fin (utilise constants et immutables)
        uint256 timeFromCliff = block.timestamp - cliffEndTime;
        uint256 vestingDuration = vestingEndTime - cliffEndTime;
        uint256 remainingAmount = schedule.totalAmount - initialRelease;
        
        uint256 vestedAmount = initialRelease + 
            (remainingAmount * timeFromCliff) / vestingDuration;
        
        return vestedAmount;
    }
    
    /**
     * @notice Permet au bénéficiaire de claim ses tokens
     */
    function claimTokens() external {
        require(!paused, "Contract paused");
        
        VestingSchedule storage schedule = vestingSchedules[msg.sender];
        require(schedule.totalAmount > 0, "No vesting schedule");
        require(!schedule.revoked, "Vesting revoked");
        
        // Vérification de l'intervalle minimum (utilise immutable)
        require(
            block.timestamp >= schedule.lastClaimTime + minClaimInterval,
            "Claim too soon"
        );
        
        uint256 vested = getVestedAmount(msg.sender);
        uint256 claimable = vested - schedule.releasedAmount;
        
        require(claimable > 0, "Nothing to claim");
        
        schedule.releasedAmount += claimable;
        schedule.lastClaimTime = block.timestamp;
        
        emit TokensClaimed(msg.sender, claimable);
        
        // Transfer des tokens (utilise immutable)
        // IERC20(token).transfer(msg.sender, claimable);
    }
    
    /**
     * @notice Révoque un vesting (admin uniquement)
     */
    function revokeVesting(address beneficiary) external {
        require(msg.sender == deployer, "Only deployer");
        
        VestingSchedule storage schedule = vestingSchedules[beneficiary];
        require(schedule.totalAmount > 0, "No vesting schedule");
        require(!schedule.revoked, "Already revoked");
        
        uint256 vested = getVestedAmount(beneficiary);
        uint256 unvested = schedule.totalAmount - vested;
        
        schedule.revoked = true;
        
        emit VestingRevoked(beneficiary, unvested);
        
        // Retour des tokens non vestés au treasury (utilise constant)
        if (unvested > 0) {
            // IERC20(token).transfer(TREASURY, unvested);
        }
    }
    
    /**
     * @notice Informations sur le contrat
     */
    function getContractInfo() external view returns (
        address _token,
        address _deployer,
        uint256 _deploymentTime,
        uint256 _chainId,
        bool _isTestnet,
        uint256 _vestingDuration,
        uint256 _cliffDuration
    ) {
        return (
            token,                    // immutable
            deployer,                 // immutable
            deploymentTime,           // immutable
            chainId,                  // immutable
            isTestnet,                // immutable
            VESTING_DURATION_DAYS,    // constant
            CLIFF_DURATION_DAYS       // constant
        );
    }
    
    /**
     * @notice Calcule les frais pour un montant donné
     */
    function calculateFee(uint256 amount) public view returns (uint256) {
        // Combine constant (BASIS_POINTS) et immutable (protocolFee)
        return (amount * protocolFee) / BASIS_POINTS;
    }
    
    /**
     * @notice Vérifie si on est en période de cliff
     */
    function isInCliffPeriod() public view returns (bool) {
        // Utilise immutables
        return block.timestamp >= vestingStartTime && 
               block.timestamp < cliffEndTime;
    }
    
    /**
     * @notice Pause d'urgence (deployer uniquement)
     */
    function togglePause() external {
        require(msg.sender == deployer, "Only deployer");
        paused = !paused;
    }
}