require('dotenv').config();
require('@nomiclabs/hardhat-waffle');
require('@nomiclabs/hardhat-etherscan');

const kovanSettings = {
	url: 'https://kovan.infura.io/v3/ba1d4abd37bc45a89767f6c3b3e131ef',
	privateKey: process.env.PRIVATE_KEY,
};

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more
/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
	solidity: {
		version: '0.8.1',
		settings: {
			optimizer: {
				enabled: true,
				runs: 200,
			},
		},
	},
	defaultNetwork: 'kovan',
	networks: {
		// ropsten: {
		// 	url: ropstenSettings.url,
		// 	accounts: [`${ropstenSettings.privateKey}`],
		// },
		kovan: {
			url: kovanSettings.url,
			accounts: [`${kovanSettings.privateKey}`],
		},
		// rinkeby: {
		// 	url: rinkebySettings.url,
		// 	accounts: [`${rinkebySettings.privateKey}`],
		// },
	},

	etherscan: {
		apiKey: process.env.ETHERSCAN_API_KEY,
	},
	paths: {
		sources: './contracts',
		tests: './test',
		cache: './cache',
		artifacts: './artifacts',
	},
	mocha: {
		timeout: 40000,
	},
};
