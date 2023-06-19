const { network, ethers } = require("hardhat");
const {
  developmentChains,
  networkConfig,
} = require("../helper-hardhat-config");
const verify = require("../utils/verify");

const VRF_SUB_FUND = ethers.utils.parseEther("1");
module.exports = async function ({ getNamedAccounts, deployments }) {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();
  const chainId = network.config.chainId;
  let vrfCoordinatorV2Address, subscriptionId;

  if (chainId == 31337) {
    const vrfCordinatorV2Mock = await ethers.getContract(
      "VRFCoordinatorV2Mock"
    );
    vrfCoordinatorV2Address = vrfCordinatorV2Mock.address;
    const transactionResponse = await vrfCordinatorV2Mock.createSubscription();
    const transactionReceipt = await transactionResponse.wait(1);
    subscriptionId = transactionReceipt.events[0].args.subId;
    await vrfCordinatorV2Mock.fundSubscription(subscriptionId, VRF_SUB_FUND);
  } else {
    vrfCoordinatorV2Address = networkConfig[chainId]["vrfCoordinatorV2"];
    subscriptionId = networkConfig[chainId]["subscriptionId"];
  }

  const entranceFee = networkConfig[chainId]["raffleEntranceFee"];
  const gasLane = networkConfig[chainId]["gasLane"];
  const callbackGasLimit = networkConfig[chainId]["callbackGasLimit"];
  const interval = networkConfig[chainId]["keepersUpdateInterval"];

  const args = [
    vrfCoordinatorV2Address,
    entranceFee,
    gasLane,
    subscriptionId,
    callbackGasLimit,
    interval,
  ];
  const raffle = await deploy("Raffle", {
    from: deployer,
    args: args,
    log: true,
    waitConfirmations: network.config.waitConfirmations || 1,
  });

  // Ensure the Raffle contract is a valid consumer of the VRFCoordinatorV2Mock contract.
  if (developmentChains.includes(network.name)) {
    const vrfCoordinatorV2Mock = await ethers.getContract(
      "VRFCoordinatorV2Mock"
    );
    await vrfCoordinatorV2Mock.addConsumer(subscriptionId, raffle.address);
  }
  if (
    !developmentChains.includes(network.name) &&
    process.env.ETHERSCAN_API_KEY
  ) {
    log("Verifying Contract...");
    await verify(raffle.address, args);
  }

  log("-------------------");
};

module.exports.tags = ["all", "raffle"];
