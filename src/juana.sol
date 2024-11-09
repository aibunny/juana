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

    function mintKYC(
        address to,
        uint256 tokenId,
        BurnAuth burnAuthorization,
        bytes32 kycHash,
        bool isVerified
    ) external onlyOwner {
        require(isVerified, "KYC must be verified");
        require(kycHash != bytes32(0), "Invalid KYC hash");

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
        delete _kycDetails[tokenId];
    }

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public override(ERC721, IERC721) {
        revert("Transfers of juana soulbound token disabled");
    }

    // function safeTransferFrom(
    //     address from,
    //     address to,
    //     uint256 tokenId
    // ) public override(ERC721, IERC721) {
    //     revert("Transfers of juana soulbound token disabled");
    // }

    // function safeTransferFrom(
    //     address from,
    //     address to,
    //     uint256 tokenId,
    //     bytes memory data
    // ) public override(ERC721, IERC721) {
    //     revert("Transfers of juana soulbound token disabled");
    // }

    function hasValidKYC(address account) external view returns (bool) {
        uint256 balance = balanceOf(account);
        if (balance == 0) return false;

        uint256 tokenId = tokenOfOwnerByIndex(account, 0);
        return _kycDetails[tokenId].isVerified;
    }

    function getKYCDetailByAddress(address account) public view returns (KYCDetails memory) {
        uint256 balance = balanceOf(account);
        if (balance == 0) return KYCDetails(BurnAuth.Neither, bytes32(0), 0, false);

        uint256 tokenId = tokenOfOwnerByIndex(account, 0);
        return _kycDetails[tokenId];
    }

    function isTokenValid(uint256 tokenId) external view returns (bool) {
        return exists(tokenId);
    }
}
