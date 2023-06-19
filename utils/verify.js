const { run } = require("hardhat");

const verify = async (contractAddress, args) => {
  console.log("Verifying contract..");
  try {
    await run("verify:verify", {
      address: contractAddress,
      constructorArgumenst: args,
    });
  } catch (error) {
    if (error.message.toLowerCase().includes("Already Verified")) {
      console.log("Already Verified");
    } else {
      console.log(error);
    }
  }
};

module.exports = { verify };
