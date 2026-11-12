// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {CrowdfundTestBase} from "./Crowdfund.Base.t.sol";
import {Crowdfund} from "../Crowdfund.sol";

contract CrowdfundCreateTest is CrowdfundTestBase {
    function test_CreateStoresCampaign() public {
        uint256 id = _create();
        assertEq(id, 0);
        assertEq(cf.campaignCount(), 1);
        Crowdfund.Campaign memory c = cf.getCampaign(0);
        assertEq(c.id, 0);
        assertEq(c.creator, creator);
        assertEq(c.beneficiary, bene);
        assertEq(c.title, "Title");
        assertEq(c.description, "Description");
        assertEq(c.goal, GOAL);
        assertEq(c.deadline, START + DURATION);
        assertEq(c.raised, 0);
        assertEq(c.refunded, 0);
        assertFalse(c.withdrawn);
        assertFalse(c.cancelled);
        assertEq(uint8(cf.statusOf(0)), uint8(Crowdfund.Status.Active));
    }

    function test_CreateEmitsEvent() public {
        vm.expectEmit(true, true, true, true, address(cf));
        emit CampaignCreated(0, creator, bene, GOAL, START + DURATION);
        _create();
    }

    function test_IdsIncrementAndCreatorIndex() public {
        uint256 a = _create();
        vm.prank(alice);
        uint256 b = cf.createCampaign("Other", "", 5, 1 hours, bene2);
        uint256 c = _create();
        assertEq(a, 0);
        assertEq(b, 1);
        assertEq(c, 2);
        assertEq(cf.campaignCount(), 3);

        uint256[] memory mine = cf.campaignsByCreator(creator);
        assertEq(mine.length, 2);
        assertEq(mine[0], 0);
        assertEq(mine[1], 2);
        uint256[] memory hers = cf.campaignsByCreator(alice);
        assertEq(hers.length, 1);
        assertEq(hers[0], 1);
        assertEq(cf.campaignsByCreator(stranger).length, 0);
    }

    function test_CreateAcceptsBoundaryValues() public {
        vm.startPrank(creator);
        cf.createCampaign(_str(1), "", 1, 1 hours, bene);
        cf.createCampaign(_str(100), _str(1000), 1, 90 days, address(uint160(0x10000)));
        vm.stopPrank();
        assertEq(cf.campaignCount(), 2);
        assertEq(cf.getCampaign(1).deadline, START + 90 days);
    }

    function test_RevertWhen_ZeroGoal() public {
        vm.expectRevert(bytes("Goal is zero"));
        vm.prank(creator);
        cf.createCampaign("T", "D", 0, DURATION, bene);
    }

    function test_RevertWhen_DurationTooShort() public {
        vm.expectRevert(bytes("Invalid duration"));
        vm.prank(creator);
        cf.createCampaign("T", "D", GOAL, 1 hours - 1, bene);
    }

    function test_RevertWhen_DurationTooLong() public {
        vm.expectRevert(bytes("Invalid duration"));
        vm.prank(creator);
        cf.createCampaign("T", "D", GOAL, 90 days + 1, bene);
    }

    function test_RevertWhen_ZeroDuration() public {
        vm.expectRevert(bytes("Invalid duration"));
        vm.prank(creator);
        cf.createCampaign("T", "D", GOAL, 0, bene);
    }

    function test_RevertWhen_EmptyTitle() public {
        vm.expectRevert(bytes("Invalid title length"));
        vm.prank(creator);
        cf.createCampaign("", "D", GOAL, DURATION, bene);
    }

    function test_RevertWhen_TitleTooLong() public {
        string memory t = _str(101);
        vm.expectRevert(bytes("Invalid title length"));
        vm.prank(creator);
        cf.createCampaign(t, "D", GOAL, DURATION, bene);
    }

    function test_RevertWhen_DescriptionTooLong() public {
        string memory d = _str(1001);
        vm.expectRevert(bytes("Description too long"));
        vm.prank(creator);
        cf.createCampaign("T", d, GOAL, DURATION, bene);
    }

    function test_RevertWhen_BeneficiaryZero() public {
        vm.expectRevert(bytes("Beneficiary is zero"));
        vm.prank(creator);
        cf.createCampaign("T", "D", GOAL, DURATION, address(0));
    }

    function test_RevertWhen_BeneficiaryIsCrowdfund() public {
        address self = address(cf);
        vm.expectRevert(bytes("Beneficiary is crowdfund"));
        vm.prank(creator);
        cf.createCampaign("T", "D", GOAL, DURATION, self);
    }

    function test_RevertWhen_BeneficiaryIsUsdc() public {
        vm.expectRevert(bytes("Beneficiary is USDC"));
        vm.prank(creator);
        cf.createCampaign("T", "D", GOAL, DURATION, USDC);
    }

    function test_RevertWhen_BeneficiaryReservedRange() public {
        vm.expectRevert(bytes("Beneficiary in reserved range"));
        vm.prank(creator);
        cf.createCampaign("T", "D", GOAL, DURATION, address(uint160(0xFFFF)));
    }

    function test_RevertWhen_BeneficiaryReservedRangeLow() public {
        vm.expectRevert(bytes("Beneficiary in reserved range"));
        vm.prank(creator);
        cf.createCampaign("T", "D", GOAL, DURATION, address(uint160(1)));
    }

    function test_GetCampaignRevertsOnUnknownId() public {
        vm.expectRevert(bytes("Invalid campaign id"));
        cf.getCampaign(0);
        _create();
        vm.expectRevert(bytes("Invalid campaign id"));
        cf.getCampaign(1);
    }
}
