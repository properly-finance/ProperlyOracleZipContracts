const LandPriceOracle = artifacts.require("LandPriceOracle");
module.exports = async function(deployer, network, accounts) {
  await deployer.deploy(LandPriceOracle);
  const landPriceOracle = await LandPriceOracle.deployed();
  landPriceOracle.setOracleWhitelist(deployer, { from: deployer });
};
