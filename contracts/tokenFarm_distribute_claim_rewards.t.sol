// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "./DappToken.sol";
import "./LPToken.sol";
import "./TokenFarm.sol";

contract TokenFarmTestDistributeReward is Test {
    DappToken public dappToken;
    LPToken public lpToken;
    TokenFarm public tokenFarm;
    
    address public owner;
    address public user1;
    address public user2;
    address public user3;
    
    uint256 constant MINT_AMOUNT = 100e18; // 100 tokens
    uint256 constant DEPOSIT_AMOUNT = 50e18; // 50 tokens
    
    function setUp() public {
        owner = address(this);
        user1 = address(0x1);
        user2 = address(0x2);
        user3 = address(0x3); 
        
        vm.deal(user1, 1 ether);
        vm.deal(user2, 1 ether);
        vm.deal(user3, 1 ether);
        
        dappToken = new DappToken(owner);
        lpToken = new LPToken(owner);
        tokenFarm = new TokenFarm(dappToken, lpToken);
        
        dappToken.transferOwnership(address(tokenFarm));
    }
    
    function testDistribuirRecompensasExitosamente() public {
        lpToken.mint(user1, MINT_AMOUNT);
        lpToken.mint(user2, MINT_AMOUNT);
        lpToken.mint(user3, MINT_AMOUNT);
        
        assertEq(lpToken.balanceOf(user1), MINT_AMOUNT);
        assertEq(lpToken.balanceOf(user2), MINT_AMOUNT);
        assertEq(lpToken.balanceOf(user3), MINT_AMOUNT);
        
        vm.startPrank(user1);
        lpToken.approve(address(tokenFarm), DEPOSIT_AMOUNT);
        tokenFarm.deposit(DEPOSIT_AMOUNT);
        vm.stopPrank();
        
        vm.startPrank(user2);
        lpToken.approve(address(tokenFarm), DEPOSIT_AMOUNT);
        tokenFarm.deposit(DEPOSIT_AMOUNT);
        vm.stopPrank();
        
        vm.startPrank(user3);
        lpToken.approve(address(tokenFarm), DEPOSIT_AMOUNT);
        tokenFarm.deposit(DEPOSIT_AMOUNT);
        vm.stopPrank();
        
        uint256 initialBlock = block.number;
        uint256 blocksToAdvance = 10;
        
        console.log("Block inicial:", initialBlock);
        console.log("Total staking balance:", tokenFarm.totalStakingBalance());
        
        vm.roll(initialBlock + blocksToAdvance);
        
        tokenFarm.distributeRewardsAll();
        
        uint256 user1Rewards = tokenFarm.pendingRewards(user1);
        uint256 user2Rewards = tokenFarm.pendingRewards(user2);
        uint256 user3Rewards = tokenFarm.pendingRewards(user3);
        
        assertTrue(user1Rewards > 0, "User1 deberia tener recompensas");
        assertTrue(user2Rewards > 0, "User2 deberia tener recompensas");
        assertTrue(user3Rewards > 0, "User3 deberia tener recompensas");
        
        assertApproxEqAbs(user1Rewards, user2Rewards, 1e15, "User1 y User2 deberian tener recompensas similares");
        assertApproxEqAbs(user2Rewards, user3Rewards, 1e15, "User2 y User3 deberian tener recompensas similares");
    }
    
    function testClaimReward() public {
        lpToken.mint(user1, MINT_AMOUNT);
        
        vm.startPrank(user1);
        lpToken.approve(address(tokenFarm), DEPOSIT_AMOUNT);
        tokenFarm.deposit(DEPOSIT_AMOUNT);
        vm.stopPrank();
        
        vm.roll(block.number + 10);
        
        tokenFarm.distributeRewardsAll();
        
        uint256 pendingRewards = tokenFarm.pendingRewards(user1);
        assertTrue(pendingRewards > 0, "Usuario deberia tener recompensas pendientes");
        
        uint256 initialDappBalance = dappToken.balanceOf(user1);
        
        console.log("Balance inicial del farm", initialDappBalance);
        vm.prank(user1);
        tokenFarm.claimReward();
        
        // Verificar que las recompensas se mintearon y transfirieron
        assertEq(tokenFarm.pendingRewards(user1), 0, "Pending rewards deberia ser 0");
        assertEq(
            dappToken.balanceOf(user1), 
            initialDappBalance + pendingRewards, 
            "Usuario deberia recibir DAPP tokens"
        );
    }
    
    function testSoloOwnerPuedeDistribuirRecompensas() public {
        
        lpToken.mint(user1, MINT_AMOUNT);
        
        vm.startPrank(user1);

        lpToken.approve(address(tokenFarm), DEPOSIT_AMOUNT);
        tokenFarm.deposit(DEPOSIT_AMOUNT);
        
        vm.expectRevert("Solo el owner puede llamar a esta funcion.");
        tokenFarm.distributeRewardsAll();

        vm.stopPrank();
        
        // Owner puede llamar la función
        tokenFarm.distributeRewardsAll();
    }
    
    function testCalculoDeRecompensasProporcionalmente() public {
        // User1 deposita 30 tokens
        lpToken.mint(user1, MINT_AMOUNT);
        vm.startPrank(user1);
        lpToken.approve(address(tokenFarm), 30e18);
        tokenFarm.deposit(30e18);
        vm.stopPrank();
        
        // User2 deposita 70 tokens (más del doble que user1)
        lpToken.mint(user2, MINT_AMOUNT);
        vm.startPrank(user2);
        lpToken.approve(address(tokenFarm), 70e18);
        tokenFarm.deposit(70e18);
        vm.stopPrank();
        
        // Avanzar bloques
        vm.roll(block.number + 10);

        tokenFarm.distributeRewardsAll();
        
        uint256 user1Rewards = tokenFarm.pendingRewards(user1);
        uint256 user2Rewards = tokenFarm.pendingRewards(user2);
        
        console.log("User1 rewards (30 tokens staked):", user1Rewards);
        console.log("User2 rewards (70 tokens staked):", user2Rewards);
        
        // User2 debería tener aproximadamente 2.33x más recompensas que user1 (70/30)
        assertTrue(user2Rewards > user1Rewards, "User2 deberia tener mas recompensas");
        
        // Verificar proporción aproximada: user2Rewards / user1Rewards ≈ 70/30 = 2.33
        uint256 ratio = (user2Rewards * 100) / user1Rewards; 
        assertApproxEqAbs(ratio, 233, 10, "La proporcion deberia ser aproximadamente 2.33");
    }
}