// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Test.sol";

import "../src/MintUpFactory.sol";
import { MintUpNft } from "../src/MintUpNft.sol";

contract MintUpFactoryTest is Test {
  MintUpFactory public mintUpFactory;
  // MintUpNft[] public nftDeployed;

  uint256 internal ownerPrivateKey;
  address internal owner;
  uint256 internal user1PrivateKey;
  address internal user1;
  uint256 internal royaltiesPrivateKey;
  address internal royaltiesAddress;
  uint256 internal crossmintPrivateKey;
  address internal crossmintAddress;
  uint256 internal signerPrivateKey;
  address internal signerAddress;
  uint256 internal mintUpPrivateKey;
  address internal mintUpAddress;

  function setUp() public {
    ownerPrivateKey = 0xA11CE;
    owner = vm.addr(ownerPrivateKey);
    user1PrivateKey = 0xB0B;
    user1 = vm.addr(user1PrivateKey);
    royaltiesPrivateKey = 0xD0E;
    royaltiesAddress = vm.addr(royaltiesPrivateKey);
    crossmintPrivateKey = 0xBDB;
    crossmintAddress = vm.addr(crossmintPrivateKey);
    signerPrivateKey = 0xEEED;
    signerAddress = vm.addr(signerPrivateKey);
    mintUpPrivateKey = 0xEEED;
    mintUpAddress = vm.addr(mintUpPrivateKey);

    mintUpFactory = new MintUpFactory();
  }

  function setInitialisaserETH() public view returns(Initialisaser memory) {
    Initialisaser memory init;
    init.name = "TEST";
    init.symbol = "TEST";
    init.baseURI = "baseURI/";
    init.owner = owner;
    init.signer = signerAddress;
    init.mintUp = mintUpAddress;
    init.royaltiesRecipient = royaltiesAddress;
    init.maxSupply = 100;
    init.publicPrice = 1 ether;
    init.whitelistPrice = 0.5 ether;
    init.saleTimeStarts = block.timestamp + 100;
    init.saleTimeEnds = init.saleTimeStarts + 3 hours;
    init.mintUpPart = 1000;
    init.maxPerAddress = 10;
    init.royaltiesAmount = 1000;
    init.random = false;
    init.paymentMethod = false;
    return init;
  }

  function testDeployNewCollection() public {
    address newCollection = mintUpFactory.deployNewCollection(setInitialisaserETH());
    require(newCollection != address(0), "fail deploy new collection");
  }

  function testGetAllDeployedCollection() public {
    MintUpNft[] memory nftDeployed;
    nftDeployed = mintUpFactory.getAllDeployedCollection();
    require(nftDeployed.length == 0);
    mintUpFactory.deployNewCollection(setInitialisaserETH());
    nftDeployed = mintUpFactory.getAllDeployedCollection();
    require(nftDeployed.length == 1, "fail get nft deploy");
  }
}