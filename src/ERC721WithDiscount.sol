// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721Royalty} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Royalty.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {BitMaps} from "@openzeppelin/contracts/utils/structs/BitMaps.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

/// @author kovalgek
/// @notice NFT token with discount.
contract ERC721WithDiscount is ERC721Royalty, Ownable2Step {

    error ErrorMaxSupplyReached();
    error ErrorAlreadyClaimed();
    error ErrorInvalidProof();
    error ErrorPriceNotMatched(uint256, uint256);

    event TokenMintedWithDiscount(uint256 index, address indexed account);
    
    /// @notice price for normal users.
    uint256 public constant TOKEN_PRICE = 0.01 ether;

    /// @notice price for users who is in discount list.
    uint256 public constant TOKEN_PRICE_WITH_DISCOUNT = 0.001 ether;

    /// @notice maximum total supply of tokens.
    uint256 public constant MAX_TOTAL_SUPPLY = 1000;

    /// @notice merkle tree root for effective storing of accounts with discount.
    bytes32 public immutable DISCOUNT_ROOT_TREE;

    /// @notice token total supply. 
    uint256 private totalSupply;

    /// @notice bitmap structure for storing accounts that already claimed NFT with discount.
    BitMaps.BitMap private discountList;

    /// @param name_ the name of the token.
    /// @param symbol_ the symbol of the token.
    /// @param owner_ the address of the token owner.
    /// @param discountRootTree_ merkle tree root for effective storing of accounts with discount.
    constructor(
        string memory name_,
        string memory symbol_,
        address owner_,
        bytes32 discountRootTree_
    ) ERC721(name_, symbol_) Ownable(owner_) {
        DISCOUNT_ROOT_TREE = discountRootTree_;
        _setDefaultRoyalty(owner_, 250);
    }

    /// @notice mints token for to_ address with normal price.
    /// @param to_ an address token is minted for.
    function mint(address to_) external payable returns (uint256) {
        return _mintForPrice(TOKEN_PRICE);
    }

    /// @notice mints token for to_ address with noraml price.
    /// @param to_ an account to mint token for.
    /// @param index_ an offchain account index.
    /// @param merkleProof_ a path of nodes from index to the root.
    function mintWithDiscount(address to_, uint256 index_, bytes32[] calldata merkleProof_) external payable returns (uint256 tokenId) {
        _claimDiscount(to_, index_, merkleProof_);
        tokenId = _mintForPrice(TOKEN_PRICE_WITH_DISCOUNT);
        emit TokenMintedWithDiscount(index_, msg.sender);
    }

    /// @notice token total supply. 
    /// @param tokenPrice_ a price for token.
    function _mintForPrice(uint256 tokenPrice_) internal returns (uint256) {
        if (msg.value != tokenPrice_) {
            revert ErrorPriceNotMatched(tokenPrice_, msg.value);
        }
        uint256 tokenId = totalSupply;
        _safeMint(msg.sender, tokenId, "");
        return tokenId;
    }

    /// @inheritdoc ERC721
    function _safeMint(address to_, uint256 tokenId_, bytes memory data_) internal override {
        if (totalSupply >= MAX_TOTAL_SUPPLY) {
            revert ErrorMaxSupplyReached();
        }
        super._safeMint(to_, tokenId_, data_);
        totalSupply++;
    }

    /// @notice token total supply. 
    /// @param to_ an account to claim discount for.
    /// @param index_ an offchain account index.
    /// @param merkleProof_ a path of nodes from index to the root.
    function _claimDiscount(address to_, uint256 index_, bytes32[] calldata merkleProof_) internal {
        if (BitMaps.get(discountList, index_)) {
            revert ErrorAlreadyClaimed();
        }

        bytes32 node = keccak256(bytes.concat(keccak256(abi.encode(to_, index_))));
        if (!MerkleProof.verifyCalldata(merkleProof_, DISCOUNT_ROOT_TREE, node)) {
            revert ErrorInvalidProof();
        }

        BitMaps.set(discountList, index_);
    }
}
