// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title Crowdfund
/// @notice All-or-nothing USDC crowdfunding for Arc Testnet (chain ID 5042002).
/// @dev Amounts are USDC base units. Backers must approve this contract before pledging.
///      There is no owner, administrator, or privileged token recovery mechanism.
contract Crowdfund is ReentrancyGuard {
    using SafeERC20 for IERC20;

    address public constant USDC_ADDRESS = 0x3600000000000000000000000000000000000000;
    IERC20 public constant usdc = IERC20(USDC_ADDRESS);

    enum Status {
        Active,
        Succeeded,
        Withdrawn,
        Failed,
        Cancelled
    }

    struct Campaign {
        uint256 id;
        address creator;
        address beneficiary;
        string title;
        string description;
        uint256 goal;
        uint256 deadline;
        uint256 raised;
        uint256 refunded;
        bool withdrawn;
        bool cancelled;
    }

    Campaign[] private _campaigns;
    mapping(uint256 => mapping(address => uint256)) private _pledged;
    mapping(address => uint256[]) private _campaignsByCreator;
    mapping(address => uint256[]) private _backedBy;

    event CampaignCreated(
        uint256 indexed id,
        address indexed creator,
        address indexed beneficiary,
        uint256 goal,
        uint256 deadline
    );
    event Pledged(uint256 indexed id, address indexed backer, uint256 amount);
    event FundsWithdrawn(uint256 indexed id, address indexed beneficiary, uint256 amount);
    event Refunded(uint256 indexed id, address indexed backer, uint256 amount);
    event CampaignCancelled(uint256 indexed id);
    event BeneficiaryUpdated(uint256 indexed id, address newBeneficiary);

    function createCampaign(
        string calldata title,
        string calldata description,
        uint256 goal,
        uint256 duration,
        address beneficiary
    ) external nonReentrant returns (uint256 id) {
        require(goal > 0, "Goal is zero");
        require(duration >= 1 hours && duration <= 90 days, "Invalid duration");
        require(bytes(title).length > 0 && bytes(title).length <= 100, "Invalid title length");
        require(bytes(description).length <= 1000, "Description too long");
        _validateBeneficiary(beneficiary);

        id = _campaigns.length;
        uint256 deadline = block.timestamp + duration;
        _campaigns.push(
            Campaign({
                id: id,
                creator: msg.sender,
                beneficiary: beneficiary,
                title: title,
                description: description,
                goal: goal,
                deadline: deadline,
                raised: 0,
                refunded: 0,
                withdrawn: false,
                cancelled: false
            })
        );
        _campaignsByCreator[msg.sender].push(id);

        emit CampaignCreated(id, msg.sender, beneficiary, goal, deadline);
    }

    function pledge(uint256 id, uint256 amount) external nonReentrant {
        Campaign storage campaign = _getCampaign(id);
        require(!campaign.cancelled, "Campaign cancelled");
        require(block.timestamp < campaign.deadline, "Campaign ended");
        require(amount > 0, "Amount is zero");

        // Refunds are only available after pledging has permanently closed, so
        // a zero balance here identifies a backer's first pledge to this campaign.
        if (_pledged[id][msg.sender] == 0) {
            _backedBy[msg.sender].push(id);
        }
        _pledged[id][msg.sender] += amount;
        campaign.raised += amount;

        emit Pledged(id, msg.sender, amount);
        usdc.safeTransferFrom(msg.sender, address(this), amount);
    }

    /// @notice Anyone may trigger payment; only the campaign beneficiary receives it.
    function withdrawFunds(uint256 id) external nonReentrant {
        Campaign storage campaign = _getCampaign(id);
        require(!campaign.cancelled, "Campaign cancelled");
        require(!campaign.withdrawn, "Funds already withdrawn");
        require(block.timestamp >= campaign.deadline, "Campaign still active");
        require(campaign.raised >= campaign.goal, "Goal not reached");

        campaign.withdrawn = true;
        address beneficiary = campaign.beneficiary;
        uint256 amount = campaign.raised;

        emit FundsWithdrawn(id, beneficiary, amount);
        usdc.safeTransfer(beneficiary, amount);
    }

    /// @notice The creator may change the beneficiary at any time before withdrawal.
    function updateBeneficiary(uint256 id, address newBeneficiary) external nonReentrant {
        Campaign storage campaign = _getCampaign(id);
        require(msg.sender == campaign.creator, "Not campaign creator");
        require(!campaign.withdrawn, "Funds already withdrawn");
        _validateBeneficiary(newBeneficiary);

        campaign.beneficiary = newBeneficiary;
        emit BeneficiaryUpdated(id, newBeneficiary);
    }

    function refund(uint256 id) external nonReentrant {
        Campaign storage campaign = _getCampaign(id);
        require(
            campaign.cancelled || (block.timestamp >= campaign.deadline && campaign.raised < campaign.goal),
            "Refund unavailable"
        );
        uint256 amount = _pledged[id][msg.sender];
        require(amount > 0, "Nothing to refund");

        _pledged[id][msg.sender] = 0;
        campaign.refunded += amount;
        // raised is the historical total and must never decrease on refunds.

        emit Refunded(id, msg.sender, amount);
        usdc.safeTransfer(msg.sender, amount);
    }

    function cancelCampaign(uint256 id) external nonReentrant {
        Campaign storage campaign = _getCampaign(id);
        require(msg.sender == campaign.creator, "Not campaign creator");
        require(block.timestamp < campaign.deadline, "Campaign ended");
        require(!campaign.cancelled, "Campaign already cancelled");
        require(!campaign.withdrawn, "Funds already withdrawn");

        campaign.cancelled = true;
        emit CampaignCancelled(id);
    }

    function getCampaign(uint256 id) external view returns (Campaign memory) {
        return _getCampaign(id);
    }

    function campaignCount() external view returns (uint256) {
        return _campaigns.length;
    }

    function pledgeOf(uint256 id, address user) external view returns (uint256) {
        _getCampaign(id);
        return _pledged[id][user];
    }

    function statusOf(uint256 id) external view returns (Status) {
        Campaign storage campaign = _getCampaign(id);
        if (campaign.cancelled) return Status.Cancelled;
        if (campaign.withdrawn) return Status.Withdrawn;
        if (block.timestamp < campaign.deadline) return Status.Active;
        if (campaign.raised >= campaign.goal) return Status.Succeeded;
        return Status.Failed;
    }

    function campaignsByCreator(address creator) external view returns (uint256[] memory) {
        return _campaignsByCreator[creator];
    }

    function backedBy(address backer) external view returns (uint256[] memory) {
        return _backedBy[backer];
    }

    function _getCampaign(uint256 id) private view returns (Campaign storage campaign) {
        require(id < _campaigns.length, "Invalid campaign id");
        return _campaigns[id];
    }

    function _validateBeneficiary(address beneficiary) private view {
        require(beneficiary != address(0), "Beneficiary is zero");
        require(beneficiary != address(this), "Beneficiary is crowdfund");
        require(beneficiary != USDC_ADDRESS, "Beneficiary is USDC");
        require(uint160(beneficiary) >= 0x10000, "Beneficiary in reserved range");
    }
}
