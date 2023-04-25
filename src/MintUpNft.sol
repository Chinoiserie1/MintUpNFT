// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "lib/openzeppelin-contracts/contracts/token/common/ERC2981.sol";

import { Initialisaser, Phase } from "./Interfaces/IMintUpNft.sol";
import { ERC20Payement } from "./PaymentMethod/ERC20Payment.sol";
import { Verification } from "./Verification/Verification.sol";
import "./Error/Error.sol";

/**
 * @notice ERC721
 * @author chixx.eth aka jérémie Lucotte
 */
contract MintUpNft is ERC721, ERC2981, Ownable, ERC20Payement {
  address crossmintAddy;
  address signer;
  address mintUp;

  string baseURI;

  uint256 maxSupply;
  uint256 maxPerAddress;
  uint256 mintUpPart;
  uint256 publicPrice;
  uint256 whitelistPrice;
  uint256 saleTimeStarts;
  uint256 saleTimeEnds;
  uint256 indexerLength;
  uint256 currentSupply = 1;

  /**
   * @dev false => NativeToken
   *      true => ERC20Token
   */
  bool paymentMethod;
  /**
   * @dev false => sequential
   *      true => random
   */
  bool random;

  /**
   * @dev see { IMintUpNft.sol }
   */
  Phase currentPhase = Phase.notStarted;

  /**
   * @dev mapping for track how many mint an address done
   */
  mapping (address => uint256) amountPremint;
  mapping (address => uint256) amountWhitelis;
  mapping (address => uint256) amountPublic;

  /**
   * @dev mapping for tokenId and the URI
   */
  mapping(uint256 => uint256) indexer;
  mapping(uint256 => uint256) tokenIDMap;
  mapping(uint256 => uint256) takenImages;

  event NewPhase(Phase newPhase);
  event NewPublicPrice(uint256 _newPublicPrice);
  event NewWhitelistPrice(uint256 _newWhitelistPrice);
  event Premint(address to, uint256 amount);

  function supportsInterface(bytes4 interfaceId)
    public
    view
    virtual
    override(ERC2981, ERC721)
    returns (bool)
  {
    return super.supportsInterface(interfaceId);
  }

  constructor(
    Initialisaser memory initParams
  ) 
    ERC721(initParams.name, initParams.symbol)
  {
    baseURI = initParams.baseURI;
    crossmintAddy = initParams.crossmintAddy;
    signer = initParams.signer;
    mintUp = initParams.mintUp;
    saleTimeStarts = initParams.saleTimeStarts;
    saleTimeEnds = initParams.saleTimeEnds;
    maxSupply = initParams.maxSupply;
    publicPrice = initParams.publicPrice;
    maxPerAddress = initParams.maxPerAddress;
    mintUpPart = initParams.mintUpPart;
    random = initParams.random;
    unchecked {
      indexerLength = initParams.maxSupply + 1;
    }

    transferOwnership(initParams.owner);
    _setDefaultRoyalty(initParams.royaltiesRecipient, initParams.royaltiesAmount);
  }

  // MODIFIER
  /**
   * @notice modifier for checking the phase
   */
  modifier onlyPhase(Phase _phase) {
    if (currentPhase != _phase) revert incorectPhase();
    _;
  }

  /**
   * @notice modifier for checking if a mint can occur depending of the time start and the end
   */
  modifier checkTime() {
    if (block.timestamp < saleTimeStarts) revert saleNotStarted();
    if (block.timestamp > saleTimeEnds) revert saleEnded();
    _;
  }

  /**
   * @notice modifier for verify the signature
   * @param _to the address that mint
   * @param _amount the amount max can be claim
   * @param _phase the phase of the signature
   * @param _sign the signature
   */
  modifier verify(address _to, uint256 _amount, Phase _phase, bytes memory _sign) {
    if (!Verification.verifySignature(signer, _to, _amount, _phase, _sign)) revert invalidSignature();
    _;
  }

  // MINT FUNCTIONS
  /**
   * @notice mint function for the premint phase
   * @param amount the amount of nft to mint
   * @param amountSignature the amount of max nft can be mint in premint
   * @param signature the signature for premint
   */
  function premint(uint256 amount, uint256 amountSignature, bytes memory signature)
    external
    checkTime
    onlyPhase(Phase.premint)
    verify(msg.sender, amountSignature, currentPhase, signature)
  {
    if (amount > amountSignature) revert amountExceed();
    if (amount + amountPremint[msg.sender] > amountSignature) revert amountExceed();
    if (amount == 0) revert amountZero();

    

    amountPremint[msg.sender] += amount;
    emit Premint(msg.sender, amount);
  }

  function sequentialMint() internal {
    
  }

  /**
   * @dev get the correct next tokenId for the URI
   *      see { https://en.wikipedia.org/wiki/Fisher–Yates_shuffle }
   * @param index current supply
   */
  function getNextImageID(uint256 index) internal returns (uint256) {
    uint256 nextImageID = indexer[index];

    // if it's 0, means it hasn't been picked yet
    if (nextImageID == 0) {
      nextImageID = index;
    }
    // Swap last one with the picked one.
    // Last one can be a previously picked one as well, thats why we check
    if (indexer[indexerLength - 1] == 0) {
      indexer[index] = indexerLength - 1;
    } else {
      indexer[index] = indexer[indexerLength - 1];
    }
    indexerLength -= 1;
    return nextImageID;
  }

  /**
   * @dev compute the pseudo random value
   */
  function getRandom() internal view returns (uint256) {
    if (maxSupply - currentSupply == 0) return 0;
    uint256 computeRandom = uint256(
      keccak256(
        abi.encodePacked(
          indexerLength,
          block.prevrandao,
          block.timestamp,
          msg.sender,
          tx.gasprice,
          blockhash(block.number)
        )
      )
    ) % (indexerLength);

    return (computeRandom == 0 ? 1 : computeRandom);
  }

  // SETTER
  /**
   * @notice set the current phase
   * @param newPhase the new phase { IMintUpNft.sol }
   */
  function setPhase(Phase newPhase) external {
    currentPhase = newPhase;
    emit NewPhase(newPhase);
  }

  /**
   * @notice set default royalties
   * @param receiver address that recieve the royalties
   * @param feeNumerator percentage of royalties 100 = 1%
   */
  function setDefaultRoyalty(address receiver, uint96 feeNumerator)
    external
    onlyOwner
  {
    if (feeNumerator > 1000) revert royaltiesExceed10percent();
    _setDefaultRoyalty(receiver, feeNumerator);
  }

  /**
   * @notice set the new public price
   * @param _newPrice the new price for public mint
   */
  function setNewPublicPrice(uint256 _newPrice) external onlyOwner {
    publicPrice = _newPrice;
    emit NewPublicPrice(_newPrice);
  }

  /**
   * @notice set the new whitelistPrice
   * @param _newPrice the new price for public mint
   */
  function setWhitelistPrice(uint256 _newPrice) external onlyOwner {
    whitelistPrice = _newPrice;
    emit NewWhitelistPrice(_newPrice);
  }
}