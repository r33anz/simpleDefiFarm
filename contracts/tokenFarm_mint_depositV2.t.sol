// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "./DappToken.sol";
import "./LPToken.sol";
import "./TokenFarmV2.sol";

contract TokenFarmTestMintDepositV2 is Test {
    DappToken public dappToken;
    LPToken public lpToken;
    TokenFarmV2 public tokenFarm;
    
    address public owner;
    address public user1;
    address public user2;
    
    uint256 constant MINT_AMOUNT = 100e18; // 100 tokens
    uint256 constant DEPOSIT_AMOUNT = 50e18; // 50 tokens
    
    function setUp() public {
        owner = address(this);
        user1 = address(0x1);
        user2 = address(0x2);
        
        vm.deal(user1, 1 ether);
        vm.deal(user2, 1 ether);
        
        dappToken = new DappToken(owner);
        lpToken = new LPToken(owner);
        tokenFarm = new TokenFarmV2(dappToken, lpToken);
        
        console.log("Contratos desplegados correctamente");
    }
    
    function testMintearLPTokensYHacerDepositExitosamente() public {
        lpToken.mint(user1, MINT_AMOUNT);
        assertEq(lpToken.balanceOf(user1), MINT_AMOUNT);
        
        vm.startPrank(user1);
        lpToken.approve(address(tokenFarm), DEPOSIT_AMOUNT);
        
        //monto que se dio permiso
        assertEq(
            lpToken.allowance(user1, address(tokenFarm)), 
            DEPOSIT_AMOUNT
        );
        tokenFarm.deposit(DEPOSIT_AMOUNT);
        vm.stopPrank();
        
        // Obtener info del usuario usando el struct
        (uint256 stakingBalance, uint256 checkpoints, uint256 pendingRewards, bool hasStaked, bool isStaking) = tokenFarm.userInfo(user1);
        
        assertEq(stakingBalance, DEPOSIT_AMOUNT);
        assertEq(tokenFarm.totalStakingBalance(), DEPOSIT_AMOUNT);
        assertTrue(isStaking);
        assertTrue(hasStaked);
        
        // Balance de LP tokens del usuario se redujo
        assertEq(
            lpToken.balanceOf(user1), 
            MINT_AMOUNT - DEPOSIT_AMOUNT
        );

        assertEq(lpToken.balanceOf(address(tokenFarm)), DEPOSIT_AMOUNT);
        assertTrue(checkpoints > 0);
    }
    
    function testDeberiaFallarConMontoCero() public {
        vm.startPrank(user1);
        vm.expectRevert("El monto debe ser mayor a 0.");
        tokenFarm.deposit(0);
        vm.stopPrank();
    }
    
    function testDeberiaFallarSinAllowanceSuficiente() public {
        lpToken.mint(user1, MINT_AMOUNT);
        
        vm.startPrank(user1);
        // Debería fallar porque no hay allowance
        vm.expectRevert();
        tokenFarm.deposit(DEPOSIT_AMOUNT);
        vm.stopPrank();
    }
    
    
    function testMultiplesUsuariosPuedenHacerStaking() public {
        // Mintear tokens para ambos usuarios
        lpToken.mint(user1, MINT_AMOUNT);
        lpToken.mint(user2, MINT_AMOUNT);
        
        // User1 hace deposit
        vm.startPrank(user1);
        lpToken.approve(address(tokenFarm), DEPOSIT_AMOUNT);
        tokenFarm.deposit(DEPOSIT_AMOUNT);
        vm.stopPrank();
        
        // User2 hace deposit
        vm.startPrank(user2);
        lpToken.approve(address(tokenFarm), DEPOSIT_AMOUNT);
        tokenFarm.deposit(DEPOSIT_AMOUNT);
        vm.stopPrank();
        
        // Verificaciones usando struct
        (uint256 stakingBalance1, , , , bool isStaking1) = tokenFarm.userInfo(user1);
        (uint256 stakingBalance2, , , , bool isStaking2) = tokenFarm.userInfo(user2);
        
        assertEq(stakingBalance1, DEPOSIT_AMOUNT);
        assertEq(stakingBalance2, DEPOSIT_AMOUNT);
        assertEq(tokenFarm.totalStakingBalance(), DEPOSIT_AMOUNT * 2);
        
        assertTrue(isStaking1);
        assertTrue(isStaking2);
        
        // Verificar que ambos están en la lista de stakers
        assertEq(tokenFarm.getStakersCount(), 2);
    }
    
    function testUsuarioPuedeHacerDepositosMultiples() public {
        
        lpToken.mint(user1, MINT_AMOUNT);
        
        vm.startPrank(user1);
        
        // Primer deposit
        lpToken.approve(address(tokenFarm), MINT_AMOUNT);
        tokenFarm.deposit(30e18);
        
        // Segundo deposit
        tokenFarm.deposit(20e18);
        
        vm.stopPrank();
        
        // Verificar que se acumuló correctamente usando struct
        (uint256 stakingBalance, , , , ) = tokenFarm.userInfo(user1);
        assertEq(stakingBalance, 50e18);
        assertEq(tokenFarm.totalStakingBalance(), 50e18);
        
        // Solo debe estar una vez en la lista de stakers
        assertEq(tokenFarm.getStakersCount(), 1);
        
        console.log("Usuario puede hacer mltiples deposits");
    }
    
}