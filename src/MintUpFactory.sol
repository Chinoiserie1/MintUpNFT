// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { MintUpNft } from "./MintUpNft.sol";
import { Initialisaser } from "./Interfaces/IMintUpNft.sol";

import "lib/openzeppelin-contracts/contracts/access/Ownable.sol";

error addressZero();

contract MintUpFactory is Ownable {
  MintUpNft[] public deployedCollection;

  event NewCollectionDeployed(address indexed collectionAddress);

  function deployNewCollection(Initialisaser calldata initParams) external onlyOwner returns (address) {
    if (initParams.mintUp == address(0)) revert addressZero();
    if (initParams.owner == address(0)) revert addressZero();
    MintUpNft newCollection = new MintUpNft(initParams);
    deployedCollection.push(newCollection);
    emit NewCollectionDeployed(address(newCollection));
    return address(newCollection);
  }
}