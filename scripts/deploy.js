import ethers from "ethers";
import { wallet, deployContract } from "./helpers.js";

import DrainArtifact from "../out/Drain.sol/Drain.json" assert { type: "json" };

const deploy = async () => {
  const Factory = new ethers.ContractFactory(
    DrainArtifact.abi,
    DrainArtifact.bytecode.object,
    wallet
  );

  return await deployContract({
    name: "Drain",
    deployer: wallet,
    factory: Factory,
    args: [],
    opts: {
      gasLimit: 1000000,
    },
  });
};

const main = async () => {
  await deploy();
};

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
