import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const TokenFarmUUPSModule = buildModule("TokenFarmUUPSModule", (m) => {
  const deployer = m.getAccount(0);

  // 1️⃣ Deploy DappToken and LPToken with correct constructor parameters
  // Your contracts expect only 1 parameter: initialOwner (address)
  const dappToken = m.contract("DappToken", [deployer], { id: "DappToken" });
  const lpToken = m.contract("LPToken", [deployer], { id: "LPToken" });

  // 2️⃣ Deploy TokenFarmProxyV1 without constructor arguments (UUPS)
  const tokenFarm = m.contract("TokenFarmProxyV1", [], { id: "TokenFarmProxyV1" });

  // 3️⃣ Initialize TokenFarmProxyV1
  m.call(
    tokenFarm,
    "initialize",
    [dappToken, lpToken, deployer],
    { from: deployer }
  );

  // 4️⃣ Make TokenFarm the owner of DappToken
  m.call(dappToken, "transferOwnership", [tokenFarm], { from: deployer });

  return { tokenFarm, dappToken, lpToken };
});

export default TokenFarmUUPSModule;