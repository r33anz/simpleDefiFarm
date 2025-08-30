// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import './DappToken.sol';
import './LPToken.sol';

contract TokenFarm{

    string public name = "Proportional Token Farm";
    address public owner;

    DappToken public dappToken;
    LPToken public lpToken;

    uint256 public constant REWARD_PER_BLOCK = 1e18;
    uint256 public totalStakingBalance;
    address[] public stakers;

    mapping (address => uint256) public stakingBalance;
    mapping (address => uint256) public checkpoints;
    mapping (address => uint256) public pendingRewards;
    mapping (address => bool) public hasStaked;
    mapping (address => bool) public isStaking; 

    event Deposit(address sender, uint256 amount, uint256 checkpoint);
    event Withdraw(address sender, uint256 amount, uint256 time);
    event ClaimReward(address sender,uint256 amount, uint256 time);
    event RewardDistributed(address sender,uint256 time);

    modifier onlyOwner {
        require(msg.sender == owner,"Solo el owner puede llamar a esta funcion.");
        _;
    }

    constructor(DappToken _dappToken, LPToken _lpToken,address _owner) {
        dappToken = _dappToken;
        lpToken = _lpToken;
        owner = _owner;
    }

    function deposit(uint256 _amount)external{
        require(_amount  > 0 , "El monto debe ser mayor a 0.");
        
        lpToken.transferFrom(msg.sender,address(this),_amount);
        stakingBalance[msg.sender] += _amount;
        totalStakingBalance += _amount;

        if(!hasStaked[msg.sender]){
            hasStaked[msg.sender] = true;
        }

        isStaking[msg.sender] = true;

        if(checkpoints[msg.sender] == 0){
            checkpoints[msg.sender] = block.number;
        }

        _distributeReward(msg.sender);

        emit Deposit(msg.sender,_amount,block.number);

    }

    function withdraw()external{
        require(isStaking[msg.sender] == true,"No esta realizando staking.");

        uint256 _amountStaked = stakingBalance[msg.sender];
        require (_amountStaked > 0,"No tiene saldo en staking.");
        
        _distributeReward(msg.sender);

        stakingBalance[msg.sender] = 0;
        totalStakingBalance -= _amountStaked;
        isStaking[msg.sender] = false;
        lpToken.transfer(msg.sender, _amountStaked);

        emit Withdraw(msg.sender,_amountStaked,block.timestamp);
    }

    function  claimReward() external {
        uint256 pendingAmount = pendingRewards[msg.sender];
        
        require(pendingAmount > 0, "No hay saldo para retirar.");

        pendingRewards[msg.sender] = 0;
        dappToken.mint(msg.sender, pendingAmount);

        emit ClaimReward(msg.sender,pendingAmount,block.timestamp);
    }

    function distributeRewardsAll() external onlyOwner{
        for(uint256 i = 0; i < stakers.length; i++){
            if(isStaking[stakers[i]]){
                _distributeReward(stakers[i]);

                emit RewardDistributed(stakers[i],block.timestamp);
            }
        }
    }

    function _distributeReward(address _sender) private{
        uint256 checkpoint = checkpoints[_sender];
        uint256 bloquesPasados = block.number - checkpoint;

        uint256 percentage = stakingBalance[_sender] / totalStakingBalance; 
        uint256 reward = REWARD_PER_BLOCK * bloquesPasados * percentage;

        pendingRewards[_sender] = reward;
        checkpoints[_sender] = block.number;
    }

}