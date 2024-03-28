// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC721WithDiscount} from "./ERC721WithDiscount.sol";
import {ERC20Rewardable} from "./ERC20Rewardable.sol";

/// @author kovalgek
/// @notice Uses to stack NFT and receive rewardable token for that. 
contract Stacking is IERC721Receiver, Ownable2Step {

    struct StakedToken {
        address owner;
        uint96 lastClaimedAt;
    }

    /// @notice NFT token that user can stake.
    ERC721WithDiscount public immutable ERC721_WITH_DISCOUNT;

    /// @notice A token that user receive as a reward when he/she staked NFT.
    ERC20Rewardable public immutable ERC20_REWARDABLE;

    /// @notice How many token user can receive per day.
    uint256 public constant REWARDS_PER_DAY = 10;

    /// @notice staked tokens map.
    mapping(uint256 => StakedToken) internal _stakedTokens;

    event Withdrawn(address indexed account, uint256 indexed tokenId);
    event Staked(address indexed account, uint256 indexed tokenId);
    event RewardsClaimed(address indexed account, uint256 indexed tokenId, uint256 amount);

    error InvalidCaller();
    error NotTokenOwner(address owner, address caller);
    error TokenIsNotStaked(uint256 tokenId);
    error TokenIsStaked(uint256 tokenId);

    /// @dev Constructor function.
    /// @param erc721WithDiscount_ The address of the NFT token contract.
    /// @param erc20Rewardable_ The address of the reward token contract.
    /// @param owner_ An owner.
    constructor(
        address erc721WithDiscount_,
        address erc20Rewardable_,
        address owner_
    ) Ownable(owner_) {
        ERC721_WITH_DISCOUNT = ERC721WithDiscount(erc721WithDiscount_);
        ERC20_REWARDABLE = ERC20Rewardable(erc20Rewardable_);
    }
    
    /// @dev Stakes an NFT token
    /// @param tokenId The ID of the token to be staked
    function stake(uint256 tokenId) public {
        ERC721_WITH_DISCOUNT.safeTransferFrom(msg.sender, address(this), tokenId);
    }

    /// @dev Receives an ERC721 token and stakes it
    /// @param from The address from which the token is being transferred
    /// @param tokenId The ID of the token being transferred
    /// @return selector A bytes4 value indicating success or failure
    function onERC721Received(address, address from, uint256 tokenId, bytes calldata) public returns (bytes4) {
        if (msg.sender != address(ERC721_WITH_DISCOUNT)) {
            revert InvalidCaller();
        }

        assert(_stakedTokens[tokenId].owner == address(0));
        assert(ERC721_WITH_DISCOUNT.ownerOf(tokenId) == address(this));

        _stakedTokens[tokenId] = StakedToken(
            {
                owner: from,
                lastClaimedAt: uint96(block.timestamp)
            }
        );

        emit Staked(from, tokenId);

        return IERC721Receiver.onERC721Received.selector;
    }

    /// @dev Withdraws a staked token and claims any available rewards
    /// @param tokenId The ID of the token to be withdrawn
    function withdraw(uint256 tokenId) public {
        StakedToken memory token = _stakedTokens[tokenId];
        if (token.owner == address(0)) {
            revert TokenIsNotStaked(tokenId);
        }
        if (token.owner != msg.sender) {
            revert NotTokenOwner(token.owner, msg.sender);
        }

        _claimRewards(tokenId, token);
        delete _stakedTokens[tokenId];

        ERC721_WITH_DISCOUNT.safeTransferFrom(address(this), msg.sender, tokenId);
        emit Withdrawn(msg.sender, tokenId);
    }

    /// @dev Allows the contract owner to recover a non staked NFT token
    /// @param tokenId The ID of the token to be recovered
    /// @param to The address to which the token should be sent
    function recoverNFT(uint256 tokenId, address to) public onlyOwner {
        if (_stakedTokens[tokenId].owner != address(0)) {
            revert TokenIsStaked(tokenId);
        }
        ERC721_WITH_DISCOUNT.safeTransferFrom(address(this), to, tokenId);
    }

    /// @dev Returns the owner of a staked token
    /// @param tokenId The ID of the token
    /// @return owner The address of the token owner
    function ownerOf(uint256 tokenId) public view returns (address) {
        address owner = _stakedTokens[tokenId].owner;
        if (owner == address(0)) {
            revert TokenIsNotStaked(tokenId);
        }

        return owner;
    }
    
    /// @dev Checks if a token is staked
    /// @param tokenId The ID of the token to check
    /// @return result A boolean indicating whether the token is staked or not
    function isStaked(uint256 tokenId) public view returns (bool) {
        return _stakedTokens[tokenId].owner != address(0);
    }

    /// @dev Returns the amount of claimable rewards for a staked token
    /// @param tokenId The ID of the token
    /// @return amount The amount of claimable rewards
    function claimableRewards(uint256 tokenId) public view returns (uint256) {
        StakedToken memory token = _stakedTokens[tokenId];
        return _claimableRewards(tokenId, token);
    }

    /// @dev Claims the rewards for a staked token
    /// @param tokenId The ID of the token
    function claimRewards(uint256 tokenId) public {
        StakedToken memory token = _stakedTokens[tokenId];
        if (msg.sender != token.owner) {
            revert NotTokenOwner(token.owner, msg.sender);
        }
        _claimRewards(tokenId, token);
    }

    /// @param tokenId The ID of the token
    /// @dev Internal function to claim rewards for a specific token
    /// @param token The StakedToken struct representing the token
    /// @notice This function will revert if the token is not staked
    function _claimRewards(uint256 tokenId, StakedToken memory token) internal {
        uint256 rewards = _claimableRewards(tokenId, token);

        emit RewardsClaimed(token.owner, tokenId, rewards);
        if (rewards == 0) return;

        _stakedTokens[tokenId].lastClaimedAt = uint96(block.timestamp);
        ERC20_REWARDABLE.mint(token.owner, rewards);
    }
    
    /// @dev Internal function to calculate the claimable rewards for a specific token
    /// @param token The StakedToken struct representing the token
    /// @return rewards The amount of claimable rewards
    function _claimableRewards(uint256 tokenId, StakedToken memory token) internal view returns (uint256) {
        if (token.owner == address(0)) {
            revert TokenIsNotStaked(tokenId);
        }
        return (block.timestamp - token.lastClaimedAt) * REWARDS_PER_DAY / 1 days;
    }
}