// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

struct Initialisaser {
  string name;
  string symbol;
  string baseURI;
  address crossmintAddy;
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
}

enum Phase {
  notStarted,
  premint,
  whitelistMint,
  publicMint
}