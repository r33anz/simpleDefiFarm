import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";


export default buildModule("SimpleDeFiModule", (m) => {
    const deployer = m.getAccount(0);        

    const tokenLP = m.contract("LPToken", [deployer]);   
    const tokenDapp = m.contract("DappToken", [deployer]); 
    const farm  = m.contract("TokenFarm", [tokenDapp,tokenLP]); 

    m.call(tokenDapp, "transferOwnership", [farm]);
    
    return { 
            tokenLP,
            tokenDapp, 
            farm 
        };
});
