// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "./DappToken.sol";
import "./LPToken.sol";
import "./TokenFarm.sol";

contract TokenFarmUnstakeClaimRewards is Test{
    DappToken public dappToken;
    LPToken public lpToken;
    TokenFarm public tokenFarm;
    
    address public owner;
    address public user1;

    uint256 constant MINT_AMOUNT = 100e18; // 100 tokens
    uint256 constant DEPOSIT_AMOUNT = 50e18; // 50 tokens
    
    function setUp() public {
        owner = address(this);
        user1 = address(0x1);
        
        vm.deal(user1, 1 ether);
        
        dappToken = new DappToken(owner);
        lpToken = new LPToken(owner);
        tokenFarm = new TokenFarm(dappToken, lpToken);
        
        dappToken.transferOwnership(address(tokenFarm));
    }

    function testUnstakeAndClaimRewardsSuccessfully() public {
        lpToken.mint(user1, MINT_AMOUNT);
        
        assertEq(lpToken.balanceOf(user1), MINT_AMOUNT);
        
        vm.startPrank(user1);
        lpToken.approve(address(tokenFarm), DEPOSIT_AMOUNT);
        tokenFarm.deposit(DEPOSIT_AMOUNT);
        vm.stopPrank();
        
        uint256 initialBlock = block.number;
        uint256 blocksToAdvance = 10;
        vm.roll(initialBlock + blocksToAdvance);
        
        tokenFarm.distributeRewardsAll();

        vm.startPrank(user1);
        lpToken.approve(address(tokenFarm), 30e18);
        tokenFarm.deposit(30e18);
        vm.stopPrank();

        uint256 blocksToAdvance2 = 5;
        vm.roll(block.number + blocksToAdvance2);

        vm.startPrank(user1);
        tokenFarm.withdraw();

        assertEq(lpToken.balanceOf(user1), MINT_AMOUNT, "El balance de LPToken de user1 es incorrecto despues de unstake.");

        uint256 expectedRewards = (tokenFarm.REWARD_PER_BLOCK() * (blocksToAdvance + blocksToAdvance2) * DEPOSIT_AMOUNT) / DEPOSIT_AMOUNT;
        assertEq(dappToken.balanceOf(user1), expectedRewards, "El balance de DappToken de user1 es incorrecto despues de claim rewards.");
    }
}