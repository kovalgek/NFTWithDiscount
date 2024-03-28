// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// ERC20 reward token that can be minted by stacking contract.
contract ERC20Rewardable is ERC20, Ownable2Step {

    /// an address of account that can mint token.
    address public minter;

    error ErrorNotMinter();

    /// @param name_ the name of the token.
    /// @param symbol_ the symbol of the token.
    /// @param owner_ the address of the token owner.
    constructor(
        string memory name_,
        string memory symbol_,
        address owner_
    ) ERC20(name_, symbol_) Ownable(owner_) {}

    /// @dev minter setter
    /// @param minter_ minter address.
    function setMinter(address minter_) external onlyOwner {
        minter = minter_;
    }

    /// @dev mints value_ amount of token for to_.
    /// @param to_ an address that token is mint for.
    /// @param value_ amount of token to be minted.
    function mint(address to_, uint256 value_) external {
        if (msg.sender != minter) {
            revert ErrorNotMinter();
        }
        _mint(to_, value_);
    }
}
