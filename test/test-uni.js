const { expect } = require('chai');
const { ethers } = require('hardhat');
// require("@nomiclabs/hardhat-waffle");
describe('balanceCheck', function () {
	it('should return the balance of the account', async function () {
		const [deployer] = await ethers.getSigners();
		const balance = await deployer.getBalance();
		console.log('balance:', balance.toString());
		expect(balance.toString()).to.equal('10000000000000000000000');
	});
});
describe('UniswapFactory', function () {
	it('Factory deploy', async function () {
		const [deployer] = await ethers.getSigners();
		const UniswapFactory = await ethers.getContractFactory('UniswapFactory');
		const factory = await UniswapFactory.deploy();
		await factory.deployed();

		await factory.initializeFactory(deployer.address);
		console.log('factory address:', factory.address);
	});
});

describe('TestTokens', function () {
	it('Test Tokens deploy and mint', async function () {
		const [deployer] = await ethers.getSigners();
		const TestToken1 = await ethers.getContractFactory('TestToken1');
		const TestToken2 = await ethers.getContractFactory('TestToken2');

		const token1 = await TestToken1.deploy();
		await token1.deployed();

		console.log('User Token1 balance:', (await token1.balanceOf(deployer.address)).toString());

		const token2 = await TestToken2.deploy();
		await token2.deployed();

		console.log('User Token2 balance:', (await token2.balanceOf(deployer.address)).toString());
	});
});

describe('UniV1', function () {
	it('New Exchange made with ETH-Token1, ETH-Token2 from Factory.', async function () {
		const [deployer] = await ethers.getSigners();

		console.log('Deploying contracts with the account:', deployer.address);

		console.log('Account balance:', (await deployer.getBalance()).toString());

		const UniswapFactory = await ethers.getContractFactory('UniswapFactory');
		const factory = await UniswapFactory.deploy();
		await factory.deployed();

		// console.log(factory);
		await factory.initializeFactory(deployer.address);

		const TestToken1 = await ethers.getContractFactory('TestToken1');
		const TestToken2 = await ethers.getContractFactory('TestToken2');

		const token1 = await TestToken1.deploy();
		await token1.deployed();

		console.log('User Token1 balance:', (await token1.balanceOf(deployer.address)).toString());

		const token2 = await TestToken2.deploy();
		await token2.deployed();

		console.log('User Token2 balance:', (await token2.balanceOf(deployer.address)).toString());

		await token1.mint(deployer.address, 100);
		console.log('User Token1 balance:', (await token1.balanceOf(deployer.address)).toString());

		await factory.createExchange(token1.address);
		await factory.createExchange(token2.address);

		const UniswapExchange = await ethers.getContractFactory('UniswapExchange');

		const exchange1 = await UniswapExchange.attach(await factory.getExchange(token1.address));
		console.log('exchange1 address: ', exchange1.address);

		const exchange2 = await UniswapExchange.attach(await factory.getExchange(token2.address));
		console.log('exchange2 address: ', exchange2.address);

		await token1.approve(exchange1.address, 1000000);
		console.log('exchange1 Allowance: ', (await token1.allowance(deployer.address, exchange1.address)).toString());
		await token2.approve(exchange2.address, 1000000);
		console.log('exchange2 Allowance: ', (await token2.allowance(deployer.address, exchange2.address)).toString());
		// console.log(ethers.timestamp);
		await exchange1.addLiquidity(1, '100000', '1654983000', { value: ethers.utils.parseEther('1.0') });
		await exchange2.addLiquidity(1, '100000', '1654983000', { value: ethers.utils.parseEther('1.0') });

		console.log('');
		console.log('User Token1 balance:', (await token1.balanceOf(deployer.address)).toString());
		console.log('User ETH balance:', (await deployer.getBalance()).toString());
		await exchange1.ethToTokenSwapInput(1, '1654983000', { value: ethers.utils.parseEther('0.1') });
		console.log('eth -> token1 swap');
		console.log('User Token1 balance:', (await token1.balanceOf(deployer.address)).toString());
		console.log('User ETH balance:', (await deployer.getBalance()).toString());

		await exchange1.tokenToEthSwapInput(100, 1, '1654983000');
		console.log('token1 -> eth swap');
		console.log('User Token1 balance:', (await token1.balanceOf(deployer.address)).toString());
		console.log('User ETH balance:', (await deployer.getBalance()).toString());

		console.log('liquidity balance: ', (await exchange1.balanceOf(deployer.address)).toString());

		await exchange1.removeLiquidity('1000000000000000000', ethers.utils.parseEther('0.2'), '2000', '1654983000');
		console.log('remove liquidity');
		console.log('User Token1 balance:', (await token1.balanceOf(deployer.address)).toString());
		console.log('User ETH balance:', (await deployer.getBalance()).toString());
		// const testToken1 = await TestToken1.deploy();
		// await testToken1.deployed();
		await exchange1.addLiquidity(1, '100000', '1654983000', { value: ethers.utils.parseEther('1.0') });
		console.log('check ============== check');
		console.log('exchange1 balance: ', (await token1.balanceOf(exchange1.address)).toString());
		console.log('exchange2 balance: ', (await token2.balanceOf(exchange2.address)).toString());
		console.log('check ============== check');
		console.log('token1 to token2');
		console.log('User Token1 balance:', (await token1.balanceOf(deployer.address)).toString());
		console.log('User Token2 balance:', (await token2.balanceOf(deployer.address)).toString());
		console.log('User ETH balance:', (await deployer.getBalance()).toString());

		await exchange1.tokenToTokenSwapInput(
			'100',
			'1',
			ethers.utils.parseEther('0.000000002'),
			'1654983000',
			token2.address
		);

		console.log('User Token1 balance:', (await token1.balanceOf(deployer.address)).toString());
		console.log('User Token2 balance:', (await token2.balanceOf(deployer.address)).toString());
		console.log('User ETH balance:', (await deployer.getBalance()).toString());
		// expect(await greeter.greet()).to.equal('Hello, world!');

		// const setGreetingTx = await greeter.setGreeting('Hola, mundo!');

		// // wait until the transaction is mined
		// await setGreetingTx.wait();

		// expect(await greeter.greet()).to.equal('Hola, mundo!');
	});
});
