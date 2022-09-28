// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import { ArtGobblers } from "./ArtGobblers.sol";
import { ERC721 } from "../lib/solmate/src/tokens/ERC721.sol";

contract Turkeys is ERC721 {

    // @notice The address of the ArtGobblers ERC721 token contract.
    ArtGobblers public immutable artGobblers;

    // @notice The baseURI strings where Turkey nft art is stored
    // @dev Currently just placeholders pending Turkey nft art
    string baseURI;

    // @notice Struct holding Gobbleable Turkey nft information
    struct Turkey {
        // Associated GobblerId since Turkeys are 1:1 soul-bonded to Gobblers
        uint256 gobblerId;
        // Gobbled status boolean to keep track of whether Turkey is currently gobbled
        bool isGobbled;
        // Array of TurkeyId uints that are clones of original Turkey, minted by deCook()ing
        uint[] cloneIds;
    }

    // @notice Mapping of TurkeyIds to their Turkey struct attributes
    // @dev Used to keep track of Turkey's associated Gobbler, gobbled status, and minted clones
    mapping (uint256 => Turkey) public turkeys;

    constructor(ArtGobblers _artGobblers) ERC721("Gobbleable Turkeys", "TURKEY") {
        artGobblers = _artGobblers;
        baseURI = "Hello";
    }

    // @notice Overrides the SolMate transferFrom() function to slightly modify it, 
    // adding the cook() hook function before the transfer in the style of OZ's _beforeTokenTransfer() hook
    // @notice This causes this contract's cook() hook to be called anytime a Turkey NFT is gobbled, since Art Gobblers calls transferFrom() in its gobble() function
    // @param Here id refers to the Turkey tokenId
    // @dev The function that calls into this, ArtGobbler's gobble() handles verification of the gobblerId so it's not needed
    function transferFrom(
        address from,
        address to,
        uint256 id
    ) public virtual override {
        if (to == address(artGobblers)) { 
            cook(from, id); 
        }
        super.transferFrom(from, to, id);
    }

    // @notice Function to claim a Gobbleable Turkey nft, provided claimer owns an Art Gobbler
    function claim(uint256 _gobblerId) external {
        // ensure that caller owns an Art Gobbler, the specified gobblerId
        require(artGobblers.ownerOf(_gobblerId) == msg.sender, "Only addresses with an Art Gobbler may claim.");
        require(balanceOf(msg.sender) == 0, "Only one Turkey NFT may be minted per Gobbler.");
        uint[] memory newArray = new uint[](0);
        turkeys[_gobblerId] = Turkey({
            gobblerId: _gobblerId,
            isGobbled: false,
            cloneIds: newArray
        });
        _mint(msg.sender, _gobblerId);
    }

    // @notice Hook function that is called before the inherited transferFrom() function from SolMate completes.
    // @notice This results in execution during any call to gobble() in the ArtGobblers contract, as it invokes transferFrom().
    // @notice Will feed a Turkey nft to a Gobbler, soul-bonding the Turkey to the Gobbler and giving a way to be un-gobbled.
    // @dev This function will only be called by the ArtGobblers address, by a user that owns both a Turkey and an Art Gobbler
    function cook(address from, uint256 turkeyId) internal returns (address) {
        // ensure that only original Turkey nft's can be gobbled
        require(turkeyId < 10000, "Clones may not be gobbled!");
        // this will revert if the specified TurkeyId has not yet been minted
        address turkeyOwner = ownerOf(turkeyId);
        // require tx.origin to own the specified TurkeyId
        require(from == turkeyOwner);
        // require specified TurkeyId to not currently be gobbled
        require(turkeys[turkeyId].isGobbled == false, "Turkey is currently gobbled");
        // set Turkey struct bool attribute
        turkeys[turkeyId].isGobbled = true;
        // provides approval to the ArtGobblers contract, provided all above checks pass; especially tx.origin bieng owner of turkeyId
        getApproved[turkeyId] == address(artGobblers);
    }

    // @notice Function to burn an already-gobbled GT turkey nft and reissue it, in essence un-gobbling it
    // @notice Gobble-deCook, get it? Haha. Nice.
    function deCook(uint256 turkeyId) external {
        Turkey memory turkey = turkeys[turkeyId];
        require(turkey.isGobbled == true, "Gobble that turkey first!");
        // since they are 1:1, gobblerId == turkeyId
        address gobblerOwner = artGobblers.ownerOf(turkeyId);
        require(msg.sender == gobblerOwner);

        // grab clone information from the Turkey to be deleted
        uint length = turkey.cloneIds.length;
        uint[] memory newArray = new uint[](length + 1);
        for (uint i; i < turkey.cloneIds.length; i++) {
            newArray[i] = turkey.cloneIds[i];
        }
        // clone Turkeys exceed maximum Art Gobblers supply to avoid collisions and prevent gobbling Turkey clones
        uint collisionPreventer = (length + 1) * 10000;
        uint newTurkeyClone = turkeyId + collisionPreventer;
        newArray[length] = newTurkeyClone;
        // delete the gobbled Turkey
        _burn(turkeyId);
        // remint the deleted Turkey
        turkeys[turkeyId] = Turkey({
            gobblerId: 1,
            isGobbled: false,
            cloneIds: newArray
        });
        _mint(msg.sender, turkeyId);
        // mint the cloned Turkey
        _mint(msg.sender, newTurkeyClone);
    }

    // /*
    // /// URI LOGIC ///
    // */

    // @notice Function to return tokenURI for Gobbleable Turkey NFT image
    // @notice Different tokenURI is returned when the GT turkey nft is gobbled or ungobbled
    // @dev Set to placeholders pending actual turkey art
    // @param baseURI is set in the constructor
    function tokenURI(uint256 turkeyId) public view override returns (string memory) {
        if (!turkeys[turkeyId].isGobbled) {
            return string.concat(baseURI, "Mars!");
        }
        if (turkeys[turkeyId].isGobbled) {
            return string.concat(baseURI, "World!");
        }
    }

    // /*
    // /// CONVENIENCE FUNCTIONS ///
    // */

    // @notice Function to return associated GobblerId given a TurkeyId
    function getAssociatedGobbler(uint256 _turkeyId) public view returns (uint256) {
        return turkeys[_turkeyId].gobblerId;
    }

    // @notice Function to return boolean gobbled status given a TurkeyId
    function getGobbledStatus(uint256 _turkeyId) public view returns (bool) {
        return turkeys[_turkeyId].isGobbled;
    }

    // @notice Function to return array of TurkeyIds for associated clones
    function getTurkeyClones(uint256 _turkeyId) public view returns (uint[] memory) {
        return turkeys[_turkeyId].cloneIds;
    }

    /*
    /// TEMPORARY FUNCTION FOR TESTING ///
    */
    // Uncomment the below function ONLY when running tests for convenience/speed
    function mintForTests() public {
        uint[] memory newArray = new uint[](0);
        turkeys[1] = Turkey({
            gobblerId: 1,
            isGobbled: false,
            cloneIds: newArray
        });
        _mint(msg.sender, 1);
    }
}