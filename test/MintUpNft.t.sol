// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Test.sol";

import "../src/MintUpNft.sol";
import "../src/Error/Error.sol";
import "../src/Interfaces/IMintUpNft.sol";

contract MintUpNftTest is Test {
  MintUpNft public mintUpNft;

  uint256 internal ownerPrivateKey;
  address internal owner;
  uint256 internal user1PrivateKey;
  address internal user1;
  uint256 internal user2PrivateKey;
  address internal user2;
  uint256 internal user3PrivateKey;
  address internal user3;
  uint256 internal royaltiesPrivateKey;
  address internal royaltiesAddress;
  uint256 internal crossmintPrivateKey;
  address internal crossmintAddress;
  uint256 internal signerPrivateKey;
  address internal signerAddress;
  uint256 internal mintUpPrivateKey;
  address internal mintUpAddress;

  Initialisaser initETH;

  function setUp() public {
    ownerPrivateKey = 0xA11CE;
    owner = vm.addr(ownerPrivateKey);
    user1PrivateKey = 0xB0B;
    user1 = vm.addr(user1PrivateKey);
    user2PrivateKey = 0xFED;
    user2 = vm.addr(user2PrivateKey);
    user3PrivateKey = 0xAD1;
    user3 = vm.addr(user3PrivateKey);
    royaltiesPrivateKey = 0xD0E;
    royaltiesAddress = vm.addr(royaltiesPrivateKey);
    crossmintPrivateKey = 0xBDB;
    crossmintAddress = vm.addr(crossmintPrivateKey);
    signerPrivateKey = 0xEEED;
    signerAddress = vm.addr(signerPrivateKey);
    mintUpPrivateKey = 0xEEED;
    mintUpAddress = vm.addr(mintUpPrivateKey);
    vm.startPrank(owner);

    initETH = setInitialisaserETH();

    mintUpNft = new MintUpNft(initETH);
  }

  function setInitialisaserETH() public view returns(Initialisaser memory) {
    Initialisaser memory init;
    init.name = "TEST";
    init.symbol = "TEST";
    init.baseURI = "baseURI/";
    init.crossmintAddy = crossmintAddress;
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

  function testDefaultRoyalties() view public {
    uint256 _amount = 1000;
    (address _royaltiesAddy, uint256 _royalties) = mintUpNft.royaltyInfo(1, _amount);
    require(_royaltiesAddy == initETH.royaltiesRecipient, "fail set royalties recipient");
    require(_royalties == _amount * initETH.royaltiesAmount / 10000);
  }

  function testOwner() view public {
    address _owner = mintUpNft.owner();
    require(_owner == initETH.owner, "fail transfer ownership");
  }

  
}