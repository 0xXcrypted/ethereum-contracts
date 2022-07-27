//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import './IERC721.sol';
import "@openzeppelin/contracts/utils/Counters.sol";
import '@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol';

contract WillController is ERC721Holder {
  using Counters for Counters.Counter;
  Counters.Counter private willCounter;

  mapping (uint256 => Will) public _will;
  mapping (uint256 => address) public willToWiller;
  mapping (uint256 => address) public willToRecipient;

  enum Status {
    vaild,
    completed,
    cancelled
  }

  struct Will {
    uint256 lastActionBlock;
    uint256 actionInterval;
    address collectionAddress;
    uint256 collectionId;
    address willer;
    address recipient;
    uint256 willOrderId;
    Status status;
  }

    modifier onlyWiller(uint256 willId) {
    require(_will[willId].willer == msg.sender);
    _;
  }

  modifier onlyRecipient(uint256 willId) {
    require(_will[willId].recipient == msg.sender);
    _;
  }

  function createWill(uint256 _actionInterval, address _collectionAddress, uint256 _collectionId, address _recipient) public {
    Will memory newWill;
    newWill.lastActionBlock = block.number;
    newWill.actionInterval = _actionInterval;
    newWill.collectionAddress = _collectionAddress;
    newWill.collectionId = _collectionId;
    newWill.willer = msg.sender;
    newWill.recipient = _recipient;
    newWill.willOrderId = 0;
    newWill.status = Status.vaild;

    IERC721(_collectionAddress).safeTransferFrom(msg.sender, address(this), _collectionId);

    uint256 currentId = willCounter.current();

    _will[currentId] = newWill;
    willToWiller[currentId] = msg.sender;
    willToRecipient[currentId] = _recipient;

    willCounter.increment();
  }

  function resetActionBlock(uint256 _willId) public onlyWiller(_willId) {
    Will memory will = _will[_willId];
    Will memory newWill;
    require(will.status == Status.vaild);
    require(will.lastActionBlock + will.actionInterval > block.number);
    
    newWill.lastActionBlock = block.number;
    newWill.actionInterval = will.actionInterval;
    newWill.collectionAddress = will.collectionAddress;
    newWill.collectionId = will.collectionId;
    newWill.willer = will.willer;
    newWill.recipient = will.recipient;
    newWill.willOrderId = will.willOrderId;
    newWill.status = will.status;

    _will[_willId] = newWill;
  }

  function cancelWIll(uint256 _willId) public onlyWiller(_willId) {
    Will memory will = _will[_willId];
    Will memory newWill;
    require(will.status == Status.vaild);
    require(will.lastActionBlock + will.actionInterval > block.number);
    will.status = Status.completed;

    newWill.actionInterval = will.actionInterval;
    newWill.collectionAddress = will.collectionAddress;
    newWill.collectionId = will.collectionId;
    newWill.willer = will.willer;
    newWill.recipient = will.recipient;
    newWill.willOrderId = will.willOrderId;
    newWill.status = Status.cancelled;


    _will[_willId] = newWill;

    IERC721(will.collectionAddress).approve(will.willer, will.collectionId);
    IERC721(will.collectionAddress).safeTransferFrom(address(this), will.willer, will.collectionId);
  }

  function claimWIll(uint256 _willId) public onlyRecipient(_willId) {
    Will memory will = _will[_willId];
    Will memory newWill;
    require(will.status == Status.vaild);
    require(will.lastActionBlock + will.actionInterval < block.number);
    will.status = Status.completed;

    newWill.actionInterval = will.actionInterval;
    newWill.collectionAddress = will.collectionAddress;
    newWill.collectionId = will.collectionId;
    newWill.willer = will.willer;
    newWill.recipient = will.recipient;
    newWill.willOrderId = will.willOrderId;
    newWill.status = Status.completed;

    _will[_willId] = newWill;

    IERC721(will.collectionAddress).approve(will.recipient, will.collectionId);
    IERC721(will.collectionAddress).safeTransferFrom(address(this), will.recipient, will.collectionId);
  }

  // getter functions
  function getWill(uint256 _willId) public view returns (Will memory) {
    return _will[_willId];
  }

  function getWillToWiller(uint256 _willId) public view returns (address) {
    return willToWiller[_willId];
  }

  function getWillToRecipient(uint256 _willId) public view returns (address) {
    return willToRecipient[_willId];
  }

  function getWillCounter() public view returns (uint256) {
    return willCounter.current();
  }

  function getWillStatus(uint256 _willId) public view returns (Status) {
    return _will[_willId].status;
  }
}