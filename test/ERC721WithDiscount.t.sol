// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {ERC721WithDiscount} from "../src/ERC721WithDiscount.sol";

contract ERC721WithDiscountTest is Test {
    ERC721WithDiscount public erc721;

    address public owner = address(this);
    address public beneficiary = address(0x2E13E1);

    error ErrorMaxSupplyReached();
    
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);


    function setUp() public {
        erc721 = new ERC721WithDiscount("1","2",owner, "");
    }

    function test_InitialState() public {
        assertEq(erc721.MAX_TOTAL_SUPPLY(), 1000);
    }

    function test_MintMoreThanMaxSupply() public {
        uint256 maxSupply = erc721.MAX_TOTAL_SUPPLY();
        for (uint256 i = 0; i < maxSupply; ++i) {
            erc721.mint(beneficiary);
        }
        vm.expectRevert(abi.encodeWithSelector(ErrorMaxSupplyReached.selector));
        erc721.mint(beneficiary);
    }

    function test_MintSuccess() public {
        vm.expectEmit(address(erc721));
        emit Transfer(address(0), beneficiary, 0);
        uint256 tokenId = erc721.mint(beneficiary);
        assertEq(erc721.ownerOf(tokenId), beneficiary);
    }
}
