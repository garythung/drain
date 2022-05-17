// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "solmate/utils/SafeTransferLib.sol"; // imports ERC20

interface ERC721 {
    function safeTransferFrom(address from, address to, uint256 id) external;
}

interface ERC1155 {
    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes calldata) external;
}

contract Drain is Ownable {
    using SafeTransferLib for ERC20;

    // CONSTANTS //

    uint256 public constant PRICE = 420 wei;

    //* ADMIN *//

    /// @notice Retrieve Ether from the contract.
    /// @param _recipient Where to send the ether.
    function retrieveETH(address _recipient) external onlyOwner {
        SafeTransferLib.safeTransferETH(_recipient, address(this).balance);
    }

    /// @notice Retrieve ERC20 tokens from the contract.
    /// @param _recipient Where to send the tokens.
    /// @param _tokens Which tokens to retrieve.
    /// @param _amounts How many tokens to retrieve.
    function batchRetrieveERC20(
        address _recipient,
        address[] calldata _tokens,
        uint256[] calldata _amounts
    ) external onlyOwner {
        uint256 numContracts = _tokens.length;

        for (uint256 i = 0; i < numContracts;) {
            ERC20(_tokens[i]).safeTransfer(_recipient, _amounts[i]);
            unchecked { ++i; }
        }
    }

    /// @notice Retrieve ERC721 tokens from the contract.
    /// @param _recipient Where to send the tokens.
    /// @param _tokens Which token to retrieve.
    /// @param _ids Which token ID to retrieve.
    function batchRetrieveERC721(
        address _recipient,
        address[] calldata _tokens,
        uint256[] calldata _ids
    ) external onlyOwner {
        uint256 numContracts = _tokens.length;

        for (uint256 i = 0; i < numContracts;) {
            ERC721(_tokens[i]).safeTransferFrom(address(this), _recipient, _ids[i]);
            unchecked { ++i; }
        }
    }

    /// @notice Retrieve ERC1155 tokens from the contract.
    /// @param _recipient Where to send the tokens.
    /// @param _tokens Which token to retrieve.
    /// @param _ids Which token ID to retrieve.
    /// @param _amounts How many tokens to retrieve.
    function batchRetrieveERC1155(
        address _recipient,
        address[] calldata _tokens,
        uint256[] calldata _ids,
        uint256[] calldata _amounts
    ) external onlyOwner {
        uint256 numContracts = _tokens.length;

        for (uint256 i = 0; i < numContracts;) {
            ERC1155(_tokens[i]).safeTransferFrom(address(this), _recipient, _ids[i], _amounts[i], "");
            unchecked { ++i; }
        }
    }

    //* PUBLIC *//

    /// @notice Swap ERC20 tokens for 420 wei.
    /// @param _tokens Which tokens to swap.
    /// @param _amounts How many tokens to swap.
    function batchSwapERC20(
        address[] calldata _tokens,
        uint256[] calldata _amounts
    ) external {
        uint256 numContracts = _tokens.length;
        require(numContracts > 0, "MUST_SWAP_TOKENS");

        for (uint256 i = 0; i < numContracts;) {
            ERC20(_tokens[i]).safeTransferFrom(msg.sender, address(this), _amounts[i]);
            unchecked { ++i; }
        }

        SafeTransferLib.safeTransferETH(msg.sender, PRICE);
    }

    /// @notice Swap ERC721 tokens for 420 wei.
    /// @param _tokens Which tokens to swap.
    /// @param _ids Which token IDs to swap.
    function batchSwapERC721(
        address[] calldata _tokens,
        uint256[] calldata _ids
    ) external {
        uint256 numContracts = _tokens.length;
        require(numContracts > 0, "MUST_SWAP_TOKENS");

        for (uint256 i = 0; i < numContracts;) {
            ERC721(_tokens[i]).safeTransferFrom(msg.sender, address(this), _ids[i]);
            unchecked { ++i; }
        }

        SafeTransferLib.safeTransferETH(msg.sender, PRICE);
    }

    /// @notice Swap ERC1155 tokens for 420 wei.
    /// @param _tokens Which tokens to swap.
    /// @param _ids Which token IDs to swap.
    /// @param _amounts How many tokens to swap.
    function batchSwapERC1155(
        address[] calldata _tokens,
        uint256[] calldata _ids,
        uint256[] calldata _amounts
    ) external {
        uint256 numContracts = _tokens.length;
        require(numContracts > 0, "MUST_SWAP_TOKENS");

        for (uint256 i = 0; i < numContracts;) {
            ERC1155(_tokens[i]).safeTransferFrom(msg.sender, address(this), _ids[i], _amounts[i], "");
            unchecked { ++i; }
        }

        SafeTransferLib.safeTransferETH(msg.sender, PRICE);
    }

    //* ERC 721/1155 RECEIVERS *//

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    //* FALLBACK *//

    receive() external payable {}
}
