// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import './DappToken.sol';
import './LPToken.sol';
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract TokenFarmProxyV1 is Initializable, OwnableUpgradeable, ReentrancyGuardUpgradeable, UUPSUpgradeable {
    
    string public name;
    
    DappToken public dappToken;
    LPToken public lpToken;

    uint256 public REWARD_PER_BLOCK;
    uint256 public constant FEE_PERCENTAGE = 1;
    uint256 public totalStakingBalance;
    uint256 public totalFees;
    address[] public stakers;

    mapping (address => uint256) public stakingBalance;
    mapping (address => uint256) public checkpoints;
    mapping (address => uint256) public pendingRewards;
    mapping (address => bool) public hasStaked;
    mapping (address => bool) public isStaking; 

    event Deposit(address sender, uint256 amount, uint256 checkpoint);
    event Withdraw(address sender, uint256 amount, uint256 time);
    event ClaimReward(address sender, uint256 amount, uint256 time);
    event RewardDistributed(address sender, uint256 time);

    modifier userIsStaking(){
        require(isStaking[msg.sender] == true, "Usted no esta realizando staking.");
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _dappToken, 
        address _lpToken,
        address _owner
    ) public initializer {
        __Ownable_init(_owner);
        __ReentrancyGuard_init();
        
        name = "Proportional Token Farm";
        dappToken = DappToken(_dappToken);
        lpToken = LPToken(_lpToken);
        REWARD_PER_BLOCK = 1e18;
        totalStakingBalance = 0;
        totalFees = 0;
    }

    function deposit(uint256 _amount) external nonReentrant {
        require(_amount > 0, "El monto debe ser mayor a 0.");
        
        lpToken.transferFrom(msg.sender, address(this), _amount);
        stakingBalance[msg.sender] += _amount;
        totalStakingBalance += _amount;

        if(!hasStaked[msg.sender]){
            hasStaked[msg.sender] = true;
            stakers.push(msg.sender);
        }

        isStaking[msg.sender] = true;

        if(checkpoints[msg.sender] == 0){
            checkpoints[msg.sender] = block.number;
        }

        _distributeReward(msg.sender);

        emit Deposit(msg.sender, _amount, block.number);
    }

    function withdraw() external userIsStaking nonReentrant {
        uint256 _amountStaked = stakingBalance[msg.sender];
        require(_amountStaked > 0, "No tiene saldo en staking.");
        
        _distributeReward(msg.sender);

        stakingBalance[msg.sender] = 0;
        totalStakingBalance -= _amountStaked;
        isStaking[msg.sender] = false;
        lpToken.transfer(msg.sender, _amountStaked);
        
        uint256 pendingAmount = pendingRewards[msg.sender];
        
        require(pendingAmount > 0, "No hay saldo para retirar.");

        pendingRewards[msg.sender] = 0;
        dappToken.mint(msg.sender, pendingAmount);

        emit Withdraw(msg.sender, _amountStaked, block.timestamp);
    }

    function claimReward() external nonReentrant {
        uint256 pendingAmount = pendingRewards[msg.sender];
        uint256 pendingAmountLessFee = pendingAmount - (pendingAmount * FEE_PERCENTAGE / 100);

        totalFees += pendingAmount - pendingAmountLessFee;
        require(pendingAmount > 0, "No hay saldo para retirar.");

        pendingRewards[msg.sender] = 0;
        dappToken.mint(msg.sender, pendingAmountLessFee);

        emit ClaimReward(msg.sender, pendingAmountLessFee, block.timestamp);
    }

    function distributeRewardsAll() external onlyOwner {
        for(uint256 i = 0; i < stakers.length; i++){
            if(isStaking[stakers[i]]){
                _distributeReward(stakers[i]);
                emit RewardDistributed(stakers[i], block.timestamp);
            }
        }
    }

    function _distributeReward(address _sender) private {
        uint256 checkpoint = checkpoints[_sender];
        uint256 bloquesPasados = block.number - checkpoint;

        uint256 userStake = stakingBalance[_sender];
        uint256 reward = (REWARD_PER_BLOCK * bloquesPasados * userStake) / totalStakingBalance;
            
        pendingRewards[_sender] += reward;
        checkpoints[_sender] = block.number;
    }

    function getStakersCount() external view returns (uint256) {
        return stakers.length;
    }

    function transferDappTokenOwnership(address newOwner) external onlyOwner {
        dappToken.transferOwnership(newOwner);
    }

    function changeRewardPerBlock(uint256 newReward) external onlyOwner {
        require(newReward > 0.1e18, "El nuevo valor debe ser mayor a 0.1 tokens.");
        REWARD_PER_BLOCK = newReward;
    }

    function claimFees() external onlyOwner nonReentrant {
        require(totalFees > 0, "No hay fees para reclamar.");
        uint256 feesToClaim = totalFees;
        totalFees = 0;
        dappToken.mint(owner(), feesToClaim);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}