require('dotenv').config();
const hardhat = require('hardhat');
const ethers = hardhat.ethers;
const abi = require('../artifacts/contracts/SSV.sol/SSV.json');
let provider = new ethers.providers.EtherscanProvider('kovan');

let privateKey = process.env.PRIVATE_KEY;

let wallet = new ethers.Wallet(privateKey, provider);

async function main() {
	// const [deployer] = await ethers.getSigners();
	const ssvContract = new ethers.Contract('0x564D4867952E811e3B7Fda895496709A3c39C17d', abi.abi, provider);

	// await ssvContract.name().then(console.log);

	const ssvContractWithSigner = ssvContract.connect(wallet);
	await ssvContractWithSigner.name('asdfas').then(console.log);

	// await greeterContractWithSigner.setGreeting('hi').then(console.log);
	// await greeterContract.greet().then(console.log);
}

main();
