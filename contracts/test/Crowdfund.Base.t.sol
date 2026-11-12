// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Crowdfund} from "../Crowdfund.sol";
import {MockERC20} from "../test-helpers/MockERC20.sol";

abstract contract CrowdfundTestBase is Test {
    address internal constant USDC = 0x3600000000000000000000000000000000000000;

    Crowdfund internal cf;
    MockERC20 internal usdc;

    address internal creator = makeAddr("creator");
    address internal bene = makeAddr("bene");
    address internal bene2 = makeAddr("bene2");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal carol = makeAddr("carol");
    address internal stranger = makeAddr("stranger");

    uint256 internal constant GOAL = 1_000e6;
    uint256 internal constant DURATION = 7 days;
    uint256 internal constant START = 1_700_000_000;
    uint256 internal constant FUNDS = 1_000_000e6;

    event CampaignCreated(
        uint256 indexed id, address indexed creator, address indexed beneficiary, uint256 goal, uint256 deadline
    );
    event Pledged(uint256 indexed id, address indexed backer, uint256 amount);
    event FundsWithdrawn(uint256 indexed id, address indexed beneficiary, uint256 amount);
    event Refunded(uint256 indexed id, address indexed backer, uint256 amount);
    event CampaignCancelled(uint256 indexed id);
    event BeneficiaryUpdated(uint256 indexed id, address newBeneficiary);

    function setUp() public virtual {
        vm.warp(START);
        MockERC20 mock = new MockERC20();
        vm.etch(USDC, address(mock).code);
        usdc = MockERC20(USDC);

        cf = new Crowdfund();

        address[3] memory backers = [alice, bob, carol];
        for (uint256 i = 0; i < 3; i++) {
            usdc.mint(backers[i], FUNDS);
            vm.prank(backers[i]);
            usdc.approve(address(cf), type(uint256).max);
        }
    }

    // ---- helpers -------------------------------------------------------

    function _create() internal returns (uint256 id) {
        vm.prank(creator);
        id = cf.createCampaign("Title", "Description", GOAL, DURATION, bene);
    }

    function _pledge(address who, uint256 id, uint256 amount) internal {
        vm.prank(who);
        cf.pledge(id, amount);
    }

    function _deadline(uint256 id) internal view returns (uint256) {
        return cf.getCampaign(id).deadline;
    }

    /// Campaign that has reached goal (alice pledges GOAL), still active.
    function _createFunded() internal returns (uint256 id) {
        id = _create();
        _pledge(alice, id, GOAL);
    }

    /// Campaign with partial funding (alice 300, bob 200), still active.
    function _createPartial() internal returns (uint256 id) {
        id = _create();
        _pledge(alice, id, 300e6);
        _pledge(bob, id, 200e6);
    }

    function _bal(address a) internal view returns (uint256) {
        return usdc.balanceOf(a);
    }

    function _str(uint256 len) internal pure returns (string memory) {
        return string(new bytes(len)); // zero-bytes: valid for length checks
    }

    function _status(uint256 id) internal view returns (Crowdfund.Status) {
        return cf.statusOf(id);
    }
}
