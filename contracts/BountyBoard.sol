// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract BountyBoard is Ownable, ReentrancyGuard {
    IERC20 public immutable usdc;

    enum BountyStatus {
        Open,
        Claimed,
        Cancelled
    }

    struct Bounty {
        uint256 id;
        address creator;
        string title;
        string description;
        uint256 reward;
        BountyStatus status;
        address claimer;
        string tags;
        uint256 deadline;
        string acceptanceCriteria;
        uint8 bountyType;
        uint256 estimatedHours;
    }

    struct Submission {
        address submitter;
        string submissionNote;
        uint256 timestamp;
    }

    address public constant USDC_ADDRESS = 0x3600000000000000000000000000000000000000;

    Bounty[] private _bounties;
    mapping(uint256 => Submission[]) private _submissions;
    mapping(uint256 => mapping(address => bool)) private _hasSubmitted;

    mapping(address => uint256) public totalEarned;
    mapping(address => uint256) public bountiesWon;
    mapping(address => uint256) public bountiesCreated;

    bool public emergencyMode;

    event BountyCreated(uint256 id, address creator, uint256 reward, string title);
    event WorkSubmitted(uint256 bountyId, address submitter, string note);
    event BountyClaimed(uint256 bountyId, address claimer, uint256 reward);
    event BountyCancelled(uint256 id);
    event EmergencyModeUpdated(bool enabled);
    event SubmissionWithdrawn(uint256 bountyId, address submitter);
    event WinnerTipped(uint256 bountyId, address tipper, address winner, uint256 amount);

    modifier whenNotEmergency() {
        require(!emergencyMode, "Emergency mode active");
        _;
    }

    constructor(address initialOwner) Ownable(initialOwner) {
        require(initialOwner != address(0), "Initial owner is zero");
        usdc = IERC20(USDC_ADDRESS);
    }

    function setEmergencyMode(bool enabled) external onlyOwner {
        emergencyMode = enabled;
        emit EmergencyModeUpdated(enabled);
    }

    function createBounty(
        string memory title,
        string memory description,
        uint256 reward,
        string memory tags,
        uint256 deadline,
        string memory acceptanceCriteria,
        uint8 bountyType,
        uint256 estimatedHours
    ) external nonReentrant whenNotEmergency {
        require(reward > 0, "Reward must be > 0");
        require(deadline == 0 || deadline > block.timestamp, "Invalid deadline");
        require(bountyType <= 2, "Invalid bounty type");
        require(usdc.transferFrom(msg.sender, address(this), reward), "USDC transferFrom failed");

        uint256 bountyId = _bounties.length;

        _bounties.push(
            Bounty({
                id: bountyId,
                creator: msg.sender,
                title: title,
                description: description,
                reward: reward,
                status: BountyStatus.Open,
                claimer: address(0),
                tags: tags,
                deadline: deadline,
                acceptanceCriteria: acceptanceCriteria,
                bountyType: bountyType,
                estimatedHours: estimatedHours
            })
        );

        bountiesCreated[msg.sender] += 1;

        emit BountyCreated(bountyId, msg.sender, reward, title);
    }

    function submitWork(uint256 bountyId, string memory submissionNote) external whenNotEmergency {
        require(bountyId < _bounties.length, "Invalid bounty id");
        Bounty storage bounty = _bounties[bountyId];

        require(bounty.status == BountyStatus.Open, "Bounty not open");
        require(bounty.deadline == 0 || block.timestamp <= bounty.deadline, "Bounty deadline passed");
        require(!_hasSubmitted[bountyId][msg.sender], "Already submitted");

        _hasSubmitted[bountyId][msg.sender] = true;
        _submissions[bountyId].push(
            Submission({submitter: msg.sender, submissionNote: submissionNote, timestamp: block.timestamp})
        );

        emit WorkSubmitted(bountyId, msg.sender, submissionNote);
    }

    function withdrawSubmission(uint256 bountyId) external whenNotEmergency {
        require(bountyId < _bounties.length, "Invalid bounty id");
        Bounty storage bounty = _bounties[bountyId];
        require(bounty.status == BountyStatus.Open, "Bounty not open");
        require(_hasSubmitted[bountyId][msg.sender], "No submission found");

        Submission[] storage submissions = _submissions[bountyId];
        uint256 length = submissions.length;

        for (uint256 i = 0; i < length; i++) {
            if (submissions[i].submitter == msg.sender) {
                submissions[i] = submissions[length - 1];
                submissions.pop();
                _hasSubmitted[bountyId][msg.sender] = false;

                emit SubmissionWithdrawn(bountyId, msg.sender);
                return;
            }
        }

        revert("No submission found");
    }

    function approveClaimer(uint256 bountyId, address claimer) external nonReentrant whenNotEmergency {
        require(bountyId < _bounties.length, "Invalid bounty id");
        Bounty storage bounty = _bounties[bountyId];

        require(msg.sender == bounty.creator, "Not bounty creator");
        require(bounty.status == BountyStatus.Open, "Bounty not open");
        require(claimer != address(0), "Claimer is zero");
        require(_hasSubmitted[bountyId][claimer], "Claimer has no submission");

        try usdc.transfer(claimer, bounty.reward) returns (bool success) {
            require(success, "Winner address cannot receive USDC");
        } catch {
            revert("Winner address cannot receive USDC");
        }

        bounty.status = BountyStatus.Claimed;
        bounty.claimer = claimer;

        totalEarned[claimer] += bounty.reward;
        bountiesWon[claimer] += 1;

        emit BountyClaimed(bountyId, claimer, bounty.reward);
    }

    function tipWinner(uint256 bountyId, uint256 amount) external nonReentrant whenNotEmergency {
        require(bountyId < _bounties.length, "Invalid bounty id");
        require(amount > 0, "Amount must be > 0");

        Bounty storage bounty = _bounties[bountyId];
        require(bounty.status == BountyStatus.Claimed, "Bounty not claimed");
        require(bounty.claimer != address(0), "Winner not set");

        require(usdc.transferFrom(msg.sender, bounty.claimer, amount), "USDC transferFrom failed");

        totalEarned[bounty.claimer] += amount;

        emit WinnerTipped(bountyId, msg.sender, bounty.claimer, amount);
    }

    function cancelBounty(uint256 bountyId) external nonReentrant whenNotEmergency {
        require(bountyId < _bounties.length, "Invalid bounty id");
        Bounty storage bounty = _bounties[bountyId];

        require(msg.sender == bounty.creator, "Not bounty creator");
        require(bounty.status == BountyStatus.Open, "Bounty not open");
        require(_submissions[bountyId].length == 0, "Submissions exist");

        bounty.status = BountyStatus.Cancelled;

        require(usdc.transfer(bounty.creator, bounty.reward), "USDC transfer failed");

        emit BountyCancelled(bountyId);
    }

    function claimExpiredBounty(uint256 bountyId) external nonReentrant {
        require(bountyId < _bounties.length, "Invalid bounty id");
        Bounty storage bounty = _bounties[bountyId];

        require(bounty.status == BountyStatus.Open, "Bounty not open");
        require(bounty.deadline != 0 && block.timestamp > bounty.deadline, "Bounty not expired");
        require(msg.sender == bounty.creator, "Not bounty creator");

        bounty.status = BountyStatus.Cancelled;

        require(usdc.transfer(bounty.creator, bounty.reward), "USDC transfer failed");

        emit BountyCancelled(bountyId);
    }

    function emergencyRefund(uint256 bountyId) external onlyOwner nonReentrant {
        require(emergencyMode, "Emergency mode inactive");
        require(bountyId < _bounties.length, "Invalid bounty id");
        Bounty storage bounty = _bounties[bountyId];
        require(bounty.status == BountyStatus.Open, "Bounty not open");

        bounty.status = BountyStatus.Cancelled;

        require(usdc.transfer(bounty.creator, bounty.reward), "USDC transfer failed");

        emit BountyCancelled(bountyId);
    }

    function getBounty(uint256 id) external view returns (Bounty memory) {
        require(id < _bounties.length, "Invalid bounty id");
        return _bounties[id];
    }

    function getBounties() external view returns (Bounty[] memory) {
        return _bounties;
    }

    function getSubmissions(uint256 bountyId) external view returns (Submission[] memory) {
        require(bountyId < _bounties.length, "Invalid bounty id");
        return _submissions[bountyId];
    }

    function getReputation(address user) external view returns (uint256 earned, uint256 won, uint256 created) {
        return (totalEarned[user], bountiesWon[user], bountiesCreated[user]);
    }
}
