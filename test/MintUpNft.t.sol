// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Test.sol";

import "../src/MintUpNft.sol";
import "../src/Error/Error.sol";
import "../src/Interfaces/IMintUpNft.sol";
import { Verification } from "../src/Verification/Verification.sol";

contract MintUpNftTest is Test {
  MintUpNft public mintUpNft;
  MintUpNft public mintUpNftRandom;

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
  Initialisaser initETHRandom;

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
    initETHRandom = setInitialisaserETHRandom();

    mintUpNft = new MintUpNft(initETH);
    mintUpNftRandom = new MintUpNft(initETHRandom);
  }

  function signMessage(address _contract, address _to, uint256 _amount, Phase _phase) internal view returns (bytes memory) {
    bytes32 hash = Verification.getMessageHash(_contract, _to, _amount, _phase);
    bytes32 finalHash = Verification.getEthSignedMessageHash(hash);
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, finalHash);
    bytes memory signature = abi.encodePacked(r, s, v);
    return signature;
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

  function setInitialisaserETHRandom() public view returns(Initialisaser memory) {
    Initialisaser memory init = setInitialisaserETH();
    init.random = true;
    init.maxSupply = 10;
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

  // PREMINT
  function testPremintUser1Successful() public {
    mintUpNft.setPhase(Phase.premint);
    vm.warp(block.timestamp + 101);
    bytes memory sign = signMessage(address(mintUpNft), user1, 2, Phase.premint);
    vm.stopPrank();
    vm.startPrank(user1);
    mintUpNft.premint(2, 2, sign);
    uint256 balanceAfter = mintUpNft.balanceOf(user1);
    require(balanceAfter == 2, "fail to mint");
  }

  function testSaleNotStarted() public {
    mintUpNft.setPhase(Phase.premint);
    bytes memory sign = signMessage(address(mintUpNft), user1, 2, Phase.premint);
    vm.stopPrank();
    vm.startPrank(user1);
    vm.expectRevert(saleNotStarted.selector);
    mintUpNft.premint(2, 2, sign);
  }

  function testSaleIncorectPhase() public {
    vm.warp(block.timestamp + 101);
    bytes memory sign = signMessage(address(mintUpNft), user1, 2, Phase.premint);
    vm.stopPrank();
    vm.startPrank(user1);
    vm.expectRevert(incorectPhase.selector);
    mintUpNft.premint(2, 2, sign);
  }

  function testPremintUser1SuccessfullWith2calls() public {
    mintUpNft.setPhase(Phase.premint);
    vm.warp(block.timestamp + 101);
    bytes memory sign = signMessage(address(mintUpNft), user1, 2, Phase.premint);
    vm.stopPrank();
    vm.startPrank(user1);
    mintUpNft.premint(1, 2, sign);
    uint256 balanceAfter = mintUpNft.balanceOf(user1);
    require(balanceAfter == 1, "fail to mint 1");
    mintUpNft.premint(1, 2, sign);
    balanceAfter = mintUpNft.balanceOf(user1);
    require(balanceAfter == 2, "fail to mint 1 more");
  }

  function testPremintFailMint3withWitelistOf2() public {
    mintUpNft.setPhase(Phase.premint);
    vm.warp(block.timestamp + 101);
    bytes memory sign = signMessage(address(mintUpNft), user1, 2, Phase.premint);
    vm.stopPrank();
    vm.startPrank(user1);
    vm.expectRevert(quantityExceed.selector);
    mintUpNft.premint(3, 2, sign);
  }

  function testPremintFailMint2andMint1AfterWith2Whitelist() public {
    mintUpNft.setPhase(Phase.premint);
    vm.warp(block.timestamp + 101);
    bytes memory sign = signMessage(address(mintUpNft), user1, 2, Phase.premint);
    vm.stopPrank();
    vm.startPrank(user1);
    mintUpNft.premint(2, 2, sign);
    vm.expectRevert(quantityExceed.selector);
    mintUpNft.premint(1, 2, sign);
  }

  function testPremintWithExceedMaxPerAddressNeedToSuccess() public {
    mintUpNft.setPhase(Phase.premint);
    vm.warp(block.timestamp + 101);
    bytes memory sign = signMessage(address(mintUpNft), user1, 20, Phase.premint);
    vm.stopPrank();
    vm.startPrank(user1);
    mintUpNft.premint(20, 20, sign);
  }

  function testPremintFailWithAmountZero() public {
    mintUpNft.setPhase(Phase.premint);
    vm.warp(block.timestamp + 101);
    bytes memory sign = signMessage(address(mintUpNft), user1, 1, Phase.premint);
    vm.stopPrank();
    vm.startPrank(user1);
    vm.expectRevert(quantityZero.selector);
    mintUpNft.premint(0, 1, sign);
  }

  function testPremintFailIncorrectUserWhitelist() public {
    mintUpNft.setPhase(Phase.premint);
    vm.warp(block.timestamp + 101);
    bytes memory sign = signMessage(address(mintUpNft), user1, 1, Phase.premint);
    vm.stopPrank();
    vm.startPrank(user2);
    vm.expectRevert(invalidSignature.selector);
    mintUpNft.premint(0, 1, sign);
  }

  function testPremintIncorrectSignature() public {
    mintUpNft.setPhase(Phase.premint);
    vm.warp(block.timestamp + 101);
    bytes memory sign = signMessage(address(mintUpNft), user1, 1, Phase.whitelistMint);
    vm.stopPrank();
    vm.startPrank(user1);
    vm.expectRevert(invalidSignature.selector);
    mintUpNft.premint(1, 1, sign);
  }

  function testPremintFailMintMoreThanMaxSupplyIn1Call() public {
    mintUpNft.setPhase(Phase.premint);
    vm.warp(block.timestamp + 101);
    bytes memory sign = signMessage(address(mintUpNft), user1, 101, Phase.premint);
    vm.stopPrank();
    vm.startPrank(user1);
    vm.expectRevert(maxSupplyReach.selector);
    mintUpNft.premint(101, 101, sign);
  }

  function testPremintFailMintMoreThanMaxSupplyMultipleCall() public {
    mintUpNft.setPhase(Phase.premint);
    vm.warp(block.timestamp + 101);
    bytes memory sign = signMessage(address(mintUpNft), user1, 101, Phase.premint);
    vm.stopPrank();
    vm.startPrank(user1);
    mintUpNft.premint(100, 101, sign);
    vm.expectRevert(maxSupplyReach.selector);
    mintUpNft.premint(1, 101, sign);
  }

  function testPremintAllSupply() public {
    mintUpNft.setPhase(Phase.premint);
    vm.warp(block.timestamp + 101);
    bytes memory sign = signMessage(address(mintUpNft), user1, 100, Phase.premint);
    vm.stopPrank();
    vm.startPrank(user1);
    mintUpNft.premint(100, 100, sign);
  }

  function testPremintFailSalesEnded() public {
    mintUpNft.setPhase(Phase.premint);
    vm.warp(block.timestamp + 4 hours);
    bytes memory sign = signMessage(address(mintUpNft), user1, 10, Phase.premint);
    vm.stopPrank();
    vm.startPrank(user1);
    vm.expectRevert(saleEnded.selector);
    mintUpNft.premint(10, 10, sign);
  }

  function testPremintRandom() public {
    mintUpNftRandom.setPhase(Phase.premint);
    vm.warp(block.timestamp + 101);
    bytes memory sign = signMessage(address(mintUpNftRandom), user1, 10, Phase.premint);
    vm.stopPrank();
    vm.startPrank(user1);
    mintUpNftRandom.premint(10, 10, sign);
    string memory URI1 = mintUpNftRandom.tokenURI(1);
    string memory URI2 = mintUpNftRandom.tokenURI(2);
    string memory URI3 = mintUpNftRandom.tokenURI(3);
    string memory URI4 = mintUpNftRandom.tokenURI(4);
    string memory URI5 = mintUpNftRandom.tokenURI(5);
    string memory URI6 = mintUpNftRandom.tokenURI(6);
    string memory URI7 = mintUpNftRandom.tokenURI(7);
    string memory URI8 = mintUpNftRandom.tokenURI(8);
    string memory URI9 = mintUpNftRandom.tokenURI(9);
    string memory URI10 = mintUpNftRandom.tokenURI(10);
    require(
      keccak256(abi.encode(URI1)) != keccak256(abi.encode(URI2))
      && keccak256(abi.encode(URI1)) != keccak256(abi.encode(URI3))
      && keccak256(abi.encode(URI1)) != keccak256(abi.encode(URI4))
      && keccak256(abi.encode(URI1)) != keccak256(abi.encode(URI5))
      && keccak256(abi.encode(URI1)) != keccak256(abi.encode(URI6))
      && keccak256(abi.encode(URI1)) != keccak256(abi.encode(URI7))
      && keccak256(abi.encode(URI1)) != keccak256(abi.encode(URI8))
      && keccak256(abi.encode(URI1)) != keccak256(abi.encode(URI9))
      && keccak256(abi.encode(URI1)) != keccak256(abi.encode(URI10))
      , "Fail Random"
    );
    require(
      keccak256(abi.encode(URI2)) != keccak256(abi.encode(URI1))
      && keccak256(abi.encode(URI2)) != keccak256(abi.encode(URI3))
      && keccak256(abi.encode(URI2)) != keccak256(abi.encode(URI4))
      && keccak256(abi.encode(URI2)) != keccak256(abi.encode(URI5))
      && keccak256(abi.encode(URI2)) != keccak256(abi.encode(URI6))
      && keccak256(abi.encode(URI2)) != keccak256(abi.encode(URI7))
      && keccak256(abi.encode(URI2)) != keccak256(abi.encode(URI8))
      && keccak256(abi.encode(URI2)) != keccak256(abi.encode(URI9))
      && keccak256(abi.encode(URI2)) != keccak256(abi.encode(URI10))
      , "Fail Random"
    );
    require(
      keccak256(abi.encode(URI3)) != keccak256(abi.encode(URI2))
      && keccak256(abi.encode(URI3)) != keccak256(abi.encode(URI1))
      && keccak256(abi.encode(URI3)) != keccak256(abi.encode(URI4))
      && keccak256(abi.encode(URI3)) != keccak256(abi.encode(URI5))
      && keccak256(abi.encode(URI3)) != keccak256(abi.encode(URI6))
      && keccak256(abi.encode(URI3)) != keccak256(abi.encode(URI7))
      && keccak256(abi.encode(URI3)) != keccak256(abi.encode(URI8))
      && keccak256(abi.encode(URI3)) != keccak256(abi.encode(URI9))
      && keccak256(abi.encode(URI3)) != keccak256(abi.encode(URI10))
      , "Fail Random"
    );
    require(
      keccak256(abi.encode(URI4)) != keccak256(abi.encode(URI2))
      && keccak256(abi.encode(URI4)) != keccak256(abi.encode(URI3))
      && keccak256(abi.encode(URI4)) != keccak256(abi.encode(URI1))
      && keccak256(abi.encode(URI4)) != keccak256(abi.encode(URI5))
      && keccak256(abi.encode(URI4)) != keccak256(abi.encode(URI6))
      && keccak256(abi.encode(URI4)) != keccak256(abi.encode(URI7))
      && keccak256(abi.encode(URI4)) != keccak256(abi.encode(URI8))
      && keccak256(abi.encode(URI4)) != keccak256(abi.encode(URI9))
      && keccak256(abi.encode(URI4)) != keccak256(abi.encode(URI10))
      , "Fail Random"
    );
    require(
      keccak256(abi.encode(URI5)) != keccak256(abi.encode(URI2))
      && keccak256(abi.encode(URI5)) != keccak256(abi.encode(URI3))
      && keccak256(abi.encode(URI5)) != keccak256(abi.encode(URI4))
      && keccak256(abi.encode(URI5)) != keccak256(abi.encode(URI1))
      && keccak256(abi.encode(URI5)) != keccak256(abi.encode(URI6))
      && keccak256(abi.encode(URI5)) != keccak256(abi.encode(URI7))
      && keccak256(abi.encode(URI5)) != keccak256(abi.encode(URI8))
      && keccak256(abi.encode(URI5)) != keccak256(abi.encode(URI9))
      && keccak256(abi.encode(URI5)) != keccak256(abi.encode(URI10))
      , "Fail Random"
    );
    require(
      keccak256(abi.encode(URI6)) != keccak256(abi.encode(URI2))
      && keccak256(abi.encode(URI6)) != keccak256(abi.encode(URI3))
      && keccak256(abi.encode(URI6)) != keccak256(abi.encode(URI4))
      && keccak256(abi.encode(URI6)) != keccak256(abi.encode(URI5))
      && keccak256(abi.encode(URI6)) != keccak256(abi.encode(URI1))
      && keccak256(abi.encode(URI6)) != keccak256(abi.encode(URI7))
      && keccak256(abi.encode(URI6)) != keccak256(abi.encode(URI8))
      && keccak256(abi.encode(URI6)) != keccak256(abi.encode(URI9))
      && keccak256(abi.encode(URI6)) != keccak256(abi.encode(URI10))
      , "Fail Random"
    );
    require(
      keccak256(abi.encode(URI7)) != keccak256(abi.encode(URI2))
      && keccak256(abi.encode(URI7)) != keccak256(abi.encode(URI3))
      && keccak256(abi.encode(URI7)) != keccak256(abi.encode(URI4))
      && keccak256(abi.encode(URI7)) != keccak256(abi.encode(URI5))
      && keccak256(abi.encode(URI7)) != keccak256(abi.encode(URI6))
      && keccak256(abi.encode(URI7)) != keccak256(abi.encode(URI1))
      && keccak256(abi.encode(URI7)) != keccak256(abi.encode(URI8))
      && keccak256(abi.encode(URI7)) != keccak256(abi.encode(URI9))
      && keccak256(abi.encode(URI7)) != keccak256(abi.encode(URI10))
      , "Fail Random"
    );
    require(
      keccak256(abi.encode(URI8)) != keccak256(abi.encode(URI2))
      && keccak256(abi.encode(URI8)) != keccak256(abi.encode(URI3))
      && keccak256(abi.encode(URI8)) != keccak256(abi.encode(URI4))
      && keccak256(abi.encode(URI8)) != keccak256(abi.encode(URI5))
      && keccak256(abi.encode(URI8)) != keccak256(abi.encode(URI6))
      && keccak256(abi.encode(URI8)) != keccak256(abi.encode(URI7))
      && keccak256(abi.encode(URI8)) != keccak256(abi.encode(URI1))
      && keccak256(abi.encode(URI8)) != keccak256(abi.encode(URI9))
      && keccak256(abi.encode(URI8)) != keccak256(abi.encode(URI10))
      , "Fail Random"
    );
    require(
      keccak256(abi.encode(URI9)) != keccak256(abi.encode(URI2))
      && keccak256(abi.encode(URI9)) != keccak256(abi.encode(URI3))
      && keccak256(abi.encode(URI9)) != keccak256(abi.encode(URI4))
      && keccak256(abi.encode(URI9)) != keccak256(abi.encode(URI5))
      && keccak256(abi.encode(URI9)) != keccak256(abi.encode(URI6))
      && keccak256(abi.encode(URI9)) != keccak256(abi.encode(URI7))
      && keccak256(abi.encode(URI9)) != keccak256(abi.encode(URI8))
      && keccak256(abi.encode(URI9)) != keccak256(abi.encode(URI1))
      && keccak256(abi.encode(URI9)) != keccak256(abi.encode(URI10))
      , "Fail Random"
    );
    require(
      keccak256(abi.encode(URI10)) != keccak256(abi.encode(URI2))
      && keccak256(abi.encode(URI10)) != keccak256(abi.encode(URI3))
      && keccak256(abi.encode(URI10)) != keccak256(abi.encode(URI4))
      && keccak256(abi.encode(URI10)) != keccak256(abi.encode(URI5))
      && keccak256(abi.encode(URI10)) != keccak256(abi.encode(URI6))
      && keccak256(abi.encode(URI10)) != keccak256(abi.encode(URI7))
      && keccak256(abi.encode(URI10)) != keccak256(abi.encode(URI8))
      && keccak256(abi.encode(URI10)) != keccak256(abi.encode(URI9))
      && keccak256(abi.encode(URI10)) != keccak256(abi.encode(URI1))
      , "Fail Random"
    );
  }

  function testPremintFailWithAnotherContractSignature() public {
    mintUpNft.setPhase(Phase.premint);
    vm.warp(block.timestamp + 101);
    bytes memory sign = signMessage(address(mintUpNftRandom), user1, 2, Phase.premint);
    vm.stopPrank();
    vm.startPrank(user1);
    vm.expectRevert(invalidSignature.selector);
    mintUpNft.premint(2, 2, sign);
  }

  // WHITELISTMINT
  function testWhitelistMint() public {
    mintUpNft.setPhase(Phase.whitelistMint);
    vm.warp(block.timestamp + 101);
    bytes memory sign = signMessage(address(mintUpNft), user1, 2, Phase.whitelistMint);
    vm.stopPrank();
    vm.startPrank(user1);
    vm.deal(user1, 1 ether);
    mintUpNft.whitelistMint{ value: initETH.whitelistPrice * 2 }(user1, 2, 2, sign);
  }

  function testWhitelistMintFailIncorrectPhase() public {
    mintUpNft.setPhase(Phase.premint);
    vm.warp(block.timestamp + 101);
    bytes memory sign = signMessage(address(mintUpNft), user1, 2, Phase.whitelistMint);
    vm.stopPrank();
    vm.startPrank(user1);
    vm.deal(user1, 1 ether);
    vm.expectRevert(incorectPhase.selector);
    mintUpNft.whitelistMint{ value: initETH.whitelistPrice * 2 }(user1, 2, 2, sign);
  }

  function testWhitelistMintFailSaleNotStarted() public {
    mintUpNft.setPhase(Phase.whitelistMint);
    bytes memory sign = signMessage(address(mintUpNft), user1, 2, Phase.whitelistMint);
    vm.stopPrank();
    vm.startPrank(user1);
    vm.deal(user1, 1 ether);
    vm.expectRevert(saleNotStarted.selector);
    mintUpNft.whitelistMint{ value: initETH.whitelistPrice * 2 }(user1, 2, 2, sign);
  }

  function testWhitelistMintFailSaleEnded() public {
    mintUpNft.setPhase(Phase.whitelistMint);
    vm.warp(block.timestamp + 4 hours);
    bytes memory sign = signMessage(address(mintUpNft), user1, 2, Phase.whitelistMint);
    vm.stopPrank();
    vm.startPrank(user1);
    vm.deal(user1, 1 ether);
    vm.expectRevert(saleEnded.selector);
    mintUpNft.whitelistMint{ value: initETH.whitelistPrice * 2 }(user1, 2, 2, sign);
  }

  function testWhitelistMintFailAmountSendIncorrect() public {
    mintUpNft.setPhase(Phase.whitelistMint);
    vm.warp(block.timestamp + 101);
    bytes memory sign = signMessage(address(mintUpNft), user1, 2, Phase.whitelistMint);
    vm.stopPrank();
    vm.startPrank(user1);
    vm.deal(user1, 1 ether);
    vm.expectRevert(amountSendIncorrect.selector);
    mintUpNft.whitelistMint{ value : initETH.whitelistPrice }(user1, 2, 2, sign);
  }

  function testWhitelistMintFailIncorrectUserWhitelist() public {
    mintUpNft.setPhase(Phase.whitelistMint);
    vm.warp(block.timestamp + 101);
    bytes memory sign = signMessage(address(mintUpNft), user2, 2, Phase.whitelistMint);
    vm.stopPrank();
    vm.startPrank(user1);
    vm.deal(user1, 1 ether);
    vm.expectRevert(invalidSignature.selector);
    mintUpNft.whitelistMint{ value: initETH.whitelistPrice * 2 }(user1, 2, 2, sign);
  }

  function testWhitelistMintFailIncorrectPhaseInSignature() public {
    mintUpNft.setPhase(Phase.whitelistMint);
    vm.warp(block.timestamp + 101);
    bytes memory sign = signMessage(address(mintUpNft), user1, 2, Phase.premint);
    vm.stopPrank();
    vm.startPrank(user1);
    vm.deal(user1, 1 ether);
    vm.expectRevert(invalidSignature.selector);
    mintUpNft.whitelistMint{ value: initETH.whitelistPrice * 2 }(user1, 2, 2, sign);
  }

  function testWhitelistMintInMultipleCall() public {
    mintUpNft.setPhase(Phase.whitelistMint);
    vm.warp(block.timestamp + 101);
    bytes memory sign = signMessage(address(mintUpNft), user1, 2, Phase.whitelistMint);
    vm.stopPrank();
    vm.startPrank(user1);
    vm.deal(user1, 1 ether);
    mintUpNft.whitelistMint{ value: initETH.whitelistPrice }(user1, 1, 2, sign);
    mintUpNft.whitelistMint{ value: initETH.whitelistPrice }(user1, 1, 2, sign);
    uint256 balanceAfter = mintUpNft.balanceOf(user1);
    require(balanceAfter == 2, "fail whitelist mint in 2 call");
  }

  function testWhitelistMintFailExceedAllowedWhitelist() public {
    mintUpNft.setPhase(Phase.whitelistMint);
    vm.warp(block.timestamp + 101);
    bytes memory sign = signMessage(address(mintUpNft), user1, 2, Phase.whitelistMint);
    vm.stopPrank();
    vm.startPrank(user1);
    vm.deal(user1, 2 ether);
    mintUpNft.whitelistMint{ value: initETH.whitelistPrice }(user1, 1, 2, sign);
    mintUpNft.whitelistMint{ value: initETH.whitelistPrice }(user1, 1, 2, sign);
    uint256 balanceAfter = mintUpNft.balanceOf(user1);
    require(balanceAfter == 2, "fail whitelist mint in 2 call");
    vm.expectRevert(quantityExceed.selector);
    mintUpNft.whitelistMint{ value: initETH.whitelistPrice }(user1, 1, 2, sign);
  }

  function testWhitelistMintFailAmountZero() public {
    mintUpNft.setPhase(Phase.whitelistMint);
    vm.warp(block.timestamp + 101);
    bytes memory sign = signMessage(address(mintUpNft), user1, 2, Phase.whitelistMint);
    vm.stopPrank();
    vm.startPrank(user1);
    vm.deal(user1, 1 ether);
    vm.expectRevert(quantityZero.selector);
    mintUpNft.whitelistMint{ value: initETH.whitelistPrice * 2 }(user1, 0, 2, sign);
  }

  function testWhitelistMintRandom() public {
    mintUpNftRandom.setPhase(Phase.whitelistMint);
    vm.warp(block.timestamp + 101);
    bytes memory sign = signMessage(address(mintUpNftRandom), user1, 10, Phase.whitelistMint);
    vm.stopPrank();
    vm.startPrank(user1);
    vm.deal(user1, 10 ether);
    mintUpNftRandom.whitelistMint{ value: initETH.whitelistPrice * 10 }(user1, 10, 10, sign);
    string memory URI1 = mintUpNftRandom.tokenURI(1);
    string memory URI2 = mintUpNftRandom.tokenURI(2);
    string memory URI3 = mintUpNftRandom.tokenURI(3);
    string memory URI4 = mintUpNftRandom.tokenURI(4);
    string memory URI5 = mintUpNftRandom.tokenURI(5);
    string memory URI6 = mintUpNftRandom.tokenURI(6);
    string memory URI7 = mintUpNftRandom.tokenURI(7);
    string memory URI8 = mintUpNftRandom.tokenURI(8);
    string memory URI9 = mintUpNftRandom.tokenURI(9);
    string memory URI10 = mintUpNftRandom.tokenURI(10);
    require(
      keccak256(abi.encode(URI1)) != keccak256(abi.encode(URI2))
      && keccak256(abi.encode(URI1)) != keccak256(abi.encode(URI3))
      && keccak256(abi.encode(URI1)) != keccak256(abi.encode(URI4))
      && keccak256(abi.encode(URI1)) != keccak256(abi.encode(URI5))
      && keccak256(abi.encode(URI1)) != keccak256(abi.encode(URI6))
      && keccak256(abi.encode(URI1)) != keccak256(abi.encode(URI7))
      && keccak256(abi.encode(URI1)) != keccak256(abi.encode(URI8))
      && keccak256(abi.encode(URI1)) != keccak256(abi.encode(URI9))
      && keccak256(abi.encode(URI1)) != keccak256(abi.encode(URI10))
      , "Fail Random"
    );
    require(
      keccak256(abi.encode(URI2)) != keccak256(abi.encode(URI1))
      && keccak256(abi.encode(URI2)) != keccak256(abi.encode(URI3))
      && keccak256(abi.encode(URI2)) != keccak256(abi.encode(URI4))
      && keccak256(abi.encode(URI2)) != keccak256(abi.encode(URI5))
      && keccak256(abi.encode(URI2)) != keccak256(abi.encode(URI6))
      && keccak256(abi.encode(URI2)) != keccak256(abi.encode(URI7))
      && keccak256(abi.encode(URI2)) != keccak256(abi.encode(URI8))
      && keccak256(abi.encode(URI2)) != keccak256(abi.encode(URI9))
      && keccak256(abi.encode(URI2)) != keccak256(abi.encode(URI10))
      , "Fail Random"
    );
    require(
      keccak256(abi.encode(URI3)) != keccak256(abi.encode(URI2))
      && keccak256(abi.encode(URI3)) != keccak256(abi.encode(URI1))
      && keccak256(abi.encode(URI3)) != keccak256(abi.encode(URI4))
      && keccak256(abi.encode(URI3)) != keccak256(abi.encode(URI5))
      && keccak256(abi.encode(URI3)) != keccak256(abi.encode(URI6))
      && keccak256(abi.encode(URI3)) != keccak256(abi.encode(URI7))
      && keccak256(abi.encode(URI3)) != keccak256(abi.encode(URI8))
      && keccak256(abi.encode(URI3)) != keccak256(abi.encode(URI9))
      && keccak256(abi.encode(URI3)) != keccak256(abi.encode(URI10))
      , "Fail Random"
    );
    require(
      keccak256(abi.encode(URI4)) != keccak256(abi.encode(URI2))
      && keccak256(abi.encode(URI4)) != keccak256(abi.encode(URI3))
      && keccak256(abi.encode(URI4)) != keccak256(abi.encode(URI1))
      && keccak256(abi.encode(URI4)) != keccak256(abi.encode(URI5))
      && keccak256(abi.encode(URI4)) != keccak256(abi.encode(URI6))
      && keccak256(abi.encode(URI4)) != keccak256(abi.encode(URI7))
      && keccak256(abi.encode(URI4)) != keccak256(abi.encode(URI8))
      && keccak256(abi.encode(URI4)) != keccak256(abi.encode(URI9))
      && keccak256(abi.encode(URI4)) != keccak256(abi.encode(URI10))
      , "Fail Random"
    );
    require(
      keccak256(abi.encode(URI5)) != keccak256(abi.encode(URI2))
      && keccak256(abi.encode(URI5)) != keccak256(abi.encode(URI3))
      && keccak256(abi.encode(URI5)) != keccak256(abi.encode(URI4))
      && keccak256(abi.encode(URI5)) != keccak256(abi.encode(URI1))
      && keccak256(abi.encode(URI5)) != keccak256(abi.encode(URI6))
      && keccak256(abi.encode(URI5)) != keccak256(abi.encode(URI7))
      && keccak256(abi.encode(URI5)) != keccak256(abi.encode(URI8))
      && keccak256(abi.encode(URI5)) != keccak256(abi.encode(URI9))
      && keccak256(abi.encode(URI5)) != keccak256(abi.encode(URI10))
      , "Fail Random"
    );
    require(
      keccak256(abi.encode(URI6)) != keccak256(abi.encode(URI2))
      && keccak256(abi.encode(URI6)) != keccak256(abi.encode(URI3))
      && keccak256(abi.encode(URI6)) != keccak256(abi.encode(URI4))
      && keccak256(abi.encode(URI6)) != keccak256(abi.encode(URI5))
      && keccak256(abi.encode(URI6)) != keccak256(abi.encode(URI1))
      && keccak256(abi.encode(URI6)) != keccak256(abi.encode(URI7))
      && keccak256(abi.encode(URI6)) != keccak256(abi.encode(URI8))
      && keccak256(abi.encode(URI6)) != keccak256(abi.encode(URI9))
      && keccak256(abi.encode(URI6)) != keccak256(abi.encode(URI10))
      , "Fail Random"
    );
    require(
      keccak256(abi.encode(URI7)) != keccak256(abi.encode(URI2))
      && keccak256(abi.encode(URI7)) != keccak256(abi.encode(URI3))
      && keccak256(abi.encode(URI7)) != keccak256(abi.encode(URI4))
      && keccak256(abi.encode(URI7)) != keccak256(abi.encode(URI5))
      && keccak256(abi.encode(URI7)) != keccak256(abi.encode(URI6))
      && keccak256(abi.encode(URI7)) != keccak256(abi.encode(URI1))
      && keccak256(abi.encode(URI7)) != keccak256(abi.encode(URI8))
      && keccak256(abi.encode(URI7)) != keccak256(abi.encode(URI9))
      && keccak256(abi.encode(URI7)) != keccak256(abi.encode(URI10))
      , "Fail Random"
    );
    require(
      keccak256(abi.encode(URI8)) != keccak256(abi.encode(URI2))
      && keccak256(abi.encode(URI8)) != keccak256(abi.encode(URI3))
      && keccak256(abi.encode(URI8)) != keccak256(abi.encode(URI4))
      && keccak256(abi.encode(URI8)) != keccak256(abi.encode(URI5))
      && keccak256(abi.encode(URI8)) != keccak256(abi.encode(URI6))
      && keccak256(abi.encode(URI8)) != keccak256(abi.encode(URI7))
      && keccak256(abi.encode(URI8)) != keccak256(abi.encode(URI1))
      && keccak256(abi.encode(URI8)) != keccak256(abi.encode(URI9))
      && keccak256(abi.encode(URI8)) != keccak256(abi.encode(URI10))
      , "Fail Random"
    );
    require(
      keccak256(abi.encode(URI9)) != keccak256(abi.encode(URI2))
      && keccak256(abi.encode(URI9)) != keccak256(abi.encode(URI3))
      && keccak256(abi.encode(URI9)) != keccak256(abi.encode(URI4))
      && keccak256(abi.encode(URI9)) != keccak256(abi.encode(URI5))
      && keccak256(abi.encode(URI9)) != keccak256(abi.encode(URI6))
      && keccak256(abi.encode(URI9)) != keccak256(abi.encode(URI7))
      && keccak256(abi.encode(URI9)) != keccak256(abi.encode(URI8))
      && keccak256(abi.encode(URI9)) != keccak256(abi.encode(URI1))
      && keccak256(abi.encode(URI9)) != keccak256(abi.encode(URI10))
      , "Fail Random"
    );
    require(
      keccak256(abi.encode(URI10)) != keccak256(abi.encode(URI2))
      && keccak256(abi.encode(URI10)) != keccak256(abi.encode(URI3))
      && keccak256(abi.encode(URI10)) != keccak256(abi.encode(URI4))
      && keccak256(abi.encode(URI10)) != keccak256(abi.encode(URI5))
      && keccak256(abi.encode(URI10)) != keccak256(abi.encode(URI6))
      && keccak256(abi.encode(URI10)) != keccak256(abi.encode(URI7))
      && keccak256(abi.encode(URI10)) != keccak256(abi.encode(URI8))
      && keccak256(abi.encode(URI10)) != keccak256(abi.encode(URI9))
      && keccak256(abi.encode(URI10)) != keccak256(abi.encode(URI1))
      , "Fail Random"
    );
  }

  function testWhitelistMintFailWithAnotherContractSignature() public {
    mintUpNft.setPhase(Phase.whitelistMint);
    vm.warp(block.timestamp + 101);
    bytes memory sign = signMessage(address(mintUpNftRandom), user1, 2, Phase.whitelistMint);
    vm.stopPrank();
    vm.startPrank(user1);
    vm.expectRevert(invalidSignature.selector);
    mintUpNft.whitelistMint(user1, 2, 2, sign);
  }

  function testWhitelistMintAllSupply() public {
    mintUpNft.setPhase(Phase.whitelistMint);
    vm.warp(block.timestamp + 101);
    bytes memory sign = signMessage(address(mintUpNft), user1, 100, Phase.whitelistMint);
    vm.stopPrank();
    vm.startPrank(user1);
    vm.deal(user1, 100 ether);
    mintUpNft.whitelistMint{ value: initETH.whitelistPrice * 100 }(user1, 100, 100, sign);
    uint256 balanceAfter = mintUpNft.balanceOf(user1);
    require(balanceAfter == 100, "fail mint all supply");
  }

  function testWhitelistMintWithUser1BuyForUser2() public {
    mintUpNft.setPhase(Phase.whitelistMint);
    vm.warp(block.timestamp + 101);
    bytes memory sign = signMessage(address(mintUpNft), user2, 2, Phase.whitelistMint);
    vm.stopPrank();
    vm.startPrank(user1);
    vm.deal(user1, 100 ether);
    mintUpNft.whitelistMint{ value: initETH.whitelistPrice * 2 }(user2, 2, 2, sign);
    uint256 balanceAfter = mintUpNft.balanceOf(user2);
    require(balanceAfter == 2, "fail mint for another account");
  }

  function testWhitelistMintFailExceedMaxSupply() public {
    mintUpNft.setPhase(Phase.whitelistMint);
    vm.warp(block.timestamp + 101);
    bytes memory sign = signMessage(address(mintUpNft), user1, 101, Phase.whitelistMint);
    vm.stopPrank();
    vm.startPrank(user1);
    vm.deal(user1, 100 ether);
    vm.expectRevert(maxSupplyReach.selector);
    mintUpNft.whitelistMint{ value: initETH.whitelistPrice * 101 }(user1, 101, 101, sign);
  }

  // PUBLICMINT
  function testPublicMint() public {
    mintUpNft.setPhase(Phase.publicMint);
    vm.warp(block.timestamp + 101);
    vm.stopPrank();
    vm.startPrank(user1);
    vm.deal(user1, 2 ether);
    mintUpNft.publicMint{ value: initETH.publicPrice * 2 }(user1, 2);
  }

  function testPublicMintFailInvalidAmountSend() public {
    mintUpNft.setPhase(Phase.publicMint);
    vm.warp(block.timestamp + 101);
    vm.stopPrank();
    vm.startPrank(user1);
    vm.deal(user1, 2 ether);
    vm.expectRevert(amountSendIncorrect.selector);
    mintUpNft.publicMint{ value: initETH.publicPrice }(user1, 2);
  }

  function testPublicMintFailAmountZero() public {
    mintUpNft.setPhase(Phase.publicMint);
    vm.warp(block.timestamp + 101);
    vm.stopPrank();
    vm.startPrank(user1);
    vm.deal(user1, 2 ether);
    vm.expectRevert(quantityZero.selector);
    mintUpNft.publicMint{ value: initETH.publicPrice }(user1, 0);
  }

  function testPublicMintFailExceedMaxPerWallet() public {
    mintUpNft.setPhase(Phase.publicMint);
    vm.warp(block.timestamp + 101);
    vm.stopPrank();
    vm.startPrank(user1);
    vm.deal(user1, 20 ether);
    vm.expectRevert(quantityExceed.selector);
    mintUpNft.publicMint{ value: initETH.publicPrice * 11 }(user1, 11);
  }

  function testPublicMintFailSaleEnded() public {
    mintUpNft.setPhase(Phase.publicMint);
    vm.warp(block.timestamp + 4 hours);
    vm.stopPrank();
    vm.startPrank(user1);
    vm.deal(user1, 20 ether);
    vm.expectRevert(saleEnded.selector);
    mintUpNft.publicMint{ value: initETH.publicPrice * 2 }(user1, 2);
  }

  function testPublicMintFailSaleNotStarted() public {
    mintUpNft.setPhase(Phase.publicMint);
    vm.stopPrank();
    vm.startPrank(user1);
    vm.deal(user1, 20 ether);
    vm.expectRevert(saleNotStarted.selector);
    mintUpNft.publicMint{ value: initETH.publicPrice * 2 }(user1, 2);
  }

  function testPublicMintUser1forUser2() public {
    mintUpNft.setPhase(Phase.publicMint);
    vm.warp(block.timestamp + 1 hours);
    vm.stopPrank();
    vm.startPrank(user1);
    vm.deal(user1, 20 ether);
    mintUpNft.publicMint{ value: initETH.publicPrice * 2 }(user2, 2);
    uint256 balanceAfter = mintUpNft.balanceOf(user2);
    require(balanceAfter == 2, "fail mint for user2 by user1");
  }
}
