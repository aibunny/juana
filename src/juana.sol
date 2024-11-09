// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IERC5484 {
    // Both juana (Issuer) and user can allow burning the tokens
    enum BurnAuth {
        IssuerOnly,
        OwnerOnly,
        Both,
        Neither
    }

    event Issued(
        address indexed from,
        address indexed to,
        uint256 indexed tokenId,
        BurnAuth burnAuth
    );

    function burnAuth(uint256 tokenId) external view returns (BurnAuth);
}

// Juana is the soulBound token
contract juanaContract is ERC721Enumerable, Ownable, IERC5484 {
    struct KYCDetails {
        BurnAuth burnAuth;
        bytes32 kycHash; // hash referencing the IPFS record of the KYC data
        uint256 kycTimestamp; // tracks when KYC was done
        bool isVerified; // tracks if the KYC is verified
    }

    mapping(uint256 => KYCDetails) private _kycDetails;

    constructor() ERC721("JuanaKYCsbt", "jSBT") Ownable(msg.sender) {}

    function exists(uint256 tokenId) public view returns (bool) {
        return _kycDetails[tokenId].kycTimestamp != 0;
    }

    // allows minting to recipient wallet address, unique id for the token
    // and the burn authorization for the token
    // it should allow burning at users request but
    // only the issuer can initiate it
    function mintKYC(
        address to,
        uint256 tokenId,
        BurnAuth burnAuthorization,
        bytes32 kycHash,
        bool isVerified
    ) external onlyOwner {
        require(isVerified, "KYC must be verified");
        // kyc hash must be valid
        // TODO: add a check to verify the kyc hash offchain some oracle maybe
        require(kycHash != bytes32(0), "Invalid KYC hash");


        // only the iisuer can allow minting
        _mint(to, tokenId);
        _kycDetails[tokenId] = KYCDetails(
            burnAuthorization,
            kycHash,
            block.timestamp,
            isVerified
        );

        emit Issued(msg.sender, to, tokenId, burnAuthorization);
    }

    function burnAuth(uint256 tokenId) external view override returns (BurnAuth) {
        require(exists(tokenId), "Token does not exist");
        return _kycDetails[tokenId].burnAuth;
    }

    function burn(uint256 tokenId) external {
        require(exists(tokenId), "Token does not exist");

        // check if the burn conditions are met
        BurnAuth auth = _kycDetails[tokenId].burnAuth;

        if (auth == BurnAuth.IssuerOnly) {
            require(msg.sender == owner(), "Only issuer can burn");
        } else if (auth == BurnAuth.OwnerOnly) {
            require(ownerOf(tokenId) == msg.sender, "Only owner can burn");
        } else if (auth == BurnAuth.Both) {
            require(
                msg.sender == owner() || ownerOf(tokenId) == msg.sender,
                "Only owner or issuer can burn"
            );
        } else if (auth == BurnAuth.Neither) {
            revert("This token is not burnable");
        }

        _burn(tokenId);
        delete _kycDetails[tokenId]; //clean up
    }

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public override(ERC721, IERC721) {
        revert("Transfers of juana soulbound token disabled");
    }


    function _update(address from, address to, uint256 tokenId) internal virtual {
    // Allow minting (from == address(0)) and burning (to == address(0)), but revert for any other type of transfer
    if (from != address(0) && to != address(0)) {
        revert("Transfers are disabled, only minting and burning are allowed");
    }

    if (from == address(0)) {
        // Minting: implicitly handled by _mint()
    } else {
        // Burning: implicitly handled by _burn()
        require(ownerOf(tokenId) == from, "Invalid owner for burn");
    }

    if (to == address(0)) {
        // Burning: implicitly handled by _burn()
    } else {
        // Minting: implicitly handled by _mint()
        require(balanceOf(to) + 1 > balanceOf(to), "Overflow check failed");
    }

    // No need to manage _balances or _totalSupply as ERC721 handles this internally
    emit Transfer(from, to, tokenId);
}


    function hasValidKYC(address account) external view returns (bool) {
        // check if the account has a valid kyc
        uint256 balance = balanceOf(account);
        if (balance == 0) return false;

        uint256 tokenId = tokenOfOwnerByIndex(account, 0);
        return _kycDetails[tokenId].isVerified;
    }

    // get the kyc details for the account incase
    //the requesting party needs more information
    function getKYCDetailByAddress(address account) public view returns (KYCDetails memory) {
        uint256 balance = balanceOf(account);
        if (balance == 0) return KYCDetails(BurnAuth.Neither, bytes32(0), 0, false);

        uint256 tokenId = tokenOfOwnerByIndex(account, 0);
        return _kycDetails[tokenId];
    }

    // verify the token actually exists
    function isTokenValid(uint256 tokenId) external view returns (bool) {
        return exists(tokenId);
    }
}
