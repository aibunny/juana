// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Context.sol";

interface IERC5484 {

    //Both juana(Issuer) and user can allow burning the tokens
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
contract juanaContract is ERC721, Ownable, IERC5484 {
    struct KYCDetails{
        BurnAuth burnAuth;
        bytes32 kycHash; // hash referencing the ipfs record of the kyc data
        uint256 kycTimestamp;  // tracks when kyc was done
        bool isVerified; // tracks if the kyc is verified
    }

    mapping(uint256 => KYCDetails) private _kycDetails;



    constructor() ERC721("JuanaKYCsbt", "jSBT") {}

    // allows minting to recipient wallet address, unique id for the token
    // and the burn authorization for the token
    // it should allow burning at users request but
    // only the issuer can initiate it.
    function mintKYC(
        address to,
        uint256 tokenId,
        BurnAuth burnAuth,
        bytes32 kycHash,
        bool isVerified
    ) external onlyOwner {
        require(isVerified, "KYC must be verified"); // kyc must be verified
        // kyc hash must be valid
        // TODO: add a check to verify the kyc hash offchain some oracle maybe
        require(kycHash != bytes32(0), "Invalid kyc hash");


        // only the issuer can allow minting
        _mint(to, tokenId);
        _kycDetails[tokenId] = KYCDetails(
            burnAuth,
            kycHash,
            block.number,
            isVerified
            );

        emit Issued(msg.sender, to, tokenId, auth);
    }


    function burnAuth(uint256 tokenId) external view override returns (BurnAuth){
        require(_exists(tokenId), "Token does not exist");
        return _kycDetails[tokenId].burnAuth;
    }

    function burn(uint256 tokenId) external {
        require(_exists(tokenId), "Token does not exist");

        // check if the burn conditions are met
        BurnAuth auth = _kycDetails[tokenId].burnAuth;

        if (auth == BurnAuth.IssuerOnly) {
            require(msg.sender == owner(), "Only issuer can burn");
        } else if (auth == BurnAuth.OwnerOnly) {
            require(ownerOf(tokenId) == msg.sender, "Only owner can burn");
        } else if (auth == BurnAuth.Both) {
            require(msg.sender == owner() || ownerOf(tokenId) == msg.sender, "Only owner or issuer can burn");
        }else if (auth == BurnAuth.Neither) {
            require(false, "This token is not burnable");
        }
        _burn(tokenId);

        delete _kycDetails[tokenId]; //clean up
    }

    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal pure override {
        revert("Transfers of juana soulbound token disabled");
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) internal pure override {
        revert("Transfers of juana soulbound token disabled");
    }

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) internal pure override {
        revert("Transfers of juana soulbound token disabled");
    }


    function hasValidKYC(address account) external view returns (bool) {
        // check if the account has a valid kyc
        uint256 balance = balanceOf(account);
        if (balance == 0)  return false;

        uint256 tokenId = tokenOfOwnerByIndex(account, 0);

        return _kycDetails[tokenId].isVerified;
    }

    // get the kyc details for the account incase
    //the requesting party needs more information
    function getKyCDetailByAddress(
        address account
        ) external view returns (KYCDetails memory) {
        uint256 balance = balanceOf(account);
        if (balance == 0)  return KYCDetails(BurnAuth.Neither, bytes32(0), 0, false);

        uint256 tokenId = tokenOfOwnerByIndex(account, 0);
        return _kycDetails[tokenId];
    }

    // verify the token actually exists
    function isTokenValid(uint256 tokenId) external view returns (bool) {
        if(!_exists(tokenId)) return false;
        return true;
    }

}
