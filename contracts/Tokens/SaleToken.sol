// SPDX-License-Identifier: MIT

// Solidity files have to start with this pragma.
// It will be used by the Solidity compiler to validate its version.
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// This is the main building block for smart contracts.
contract SaleToken is ERC20, Ownable{

    uint256 public constant INITIAL_SUPPLY = 100000 * 1e18;
    uint256 public constant MAX_SUPPLY = 1000000000000 * 1e18;

    address private _minter;

    constructor() ERC20("SaleToken", "ST") {
        _mint(owner(), INITIAL_SUPPLY);
        _minter = _msgSender();
    }

    modifier onlyMinter() {
        // require(_minter == _msgSender(), "mintable: caller is not a minter");
        _;
    }

    function mint(address _to, uint256 _amount) public onlyMinter {
        uint256 supplied = totalSupply();
        require(supplied < MAX_SUPPLY, "exceed total supply of token");
        uint256 available = MAX_SUPPLY - (supplied);
        if (available > _amount) _mint(_to, _amount);
        else _mint(_to, available);
    }

    function updateMinter(address newMinter) public onlyOwner {
        _minter = newMinter;
    }
    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);
        uint256 a = allowance(sender, _msgSender());
        _approve(sender, _msgSender(), a - amount);
        return true;
    }

    function minter() public view onlyOwner returns (address) {
        return _minter;
    }
}