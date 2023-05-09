// SPDX-License-Identifier: Mit
pragma solidity ^0.8.19;

// import "lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "lib/openzeppelin-contracts/contracts/token/common/ERC2981.sol";
import "lib/ERC721A/contracts/ERC721A.sol";

import { Initialisaser, Phase } from "./Interfaces/IMintUpNft.sol";
import { ERC20Payement } from "./PaymentMethod/ERC20Payment.sol";
import { IERC20 } from "./PaymentMethod/IERC20.sol";
import { Verification } from "./Verification/Verification.sol";
import "./Error/Error.sol";

/**
 * @notice ERC721A with royalties and pseudo random URI
 * @author chixx.eth
 */
contract MintUpNft is ERC721A, ERC2981, Ownable, ERC20Payement {
  address public crossmintAddy;
  address public signer;
  address public mintUp;

  string public baseURI;

  uint256 public maxSupply;
  uint256 public maxPerAddress;
  uint256 public mintUpPart; // 100 => 1%
  uint256 public publicPrice;
  uint256 public whitelistPrice;
  uint256 public saleTimeStarts;
  uint256 public saleTimeEnds;
  uint256 public indexerLength;
  uint256 public currentSupply;

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
  mapping (address => uint256) public quantityPremint;
  mapping (address => uint256) public quantityWhitelist;
  mapping (address => uint256) public quantityPublic;

  /**
   * @dev mapping for tokenId and the URI
   */
  mapping(uint256 => uint256) public indexer;
  mapping(uint256 => uint256) public tokenIDMap;
  mapping(uint256 => uint256) public takenImages;

  event NewPhase(Phase newPhase);
  event NewPublicPrice(uint256 _newPublicPrice);
  event NewWhitelistPrice(uint256 _newWhitelistPrice);
  event Premint(address to, uint256 quantity);
  event WhitelistMint(address to, uint256 quantity);
  event PublicMint(address to, uint256 quantity);

  function supportsInterface(bytes4 interfaceId)
    public
    view
    virtual
    override(ERC2981, ERC721A)
    returns (bool)
  {
    return super.supportsInterface(interfaceId);
  }

  constructor(
    Initialisaser memory initParams
  ) 
    ERC721A(initParams.name, initParams.symbol)
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
    paymentMethod = initParams.paymentMethod;
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

  function _performPayment(uint256 _price) internal {
    if (paymentMethod) {
      if (msg.value > 0) {
        // if payment is set with ERC20 return eth send
        (bool success, ) = payable(msg.sender).call{value: msg.value}("");
        if (!success) revert failTransfer();
      }
      if (authorizedERC20 == address(0)) revert erc20NotSet();
      _ERC20Payment(msg.sender, address(this), _price);
    } else {
      if (msg.value < _price) revert amountSendIncorrect();
    }
  }

  // MINT FUNCTIONS
  /**
   * @notice mint function for the premint phase
   * @param _quantity the amount of nft to mint
   * @param _quantitySignature the amount of max nft can be mint in premint
   * @param _signature the signature for premint
   */
  function premint(uint256 _quantity, uint256 _quantitySignature, bytes memory _signature)
    external
    checkTime
    onlyPhase(Phase.premint)
    verify(msg.sender, _quantitySignature, currentPhase, _signature)
  {
    if (_quantity > _quantitySignature) revert quantityExceed();
    if (_quantity + quantityPremint[msg.sender] > _quantitySignature) revert quantityExceed();
    if (_quantity == 0) revert quantityZero();
    if (_nextTokenId() + _quantity > maxSupply) revert maxSupplyReach();

    if (random) {
      randomMint(msg.sender, _quantity);
    } else {
      sequentialMint(msg.sender, _quantity);
    }

    quantityPremint[msg.sender] += _quantity;
    emit Premint(msg.sender, _quantity);
  }

  function whitelistMint(
    address _to,
    uint256 _quantity,
    uint256 _quantitySignature,
    bytes memory _signature
  ) external
    payable
    checkTime
    onlyPhase(Phase.whitelistMint)
    verify(_to, _quantitySignature, currentPhase, _signature)
  {
    if (_quantity > _quantitySignature) revert quantityExceed();
    if (_quantity + quantityWhitelist[_to] > _quantitySignature) revert quantityExceed();
    if (_quantity == 0) revert quantityZero();
    if (_nextTokenId() + _quantity > maxSupply) revert maxSupplyReach();

    _performPayment(whitelistPrice);

    if (random) {
      randomMint(_to, _quantity);
    } else {
      sequentialMint(_to, _quantity);
    }

    quantityWhitelist[_to] += _quantity;
    emit WhitelistMint(_to, _quantity);
  }

  function publicMint(address _to, uint256 _quantity)
    external payable checkTime onlyPhase(Phase.publicMint)
  {
    if (_quantity == 0) revert quantityZero();
    if (_nextTokenId() + _quantity > maxSupply) revert maxSupplyReach();
    if (quantityPublic[_to] + _quantity > maxPerAddress) revert quantityExceed();

    _performPayment(publicPrice);

    if (random) {
      randomMint(_to, _quantity);
    } else {
      sequentialMint(_to, _quantity);
    }

    quantityPublic[_to] += _quantity;
    emit PublicMint(_to, _quantity);
  }

  /**
   * @notice perform sequential mint
   * @param _to address of the receiver
   * @param _quantity quantity receiver will receive
   */
  function sequentialMint(address _to, uint256 _quantity) internal {
    unchecked {
      for (uint256 i; i < _quantity; ++i) {
        uint256 nextId = _nextTokenId();
        takenImages[nextId + i] = 1;
        tokenIDMap[nextId + i] = nextId + i;
      }
    }
    _mint(_to, _quantity);
  }

  /**
   * @notice perform random mint
   * @param _to address of the receiver
   * @param _quantity quantity receiver will receive
   */
  function randomMint(address _to, uint256 _quantity) internal {
    unchecked {
      for (uint256 i; i < _quantity; ++i) {
        uint256 nextIndexerId = getRandom();
        uint256 nextImageID = getNextImageID(nextIndexerId);
        assert(takenImages[nextImageID] == 0);
        takenImages[nextImageID] = 1;
        tokenIDMap[_nextTokenId() + i] = nextImageID;
      }
    }
    _mint(_to, _quantity);
  }

  // PERFORM RANDOM
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

  function withdraw() external {
    address owner = owner();
    if (msg.sender != mintUp || msg.sender != owner) revert notAuthorized();
    if (paymentMethod) {
      uint256 _balance = IERC20(authorizedERC20).balanceOf(address(this));
      uint256 mintUpBalance = _balance * mintUpPart / 10000;
      _withdrawERC20(mintUp, mintUpBalance);
      _withdrawERC20(owner, _balance - mintUpBalance);
    } else {
      uint256 mintUpBalance = address(this).balance * mintUpPart / 10000;
      (bool success,) = payable(address(mintUp)).call{value: mintUpBalance}("");
      if (!success) revert failTransfer();
      (success, ) = payable(address(owner)).call{value: address(this).balance}("");
      if (!success) revert failTransfer();
    }
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
    if (receiver == address(0) && feeNumerator != 0) revert addressZero();
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

  function _startTokenId() internal override view virtual returns (uint256) {
    return 1;
  }

  function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
      uint256 imageID = tokenIDMap[tokenId];
      return (
        bytes(baseURI).length > 0
          ? string(abi.encodePacked(baseURI, _toString(imageID)))
          : ""
      );
  }
}