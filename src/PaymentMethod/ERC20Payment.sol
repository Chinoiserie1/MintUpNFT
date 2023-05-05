// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IERC20.sol";
import "lib/openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";
import "lib/openzeppelin-contracts/contracts/access/Ownable.sol";

/**
 * @notice contract for ERC20 Payment
 * @author chixx.eth
 */
contract ERC20Payement is Ownable {
  address public authorizedERC20;

  event AuthorizeNewERC20(address newAddress);
  event RejectAuthorizedERC20(address addressReject);

  /**
   * @notice add a new erc20
   * @dev only owner can call this method
   *      emit event { AuthorizeNewERC20 }
   */
  function addNewERC20(address newAddress) external onlyOwner {
    _authorizeNewERC20(newAddress);
  }

  /**
   * @notice internal function for authorize a new erc20
   */
  function _authorizeNewERC20(address newAddress) internal returns(bool) {
    authorizedERC20 = newAddress;
    emit AuthorizeNewERC20(newAddress);
    return true;
  }

  /**
   * @notice reject an authorized erc20
   * @dev only owner can call this method
   *      emit event { RejectAuthorizedERC20 }
   */
  function rejectERC20() external onlyOwner {
    _rejectAuthorizedERC20();
  }

  /**
   * @notice internal function for reject an authorized erc20
   */
  function _rejectAuthorizedERC20() internal {
    address mem = authorizedERC20;
    authorizedERC20 = address(0);
    emit RejectAuthorizedERC20(mem);
  }

  /**
   * @notice execute erc20 transfer
   * @dev internal function
   *      this contract must be approved before call _ERC20Payment 
   *      see { transferFrom } => erc20 standart
   *      return true or false if transfer done correctly
   */
  function _ERC20Payment(
    address from,
    address to,
    uint256 amount
  ) 
    internal returns(bool success)
  {
    success = IERC20(authorizedERC20).transferFrom(from, to, amount);
  }

  /**
   * @notice withdraw 
   * @dev internal function
   *      return true or false if transfer done correctly
   */
  function _withdrawERC20(
    address to,
    uint256 amount
  ) 
    internal returns(bool success)
  {
    uint256 balance = IERC20(authorizedERC20).balanceOf(address(this));
    require(balance != 0, "no token to withdraw");
    require(amount <= balance, "not enougth token to withdraw");
    success = IERC20(authorizedERC20).transfer(to, amount);
  }
}