// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract PredictionGame is Ownable, ReentrancyGuard {
    IERC20 public immutable usdc;

    uint256 public constant REFUND_WINDOW = 3 days;

    struct Bet {
        bool hasBet;
        uint256 optionIndex;
        bool claimed;
        bool refunded;
    }

    string private _question;
    string[] private _options;

    uint256 public betAmount;
    uint256 public endTime;
    bool public resolved;
    uint256 public winningOption;
    uint256 public totalPool;
    uint256 public totalBets;
    uint256 private _winnersCount;
    bool public gameCreated;

    mapping(address => Bet) private _bets;
    address[] private _bettors;
    mapping(uint256 => uint256) public optionBetCount;

    event BetPlaced(address indexed bettor, uint256 optionIndex);
    event GameResolved(uint256 winningOptionIndex, uint256 totalPool, uint256 winnersCount);
    event WinningsClaimed(address indexed winner, uint256 amount);

    constructor(address usdcAddress, address initialOwner) Ownable(initialOwner) {
        require(usdcAddress != address(0), "USDC address is zero");
        usdc = IERC20(usdcAddress);
    }

    function createQuestion(
        string memory question,
        string[] memory options,
        uint256 fixedBetAmount,
        uint256 duration
    ) external onlyOwner {
        require(!gameCreated, "Game already created");
        require(bytes(question).length > 0, "Question empty");
        require(options.length >= 2 && options.length <= 4, "Options must be 2-4");
        require(fixedBetAmount > 0, "Bet amount must be > 0");
        require(duration > 0, "Duration must be > 0");

        _question = question;
        delete _options;
        for (uint256 i = 0; i < options.length; i++) {
            require(bytes(options[i]).length > 0, "Option empty");
            _options.push(options[i]);
        }

        betAmount = fixedBetAmount;
        endTime = block.timestamp + duration;
        resolved = false;
        winningOption = 0;
        totalPool = 0;
        totalBets = 0;
        _winnersCount = 0;
        gameCreated = true;
    }

    function placeBet(uint256 optionIndex) external nonReentrant {
        require(gameCreated, "Game not created");
        require(!resolved, "Game already resolved");
        require(block.timestamp < endTime, "Betting ended");
        require(optionIndex < _options.length, "Invalid option");
        require(!_bets[msg.sender].hasBet, "Already bet");

        require(usdc.transferFrom(msg.sender, address(this), betAmount), "USDC transferFrom failed");

        _bets[msg.sender] = Bet({hasBet: true, optionIndex: optionIndex, claimed: false, refunded: false});
        _bettors.push(msg.sender);
        optionBetCount[optionIndex] += 1;

        totalPool += betAmount;
        totalBets += 1;

        emit BetPlaced(msg.sender, optionIndex);
    }

    function resolve(uint256 winningOptionIndex) external onlyOwner {
        require(gameCreated, "Game not created");
        require(!resolved, "Already resolved");
        require(block.timestamp >= endTime, "Game not ended");
        require(block.timestamp <= endTime + REFUND_WINDOW, "Refund window opened");
        require(winningOptionIndex < _options.length, "Invalid winning option");

        uint256 winnersCount = optionBetCount[winningOptionIndex];
        require(winnersCount > 0, "No winners for option");

        resolved = true;
        winningOption = winningOptionIndex;
        _winnersCount = winnersCount;

        emit GameResolved(winningOptionIndex, totalPool, winnersCount);
    }

    function claimWinnings() external nonReentrant {
        require(gameCreated, "Game not created");
        require(resolved, "Game not resolved");

        Bet storage bettorBet = _bets[msg.sender];
        require(bettorBet.hasBet, "No bet found");
        require(!bettorBet.refunded, "Bet refunded");
        require(!bettorBet.claimed, "Already claimed");
        require(bettorBet.optionIndex == winningOption, "Not a winner");

        uint256 payout = totalPool / _winnersCount;
        bettorBet.claimed = true;

        require(usdc.transfer(msg.sender, payout), "USDC transfer failed");

        emit WinningsClaimed(msg.sender, payout);
    }

    function claimRefund() external nonReentrant {
        require(gameCreated, "Game not created");
        require(!resolved, "Game resolved");
        require(block.timestamp > endTime + REFUND_WINDOW, "Refund unavailable");

        Bet storage bettorBet = _bets[msg.sender];
        require(bettorBet.hasBet, "No bet found");
        require(!bettorBet.claimed, "Already claimed");
        require(!bettorBet.refunded, "Already refunded");

        bettorBet.refunded = true;
        totalPool -= betAmount;

        require(usdc.transfer(msg.sender, betAmount), "USDC transfer failed");
    }

    function getQuestion()
        external
        view
        returns (
            string memory question,
            string[] memory options,
            uint256 fixedBetAmount,
            uint256 gameEndTime,
            bool isResolved,
            uint256 resolvedWinningOption,
            uint256 pool,
            uint256 betsCount
        )
    {
        return (_question, _options, betAmount, endTime, resolved, winningOption, totalPool, totalBets);
    }

    function getBet(address user) external view returns (bool hasBet, uint256 optionIndex) {
        Bet storage bettorBet = _bets[user];
        return (bettorBet.hasBet, bettorBet.optionIndex);
    }

    function getWinnersCount() external view returns (uint256) {
        return _winnersCount;
    }
}
