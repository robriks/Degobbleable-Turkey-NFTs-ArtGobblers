// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import {Utilities} from "./utils/Utilities.sol";
import {console} from "./utils/Console.sol";
import {Vm} from "forge-std/Vm.sol";
import {stdError} from "forge-std/Test.sol";
import {ArtGobblers, FixedPointMathLib} from "../src/ArtGobblers.sol";
import {Goo} from "../src/Goo.sol";
import {Pages} from "../src/Pages.sol";
import {GobblerReserve} from "../src/utils/GobblerReserve.sol";
import {RandProvider} from "../src/utils/rand/RandProvider.sol";
import {ChainlinkV1RandProvider} from "../src/utils/rand/ChainlinkV1RandProvider.sol";
import {LinkToken} from "./utils/mocks/LinkToken.sol";
import {VRFCoordinatorMock} from "chainlink/v0.8/mocks/VRFCoordinatorMock.sol";
import {ERC721} from "solmate/tokens/ERC721.sol";
import {MockERC1155} from "solmate/test/utils/mocks/MockERC1155.sol";
import {LibString} from "solmate/utils/LibString.sol";
import {fromDaysWadUnsafe} from "solmate/utils/SignedWadMath.sol";

import {Turkeys} from "../src/Turkeys.sol";

contract TurkeyTest is DSTestPlus {
    using LibString for uint256;

    Vm internal immutable vm = Vm(HEVM_ADDRESS);

    Utilities internal utils;
    address payable[] internal users;

    ArtGobblers internal gobblers;
    VRFCoordinatorMock internal vrfCoordinator;
    LinkToken internal linkToken;
    Goo internal goo;
    Pages internal pages;
    GobblerReserve internal team;
    GobblerReserve internal community;
    RandProvider internal randProvider;

    Turkeys public turkeys;

    bytes32 private keyHash;
    uint256 private fee;

    uint256[] ids;

    
    // setup
    function setUp() public {
        utils = new Utilities();
        users = utils.createUsers(5);
        linkToken = new LinkToken();
        vrfCoordinator = new VRFCoordinatorMock(address(linkToken));

        //gobblers contract will be deployed after 4 contract deploys, and pages after 5
        address gobblerAddress = utils.predictContractAddress(address(this), 4);
        address pagesAddress = utils.predictContractAddress(address(this), 5);

        team = new GobblerReserve(ArtGobblers(gobblerAddress), address(this));
        community = new GobblerReserve(ArtGobblers(gobblerAddress), address(this));
        randProvider = new ChainlinkV1RandProvider(
            ArtGobblers(gobblerAddress),
            address(vrfCoordinator),
            address(linkToken),
            keyHash,
            fee
        );

        goo = new Goo(
            // Gobblers:
            utils.predictContractAddress(address(this), 1),
            // Pages:
            utils.predictContractAddress(address(this), 2)
        );

        gobblers = new ArtGobblers(
            keccak256(abi.encodePacked(users[0])),
            block.timestamp,
            goo,
            Pages(pagesAddress),
            address(team),
            address(community),
            randProvider,
            "base",
            ""
        );

        pages = new Pages(block.timestamp, goo, address(0xBEEF), gobblers, "");

        turkeys = new Turkeys(gobblers);
    }

    // test that ArtGobblers will support any ERC721, not just Pages NFTs
    function testGobbleTurkey() public {
        // mint a gobbler and a turkey to users[0]
        mintGobblerToAddress(users[0], 1);
        uint gobblersBalance = gobblers.balanceOf(users[0]);
        assertEq(gobblersBalance, 1);
        
        vm.prank(users[0]);
        turkeys.mintForTests();
        uint turkeysBalance = turkeys.balanceOf(users[0]);
        assertEq(turkeysBalance, 1);

        vm.prank(users[0]);
        turkeys.approve(address(gobblers), 1);
        vm.prank(users[0]);
        gobblers.gobble(1, address(turkeys), 1, false);
        address turkeyOwner = turkeys.ownerOf(1);
        assertEq(turkeyOwner, address(gobblers));
    }

    // test that TurkeyStruct is properly initialized when minted
    function testTurkeyStruct() public {
        // mint a gobbler and a turkey to users[0]
        mintGobblerToAddress(users[0], 1);
        uint gobblersBalance = gobblers.balanceOf(users[0]);
        assertEq(gobblersBalance, 1);
        
        vm.prank(users[0]);
        turkeys.mintForTests();
        uint turkeysBalance = turkeys.balanceOf(users[0]);
        assertEq(turkeysBalance, 1);

        uint associatedGobbler = turkeys.getAssociatedGobbler(1);
        bool gobbledStatus = turkeys.getGobbledStatus(1);
        uint[] memory cloneIds = turkeys.getTurkeyClones(1);
        assertEq(associatedGobbler, 1);
        assertTrue(!gobbledStatus);
        assertEq(cloneIds.length, 0);
    }

    // test that claim() function mints properly
    function testClaim() public {
        // mint a gobbler 
        uint gobblerId = 1;
        mintGobblerToAddress(users[0], gobblerId);
        uint gobblersBalance = gobblers.balanceOf(users[0]);
        assertEq(gobblersBalance, 1);
        
        // claim a turkey
        vm.prank(users[0]);
        turkeys.claim(gobblerId);
        uint turkeysBalance = turkeys.balanceOf(users[0]);
        assertEq(turkeysBalance, 1);
        uint turkeyId = 1;
        address turkeyOwner = turkeys.ownerOf(turkeyId);
        assertEq(turkeyOwner, users[0]);

        uint associatedGobbler = turkeys.getAssociatedGobbler(turkeyId);
        bool gobbledStatus = turkeys.getGobbledStatus(turkeyId);
        uint[] memory cloneIds = turkeys.getTurkeyClones(turkeyId);
        assertEq(associatedGobbler, gobblerId);
        assertTrue(!gobbledStatus);
        assertEq(cloneIds.length, 0);
    }

    // test that claim() function reverts when called by addresses that don't hold an Art Gobbler
    function testCannotClaim() public {
        // mint a gobbler 
        uint gobblerId = 1;
        mintGobblerToAddress(users[0], gobblerId);
        uint gobblersBalance = gobblers.balanceOf(users[0]);
        assertEq(gobblersBalance, 1);

        // claim a turkey from account without a gobbler
        vm.expectRevert("Only addresses with an Art Gobbler may claim.");
        vm.prank(users[1]);
        turkeys.claim(gobblerId);
    }

    // test that Turkeys.sol cook() function properly executes when a Turkey NFT is gobbled
    function testCookTurkey() public {
        // mint a gobbler and a turkey to users[0]
        mintGobblerToAddress(users[0], 1);
        uint gobblersBalance = gobblers.balanceOf(users[0]);
        assertEq(gobblersBalance, 1);
        
        vm.prank(users[0]);
        turkeys.mintForTests();
        uint turkeysBalance = turkeys.balanceOf(users[0]);
        assertEq(turkeysBalance, 1);

        // gobble the turkey
        vm.prank(users[0]);
        turkeys.approve(address(gobblers), 1);
        vm.prank(users[0]);
        gobblers.gobble(1, address(turkeys), 1, false);
        address turkeyOwner = turkeys.ownerOf(1);
        assertEq(turkeyOwner, address(gobblers));
    }

    // test that it is possible to de-gobble a Turkey nft using deCook() via deleting and reminting
    function testDeCookTurkey() public {
        // mint a gobbler and a turkey to users[0]
        mintGobblerToAddress(users[0], 1);
        uint gobblersBalance = gobblers.balanceOf(users[0]);
        assertEq(gobblersBalance, 1);
        
        vm.prank(users[0]);
        turkeys.mintForTests();
        uint turkeysBalance = turkeys.balanceOf(users[0]);
        assertEq(turkeysBalance, 1);

        // gobble the turkey
        vm.prank(users[0]);
        turkeys.approve(address(gobblers), 1);
        vm.prank(users[0]);
        gobblers.gobble(1, address(turkeys), 1, false);
        address turkeyOwner = turkeys.ownerOf(1);
        assertEq(turkeyOwner, address(gobblers));

        // check gobbled turkey status for comparison
        uint gobblerId = turkeys.getAssociatedGobbler(1);
        assertEq(gobblerId, 1);
        bool turkeyStatus = turkeys.getGobbledStatus(1);
        assertTrue(turkeyStatus);
        uint[] memory cloneIds = turkeys.getTurkeyClones(1);
        assertEq(cloneIds.length, 0);
        
        // de-gobble the turkey
        vm.prank(users[0]);
        turkeys.deCook(1);
        
        // check de-gobbled turkey status for comparison
        uint deGobblerId = turkeys.getAssociatedGobbler(1);
        assertEq(deGobblerId, 1);
        bool deGobbledTurkeyStatus = turkeys.getGobbledStatus(1);
        assertTrue(!deGobbledTurkeyStatus);
        uint[] memory deGobbledCloneIds = turkeys.getTurkeyClones(1);
        assertEq(deGobbledCloneIds.length, 1);

        // check clone-minted turkey
        // since it's a clone it's not given any struct attributes
        uint cloneBalance = turkeys.balanceOf(users[0]);
        assertEq(cloneBalance, 2);
        address cloneOwner = turkeys.ownerOf(10001);
        assertEq(cloneOwner, users[0]);
    }

    function testMultipleDeCooks() public {
        // mint a gobbler and a turkey to users[0]
        mintGobblerToAddress(users[0], 1);
        uint gobblersBalance = gobblers.balanceOf(users[0]);
        assertEq(gobblersBalance, 1);
        
        vm.prank(users[0]);
        turkeys.mintForTests();
        uint turkeysBalance = turkeys.balanceOf(users[0]);
        assertEq(turkeysBalance, 1);

        // gobble the turkey
        vm.prank(users[0]);
        turkeys.approve(address(gobblers), 1);
        vm.prank(users[0]);
        gobblers.gobble(1, address(turkeys), 1, false);
        address turkeyOwner = turkeys.ownerOf(1);
        assertEq(turkeyOwner, address(gobblers));

        // check gobbled turkey status for comparison
        uint gobblerId = turkeys.getAssociatedGobbler(1);
        assertEq(gobblerId, 1);
        bool turkeyStatus = turkeys.getGobbledStatus(1);
        assertTrue(turkeyStatus);
        uint[] memory cloneIds = turkeys.getTurkeyClones(1);
        assertEq(cloneIds.length, 0);
        
        // de-gobble the turkey
        vm.prank(users[0]);
        turkeys.deCook(1);
        
        // check de-gobbled turkey status for comparison
        uint deGobblerId = turkeys.getAssociatedGobbler(1);
        assertEq(deGobblerId, 1);
        bool deGobbledTurkeyStatus = turkeys.getGobbledStatus(1);
        assertTrue(!deGobbledTurkeyStatus);
        uint[] memory deGobbledCloneIds = turkeys.getTurkeyClones(1);
        assertEq(deGobbledCloneIds.length, 1);

        // check clone-minted turkey
        // since it's a clone it's not given any struct attributes
        uint balanceWithClone = turkeys.balanceOf(users[0]);
        assertEq(balanceWithClone, 2);
        address cloneOwner = turkeys.ownerOf(10001);
        assertEq(cloneOwner, users[0]);

        // repeat entire process to test multiple gobble/degobbles
        // gobble the turkey a second time
        vm.prank(users[0]);
        turkeys.approve(address(gobblers), 1);
        vm.prank(users[0]);
        gobblers.gobble(1, address(turkeys), 1, false);
        address turkeyOwnerAgain = turkeys.ownerOf(1);
        assertEq(turkeyOwnerAgain, address(gobblers));

        // check gobbled turkey status for comparison a second time
        uint gobblerIdAgain = turkeys.getAssociatedGobbler(1);
        assertEq(gobblerIdAgain, 1);
        bool turkeyStatusAgain = turkeys.getGobbledStatus(1);
        assertTrue(turkeyStatusAgain);
        uint[] memory cloneIdsAgain = turkeys.getTurkeyClones(1);
        assertEq(cloneIdsAgain.length, 1);
        
        // de-gobble the turkey a second time
        vm.prank(users[0]);
        turkeys.deCook(1);
        
        // check de-gobbled turkey status for comparison a second time
        uint deGobblerIdAgain = turkeys.getAssociatedGobbler(1);
        assertEq(deGobblerIdAgain, 1);
        bool deGobbledTurkeyStatusAgain = turkeys.getGobbledStatus(1);
        assertTrue(!deGobbledTurkeyStatusAgain);
        uint[] memory deGobbledCloneIdsAgain = turkeys.getTurkeyClones(1);
        assertEq(deGobbledCloneIdsAgain.length, 2);

        // check clone-minted turkeys inside array
        // since it's a clone it's not given any struct attributes
        uint multipleCloneBalance = turkeys.balanceOf(users[0]);
        assertEq(multipleCloneBalance, 3);
        address cloneOwnerAgain = turkeys.ownerOf(10001);
        assertEq(cloneOwnerAgain, users[0]);
        address clone2Owner = turkeys.ownerOf(20001);
        assertEq(clone2Owner, users[0]);
    }



    /*//////////////////////////////////////////////////////////////
                                 HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Mint a number of gobblers to the given address
    function mintGobblerToAddress(address addr, uint256 num) internal {
        for (uint256 i = 0; i < num; i++) {
            vm.startPrank(address(gobblers));
            goo.mintForGobblers(addr, gobblers.gobblerPrice());
            vm.stopPrank();

            uint256 gobblersOwnedBefore = gobblers.balanceOf(addr);

            vm.prank(addr);
            gobblers.mintFromGoo(type(uint256).max, false);

            assertEq(gobblers.balanceOf(addr), gobblersOwnedBefore + 1);
        }
    }

    /// @notice Call back vrf with randomness and reveal gobblers.
    function setRandomnessAndReveal(uint256 numReveal, string memory seed) internal {
        bytes32 requestId = gobblers.requestRandomSeed();
        uint256 randomness = uint256(keccak256(abi.encodePacked(seed)));
        // call back from coordinator
        vrfCoordinator.callBackWithRandomness(requestId, randomness, address(randProvider));
        gobblers.revealGobblers(numReveal);
    }
}