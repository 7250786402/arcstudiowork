// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {BountyBoard} from "../BountyBoard.sol";
import {MockERC20} from "../test-helpers/MockERC20.sol";

abstract contract BountyBoardTestBase is Test {
    address internal constant USDC = 0x3600000000000000000000000000000000000000;

    BountyBoard internal bb;
    MockERC20 internal usdc;

    address internal owner = makeAddr("owner");
    address internal creator = makeAddr("creator");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal carol = makeAddr("carol");
    address internal tipper = makeAddr("tipper");
    address internal stranger = makeAddr("stranger");

    uint256 internal constant START = 1_700_000_000;
    uint256 internal constant REWARD = 500e6;
    uint256 internal constant FUNDS = 1_000_000e6;

    event BountyCreated(uint256 id, address creator, uint256 reward, string title);
    event WorkSubmitted(uint256 bountyId, address submitter, string note);
    event BountyClaimed(uint256 bountyId, address claimer, uint256 reward);
    event BountyCancelled(uint256 id);
    event EmergencyModeUpdated(bool enabled);
    event SubmissionWithdrawn(uint256 bountyId, address submitter);
    event WinnerTipped(uint256 bountyId, address tipper, address winner, uint256 amount);

    function setUp() public virtual {
        vm.warp(START);
        MockERC20 mock = new MockERC20();
        vm.etch(USDC, address(mock).code);
        usdc = MockERC20(USDC);

        bb = new BountyBoard(owner);

        address[5] memory users = [creator, alice, bob, carol, tipper];
        for (uint256 i = 0; i < users.length; i++) {
            usdc.mint(users[i], FUNDS);
            vm.prank(users[i]);
            usdc.approve(address(bb), type(uint256).max);
        }
    }

    // ---- helpers -------------------------------------------------------

    function _create() internal returns (uint256 id) {
        return _createWith(REWARD, 0, 0);
    }

    function _createWith(uint256 reward, uint256 deadline, uint8 bType) internal returns (uint256 id) {
        id = bb.getBounties().length;
        vm.prank(creator);
        bb.createBounty("Title", "Desc", reward, "tag1,tag2", deadline, "Criteria", bType, 8);
    }

    function _createWithDeadline(uint256 deadline) internal returns (uint256) {
        return _createWith(REWARD, deadline, 0);
    }

    function _submit(address who, uint256 id) internal {
        vm.prank(who);
        bb.submitWork(id, "my work");
    }

    function _approve(uint256 id, address claimer) internal {
        vm.prank(creator);
        bb.approveClaimer(id, claimer);
    }

    /// Open bounty with no deadline, alice approved => Claimed.
    function _createClaimed() internal returns (uint256 id) {
        id = _create();
        _submit(alice, id);
        _approve(id, alice);
    }

    function _bal(address a) internal view returns (uint256) {
        return usdc.balanceOf(a);
    }

    function _status(uint256 id) internal view returns (BountyBoard.BountyStatus) {
        return bb.getBounty(id).status;
    }

    function _subs(uint256 id) internal view returns (BountyBoard.Submission[] memory) {
        return bb.getSubmissions(id);
    }
}
