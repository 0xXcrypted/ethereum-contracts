const { ethers } = require('hardhat');

async function main() {
	const [deployer] = await ethers.getSigners();

	console.log('Deploying contracts with the account:', deployer.address);

	console.log('Account balance:', (await deployer.getBalance()).toString());

	// const Greeter = await ethers.getContractFactory('Greeter');
	// const greeter = await Greeter.deploy('hiSnusv');
	// const SSV = await ethers.getContractFactory('SSV');
	// const ssvToken = await SSV.deploy();
	// const SSV = await ethers.getContractFactory('SSV');
	// const ssvToken = await SSV.deploy();
	// const BatchAuction = await ethers.getContractFactory('BatchAuction');
	// const auction = await BatchAuction.deploy();
	// console.log('Auction address:', auction.address);
	// const DecipherToken = await ethers.getContractFactory('DecipherToken');
	// const decipherToken = await DecipherToken.deploy();
	// console.log('DecipherToken address:', decipherToken.address);
	const SaleToken = await ethers.getContractFactory('SaleToken');
	const saleToken = await SaleToken.deploy();
	console.log('SaleToken address:', saleToken.address);
	// Uniswap
	// const TestToken1 = await ethers.getContractFactory('TestToken1');
	// const testToken1 = await TestToken1.deploy();
	// console.log('testToken1 address:', testToken1.address);
	// const TestToken2 = await ethers.getContractFactory('TestToken2');
	// const testToken2 = await TestToken2.deploy();
	// console.log('testToken2 address:', testToken2.address);
	// const TestToken3 = await ethers.getContractFactory('TestToken3');
	// const testToken3 = await TestToken3.deploy();
	// console.log('testToken3 address:', testToken3.address);
	// const UniswapV2ERC20 = await ethers.getContractFactory('UniswapV2ERC20');
	// const uniswapv2erc20 = await UniswapV2ERC20.deploy();
	// console.log('uniswapv2erc20 address:', uniswapv2erc20.address);
	// 0x83202BE19683DC8d826C51fa2AA8c7CfDFC76ee3
	// const UniswapV2Factory = await ethers.getContractFactory('UniswapV2Factory');
	// const uniswapv2factory = await UniswapV2Factory.deploy('0x5b1AB6A09297C57911D1971537F569143a601B93');
	// console.log('uniswapv2factory address:', uniswapv2factory.address);
	// 0x63bCAB6166CcB183F2D63F02e8F2Eb4Fc1446257
	// const WETH = await ethers.getContractFactory('WETH');
	// const weth = await WETH.deploy();
	// console.log('weth address:', weth.address);
	// const UniswapV2Router02 = await ethers.getContractFactory('UniswapV2Router02');
	// const uniswapv2router02 = await UniswapV2Router02.deploy(
	// 	'0x14711C30Cf55B6075e739f3135f52dE531836a83',
	// 	'0x5e2947D88EE13bc063B68d6317f454331117fD10'
	// );
	// console.log('uniswapv2router02 address:', uniswapv2router02.address);
	// const ERC721 = await ethers.getContractFactory('ERC721');
	// const erc721 = await ERC721.deploy('SNUSV ERC721', 'ssv721');
	// console.log('erc721 address:', erc721.address);
	// const ERC1155 = await ethers.getContractFactory('ERC1155');
	// const erc1155 = await ERC1155.deploy('ssv1155');
	// console.log('erc1155 address:', erc1155.address);
	// const NFT = await ethers.getContractFactory('NFT');
	// const nft = await NFT.deploy();
	// console.log('nft address:', nft.address);
	// 0xB0B29aa44C0D9b1Dbc654196fAB407b51Dd0a3D4
	// const UniswapFactory = await ethers.getContractFactory('UniswapFactory');
	// const nuniswapfactory = await UniswapFactory.deploy();
	// console.log('nuniswapfactory address:', nuniswapfactory.address);
	// const WillController = await ethers.getContractFactory('WillController');
	// const willController = await WillController.deploy();
	// console.log('willController address:', willController.address);
}

main()
	.then(() => process.exit(0))
	.catch((error) => {
		console.error(error);
		process.exit(1);
	});
