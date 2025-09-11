// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import './DappToken.sol';
import './LPToken.sol';

contract TokenFarmV2{

    string public name = "Proportional Token Farm";
    address public owner;

    DappToken public dappToken;
    LPToken public lpToken;

    uint256 public REWARD_PER_BLOCK = 1e18;
    uint256 constant FEE_PERCENTAGE = 1;
    uint256 public totalStakingBalance;
    uint256 public totalFees;
    address[] public stakers;

    struct UserInfo {
        uint256 stakingBalance;
        uint256 checkpoints;
        uint256 pendingRewards;
        bool hasStaked;
        bool isStaking;
    }

    mapping(address => UserInfo) public userInfo;

    event Deposit(address sender, uint256 amount, uint256 checkpoint);
    event Withdraw(address sender, uint256 amount, uint256 time);
    event ClaimReward(address sender,uint256 amount, uint256 time);
    event RewardDistributed(address sender,uint256 time);

    modifier onlyOwner {
        require(msg.sender == owner,"Solo el owner puede llamar a esta funcion.");
        _;
    }

    modifier userIsStaking(){
        require(userInfo[msg.sender].isStaking == true,"USted no esta realizando staking.");
        _;
    }

    constructor(DappToken _dappToken, LPToken _lpToken) {
        dappToken = _dappToken;
        lpToken = _lpToken;
        owner = msg.sender;
    }

    function deposit(uint256 _amount)external{
        require(_amount  > 0 , "El monto debe ser mayor a 0.");
        
        lpToken.transferFrom(msg.sender,address(this),_amount);
        userInfo[msg.sender].stakingBalance += _amount;
        totalStakingBalance += _amount;

        if(!userInfo[msg.sender].hasStaked){
            userInfo[msg.sender].hasStaked = true;
            stakers.push(msg.sender);
        }

        userInfo[msg.sender].isStaking = true;

        if(userInfo[msg.sender].checkpoints == 0){
            userInfo[msg.sender].checkpoints = block.number;
        }

        _distributeReward(msg.sender);

        emit Deposit(msg.sender,_amount,block.number);

    }

    function withdraw()external userIsStaking{
    
        uint256 _amountStaked = userInfo[msg.sender].stakingBalance;
        require (_amountStaked > 0,"No tiene saldo en staking.");
        
        _distributeReward(msg.sender);

        userInfo[msg.sender].stakingBalance = 0;
        totalStakingBalance -= _amountStaked;
        userInfo[msg.sender].isStaking = false;
        lpToken.transfer(msg.sender, _amountStaked);
        
        uint256 pendingAmount = userInfo[msg.sender].pendingRewards;
        
        require(pendingAmount > 0, "No hay saldo para retirar.");

        userInfo[msg.sender].pendingRewards = 0;
        dappToken.mint(msg.sender, pendingAmount);

        emit Withdraw(msg.sender,_amountStaked,block.timestamp);
    }

    function  claimReward() external {
        uint256 pendingAmount = userInfo[msg.sender].pendingRewards;
        uint256 pendingAmountLessFee = pendingAmount - (pendingAmount * FEE_PERCENTAGE / 100);

        totalFees += pendingAmount - pendingAmountLessFee ;
        require(pendingAmount > 0, "No hay saldo para retirar.");

        userInfo[msg.sender].pendingRewards = 0;
        dappToken.mint(msg.sender, pendingAmountLessFee);

        emit ClaimReward(msg.sender,pendingAmountLessFee,block.timestamp);
    }

    function distributeRewardsAll() external onlyOwner{
        for(uint256 i = 0; i < stakers.length; i++){
            if(userInfo[stakers[i]].isStaking){
                _distributeReward(stakers[i]);

                emit RewardDistributed(stakers[i],block.timestamp);
            }
        }
    }

    function _distributeReward(address _sender) private{
        uint256 checkpoint = userInfo[_sender].checkpoints;
        uint256 bloquesPasados = block.number - checkpoint;

        uint256 userStake = userInfo[_sender].stakingBalance;
        uint256 reward = (REWARD_PER_BLOCK * bloquesPasados * userStake) / totalStakingBalance;
            
        userInfo[_sender].pendingRewards += reward;
        userInfo[_sender].checkpoints = block.number;
    }

    function getStakersCount() external view returns (uint256) {
        return stakers.length;
    }

    // Solo el owner del TokenFarm puede llamar esta función
    function transferDappTokenOwnership(address newOwner) external onlyOwner {
        dappToken.transferOwnership(newOwner);
    }

    function changeRewardPerBlock(uint256 newReward) external onlyOwner {
        require(newReward > 0.1e18 , "El nuevo valor debe ser mayor a 0.1 tokens .");
        REWARD_PER_BLOCK = newReward;
    }

    function claimFees() external onlyOwner{
        require(totalFees > 0, "No hay fees para reclamar.");
        uint256 feesToClaim = totalFees;
        totalFees = 0;
        dappToken.mint(owner, feesToClaim);
    }
}