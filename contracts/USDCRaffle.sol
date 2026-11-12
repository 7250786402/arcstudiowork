// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract USDCRaffle is Ownable, ReentrancyGuard {
    IERC20 public immutable usdc;

    uint256 public constant REFUND_WINDOW = 3 days;

    uint256 public ticketPrice;
    uint256 public maxTickets;
    uint256 public endTime;
    uint256 private raffleId;
    uint256 public totalPrizePool;
    uint256 public totalRefunded;

    bool public raffleCreated;
    bool public raffleCancelled;
    bool public winnerPicked;

    bytes32 public commitment;
    bool public committed;
    uint256 public commitBlock;

    mapping(address => uint256) public ticketsBought;
    mapping(address => uint256) private ticketsBoughtRaffleId;

    address[] private tickets;

    event RaffleCreated(uint256 ticketPrice, uint256 maxTickets, uint256 endTime);
    event TicketPurchased(address indexed buyer, uint256 count);
    event WinnerPicked(address indexed winner, uint256 prize);
    event RaffleCancelled();

    constructor(address usdcAddress) Ownable(msg.sender) {
        require(usdcAddress != address(0), "USDC address is zero");
        usdc = IERC20(usdcAddress);
    }

    function createRaffle(uint256 _ticketPrice, uint256 _maxTickets, uint256 _durationSeconds) external onlyOwner {
        require(_ticketPrice > 0, "Ticket price must be > 0");
        require(_maxTickets > 0, "Max tickets must be > 0");
        require(_durationSeconds > 0, "Duration must be > 0");

        if (raffleCreated) {
            bool previousResolved = raffleCancelled || winnerPicked || !raffleCreated;
            require(previousResolved, "Previous raffle unresolved");
        }

        delete tickets;

        ticketPrice = _ticketPrice;
        maxTickets = _maxTickets;
        endTime = block.timestamp + _durationSeconds;

        raffleId++;
        raffleCreated = true;
        raffleCancelled = false;
        winnerPicked = false;
        committed = false;
        commitment = bytes32(0);
        commitBlock = 0;
        totalPrizePool = 0;
        totalRefunded = 0;

        emit RaffleCreated(_ticketPrice, _maxTickets, endTime);
    }

    function buyTickets(uint256 count) external nonReentrant {
        require(count > 0, "Count must be > 0");
        require(raffleCreated, "Raffle not created");
        require(!raffleCancelled, "Raffle cancelled");
        require(!winnerPicked, "Winner already picked");
        require(block.timestamp < endTime, "Raffle ended");
        require(tickets.length + count <= maxTickets, "Exceeds max tickets");

        uint256 totalCost = ticketPrice * count;
        require(usdc.transferFrom(msg.sender, address(this), totalCost), "USDC transferFrom failed");

        totalPrizePool += totalCost;

        if (ticketsBoughtRaffleId[msg.sender] != raffleId) {
            ticketsBoughtRaffleId[msg.sender] = raffleId;
            ticketsBought[msg.sender] = 0;
        }
        ticketsBought[msg.sender] += count;

        for (uint256 i = 0; i < count; i++) {
            tickets.push(msg.sender);
        }

        emit TicketPurchased(msg.sender, count);
    }

    function commitWinner(bytes32 _commitment) external onlyOwner {
        require(raffleCreated, "Raffle not created");
        require(!raffleCancelled, "Raffle cancelled");
        require(!winnerPicked, "Winner already picked");
        require(block.timestamp >= endTime, "Raffle not ended");
        require(tickets.length > 0, "No tickets sold");
        require(!committed, "Winner already committed");

        commitment = _commitment;
        committed = true;
        commitBlock = block.number;
    }

    function pickWinner(bytes32 secret) external nonReentrant onlyOwner {
        require(raffleCreated, "Raffle not created");
        require(!raffleCancelled, "Raffle cancelled");
        require(!winnerPicked, "Winner already picked");
        require(block.timestamp >= endTime, "Raffle not ended");
        require(tickets.length > 0, "No tickets sold");
        require(committed, "Winner not committed");
        require(keccak256(abi.encodePacked(secret)) == commitment, "Invalid secret");

        bytes32 entropy = keccak256(abi.encodePacked(secret, tickets.length, commitBlock));
        uint256 winnerIndex = uint256(entropy) % tickets.length;
        address winner = tickets[winnerIndex];

        winnerPicked = true;

        uint256 prize = usdc.balanceOf(address(this));
        require(usdc.transfer(winner, prize), "USDC transfer failed");

        emit WinnerPicked(winner, prize);
    }

    function claimRefund() external nonReentrant {
        require(raffleCreated, "Raffle not created");
        require(!winnerPicked, "Winner already picked");
        require(block.timestamp > endTime + REFUND_WINDOW, "Refund unavailable");
        require(ticketsBoughtRaffleId[msg.sender] == raffleId, "No tickets bought");

        uint256 count = ticketsBought[msg.sender];
        require(count > 0, "No tickets bought");

        ticketsBought[msg.sender] = 0;

        uint256 refundAmount = ticketPrice * count;
        require(usdc.transfer(msg.sender, refundAmount), "USDC transfer failed");

        totalRefunded += refundAmount;

        if (totalRefunded >= totalPrizePool) {
            raffleCancelled = true;
            committed = false;
            commitment = bytes32(0);
            commitBlock = 0;
        }
    }

    function cancelRaffle() external onlyOwner {
        require(raffleCreated, "Raffle not created");
        require(!raffleCancelled, "Raffle already cancelled");
        require(!winnerPicked, "Winner already picked");
        require(tickets.length == 0, "Tickets already sold");

        raffleCancelled = true;

        emit RaffleCancelled();
    }

    function getTickets() external view returns (address[] memory) {
        return tickets;
    }

    function ticketCount() external view returns (uint256) {
        return tickets.length;
    }

    function prizePool() external view returns (uint256) {
        return usdc.balanceOf(address(this));
    }

    function raffleActive() external view returns (bool) {
        return raffleCreated && !raffleCancelled && !winnerPicked && block.timestamp < endTime && tickets.length < maxTickets;
    }

    function timeLeft() external view returns (uint256) {
        if (!raffleCreated || raffleCancelled || winnerPicked || block.timestamp >= endTime) {
            return 0;
        }

        return endTime - block.timestamp;
    }
}
