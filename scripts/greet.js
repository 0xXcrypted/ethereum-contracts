require('dotenv').config();
const hardhat = require('hardhat');
const ethers = hardhat.ethers;
const abi = require('../artifacts/contracts/Greeter.sol/Greeter.json');
let provider = new ethers.providers.EtherscanProvider('kovan');

let privateKey = process.env.PRIVATE_KEY;
let wallet = new ethers.Wallet(privateKey, provider);

async function main() {
	// const [deployer] = await ethers.getSigners();
	const greeterContract = new ethers.Contract('0xd661d40bD8CEc393eBcD1FdD70E3B2C9488cD9cc', abi.abi, provider);
	const greeterContractWithSigner = greeterContract.connect(wallet);

	// await greeterContractWithSigner.setGreeting('hi').then(console.log);
	await greeterContract.greet().then(console.log);
}

main();
