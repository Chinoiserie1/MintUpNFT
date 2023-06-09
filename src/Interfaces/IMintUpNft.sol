// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

struct Initialisaser {
  string name;
  string symbol;
  string baseURI;
  address owner;
  address signer;
  address mintUp;
  address royaltiesRecipient;
  uint256 maxSupply;
  uint256 publicPrice;
  uint256 whitelistPrice;
  uint256 saleTimeStarts;
  uint256 saleTimeEnds;
  uint256 mintUpPart;
  uint256 maxPerAddress;
  uint96 royaltiesAmount;
  bool random;
  bool paymentMethod;
}

enum Phase {
  notStarted,
  premint,
  whitelistMint,
  publicMint
}