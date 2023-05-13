// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { MintUpNft } from "./MintUpNft.sol";
import { Initialisaser } from "./Interfaces/IMintUpNft.sol";

import "lib/openzeppelin-contracts/contracts/access/Ownable.sol";

error addressZero();
error baseUriNotSet();
error nameNotSet();
error symbolNotSet();

contract MintUpFactory is Ownable {
  MintUpNft[] private deployedCollection;

  event NewCollectionDeployed(address indexed collectionAddress);

  function deployNewCollection(Initialisaser calldata initParams) external onlyOwner returns (address) {
    if (initParams.mintUp == address(0)) revert addressZero();
    if (initParams.owner == address(0)) revert addressZero();
    if (bytes(initParams.baseURI).length == 0) revert baseUriNotSet();
    if (bytes(initParams.name).length == 0) revert nameNotSet();
    if (bytes(initParams.symbol).length == 0) revert symbolNotSet();
    MintUpNft newCollection = new MintUpNft(initParams);
    deployedCollection.push(newCollection);
    emit NewCollectionDeployed(address(newCollection));
    return address(newCollection);
  }

  function getAllDeployedCollection() external view returns (MintUpNft[] memory) {
    return deployedCollection;
  }
}