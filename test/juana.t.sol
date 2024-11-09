// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/juana.sol";

contract JuanaContractTest is Test {
    juanaContract public juana;
    address public owner;
    address public user;
    bytes32 public constant MOCK_KYC_HASH = keccak256("mock_kyc_data");
    uint256 public constant TOKEN_ID = 1;

    function setUp() public {
        owner = address(this);
        user = address(0xBEEF);
        juana = new juanaContract();
    }

    function testInitialState() public {
        assertEq(juana.name(), "JuanaKYCsbt");
        assertEq(juana.symbol(), "jSBT");
        assertEq(juana.owner(), owner);
    }

    function testMintKYC() public {
        juana.mintKYC(user, TOKEN_ID, IERC5484.BurnAuth.Both, MOCK_KYC_HASH, true);

        assertEq(juana.ownerOf(TOKEN_ID), user);
        assertEq(uint256(juana.burnAuth(TOKEN_ID)), uint256(IERC5484.BurnAuth.Both));
        assertTrue(juana.hasValidKYC(user));
    }

    function testFailMintWithUnverifiedKYC() public {
        // This should revert due to unverified KYC
        juana.mintKYC(user, TOKEN_ID, IERC5484.BurnAuth.Both, MOCK_KYC_HASH, false);
    }

    function testFailMintWithInvalidKYCHash() public {
        // This should revert due to invalid KYC hash
        juana.mintKYC(user, TOKEN_ID, IERC5484.BurnAuth.Both, bytes32(0), true);
    }

    function testFailMintByNonOwner() public {
        // Only the owner can mint
        vm.prank(user);
        juana.mintKYC(user, TOKEN_ID, IERC5484.BurnAuth.Both, MOCK_KYC_HASH, true);
    }

    function testBurnByIssuer() public {
        juana.mintKYC(user, TOKEN_ID, IERC5484.BurnAuth.IssuerOnly, MOCK_KYC_HASH, true);
        juana.burn(TOKEN_ID);
        assertFalse(juana.isTokenValid(TOKEN_ID));
    }

    function testBurnByOwner() public {
        juana.mintKYC(user, TOKEN_ID, IERC5484.BurnAuth.OwnerOnly, MOCK_KYC_HASH, true);
        vm.prank(user);
        juana.burn(TOKEN_ID);
        assertFalse(juana.isTokenValid(TOKEN_ID));
    }

    function testFailBurnUnauthorized() public {
        juana.mintKYC(user, TOKEN_ID, IERC5484.BurnAuth.IssuerOnly, MOCK_KYC_HASH, true);
        vm.prank(user);
        // This should revert because the user is not authorized to burn
        juana.burn(TOKEN_ID);
    }

    function testFailBurnNonExistentToken() public {
        // This should revert because the token does not exist
        juana.burn(999);
    }

    function testFailTransferToken() public {
        juana.mintKYC(user, TOKEN_ID, IERC5484.BurnAuth.Both, MOCK_KYC_HASH, true);
        vm.prank(user);
        // This should revert because transfers are disabled
        juana.transferFrom(user, address(0xDEAD), TOKEN_ID);
    }

    function testGetKYCDetails() public {
        juana.mintKYC(user, TOKEN_ID, IERC5484.BurnAuth.Both, MOCK_KYC_HASH, true);

        juanaContract.KYCDetails memory details = juana.getKYCDetailByAddress(user);
        assertEq(uint256(details.burnAuth), uint256(IERC5484.BurnAuth.Both));
        assertEq(details.kycHash, MOCK_KYC_HASH);
        assertTrue(details.isVerified);
    }

    function testGetKYCDetailsForNonHolder() public {
        juanaContract.KYCDetails memory details = juana.getKYCDetailByAddress(address(0xDEAD));
        assertEq(uint256(details.burnAuth), uint256(IERC5484.BurnAuth.Neither));
        assertEq(details.kycHash, bytes32(0));
        assertEq(details.kycTimestamp, 0);
        assertFalse(details.isVerified);
    }

    function testIsTokenValid() public {
        assertFalse(juana.isTokenValid(TOKEN_ID));

        juana.mintKYC(user, TOKEN_ID, IERC5484.BurnAuth.Both, MOCK_KYC_HASH, true);
        assertTrue(juana.isTokenValid(TOKEN_ID));

        juana.burn(TOKEN_ID);
        assertFalse(juana.isTokenValid(TOKEN_ID));
    }
}
