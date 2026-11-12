// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title EscrowDeal
/// @notice USDC deal escrow for Arc Testnet (chain ID 5042002), with no admin role.
/// @dev Amounts are in USDC base units. Buyers must approve this contract before creating a deal.
contract EscrowDeal is ReentrancyGuard {
    using SafeERC20 for IERC20;

    address public constant USDC_ADDRESS = 0x3600000000000000000000000000000000000000;
    IERC20 public constant usdc = IERC20(USDC_ADDRESS);
    uint256 public constant ARBITER_TIMEOUT = 14 days;

    enum Status {
        Funded,
        Accepted,
        Delivered,
        Released,
        Refunded,
        Disputed,
        Resolved
    }

    struct Deal {
        uint256 id;
        address buyer;
        address seller;
        address sellerPayout;
        address arbiter;
        uint256 amount;
        string title;
        string terms;
        uint256 deliverBy;
        uint256 reviewWindow;
        uint256 deliveredAt;
        uint256 disputedAt;
        Status status;
    }

    Deal[] private _deals;
    mapping(address => uint256[]) private _userDeals;
    mapping(uint256 => mapping(address => uint256)) private claimable;
    mapping(uint256 => uint256) public sellerOwed;

    event DealCreated(uint256 indexed id, address indexed buyer, address indexed seller, uint256 amount);
    event Delivered(uint256 indexed id);
    event Released(uint256 indexed id, address indexed seller, uint256 amount);
    event SellerWithdrawn(uint256 indexed id, address indexed payout, uint256 amount);
    event Refunded(uint256 indexed id, address indexed buyer, uint256 amount);
    event DisputeRaised(uint256 indexed id);
    event DisputeResolved(uint256 indexed id, uint256 toSeller, uint256 toBuyer);
    event PayoutUpdated(uint256 indexed id, address newPayout);

    /// @notice Create a funded deal with at least one bounded settlement path.
    /// @dev Requires a nonzero arbiter or a nonzero review window (or both).
    function createDeal(
        address seller,
        uint256 amount,
        string calldata title,
        string calldata terms,
        uint256 deliverBy,
        address arbiter,
        uint256 reviewWindow
    ) external nonReentrant returns (uint256 id) {
        require(seller != address(0), "Seller is zero");
        require(seller != msg.sender, "Seller is buyer");
        require(seller != address(this), "Seller is escrow");
        require(amount > 0, "Amount is zero");
        require(deliverBy > block.timestamp, "Invalid delivery deadline");
        require(arbiter == address(0) || (arbiter != msg.sender && arbiter != seller), "Invalid arbiter");
        require(reviewWindow == 0 || (reviewWindow >= 1 days && reviewWindow <= 30 days), "Invalid review window");
        require(arbiter != address(0) || reviewWindow != 0, "No settlement path");

        id = _deals.length;
        _deals.push();
        Deal storage deal = _deals[id];
        deal.id = id;
        deal.buyer = msg.sender;
        deal.seller = seller;
        deal.arbiter = arbiter;
        deal.amount = amount;
        deal.title = title;
        deal.terms = terms;
        deal.deliverBy = deliverBy;
        deal.reviewWindow = reviewWindow;
        deal.status = Status.Funded;

        _userDeals[msg.sender].push(id);
        _userDeals[seller].push(id);
        if (arbiter != address(0)) {
            _userDeals[arbiter].push(id);
        }

        emit DealCreated(id, msg.sender, seller, amount);
        usdc.safeTransferFrom(msg.sender, address(this), amount);
    }

    function acceptDeal(uint256 id, address payout) external nonReentrant {
        Deal storage deal = _getDeal(id);
        require(msg.sender == deal.seller, "Not seller");
        require(deal.status == Status.Funded, "Invalid status");
        require(block.timestamp <= deal.deliverBy, "Delivery deadline passed");
        require(payout != address(0), "Payout is zero");
        require(payout != address(this), "Payout is escrow");
        require(payout != USDC_ADDRESS, "Payout is USDC");
        require(uint160(payout) >= 0x10000, "Payout in precompile range");

        deal.sellerPayout = payout;
        deal.status = Status.Accepted;
    }

    function updatePayout(uint256 id, address newPayout) external nonReentrant {
        Deal storage deal = _getDeal(id);
        require(msg.sender == deal.seller, "Not seller");
        require(deal.status != Status.Funded, "Invalid status");
        require(newPayout != address(0), "Payout is zero");
        require(newPayout != address(this), "Payout is escrow");
        require(newPayout != USDC_ADDRESS, "Payout is USDC");
        require(uint160(newPayout) >= 0x10000, "Payout in precompile range");

        deal.sellerPayout = newPayout;
        emit PayoutUpdated(id, newPayout);
    }

    function cancelUnaccepted(uint256 id) external nonReentrant {
        Deal storage deal = _getDeal(id);
        require(msg.sender == deal.buyer, "Not buyer");
        require(deal.status == Status.Funded, "Invalid status");

        deal.status = Status.Refunded;
        emit Refunded(id, deal.buyer, deal.amount);
        usdc.safeTransfer(deal.buyer, deal.amount);
    }

    function markDelivered(uint256 id) external nonReentrant {
        Deal storage deal = _getDeal(id);
        require(msg.sender == deal.seller, "Not seller");
        require(deal.status == Status.Accepted, "Invalid status");
        require(block.timestamp <= deal.deliverBy, "Delivery deadline passed");

        deal.status = Status.Delivered;
        deal.deliveredAt = block.timestamp;
        emit Delivered(id);
    }

    function release(uint256 id) external nonReentrant {
        Deal storage deal = _getDeal(id);
        require(msg.sender == deal.buyer, "Not buyer");
        require(deal.status == Status.Accepted || deal.status == Status.Delivered, "Invalid status");

        require(sellerOwed[id] == 0, "Seller already credited");
        deal.status = Status.Released;
        sellerOwed[id] = deal.amount;
        emit Released(id, deal.seller, deal.amount);
    }

    function withdrawSeller(uint256 id) external nonReentrant {
        Deal storage deal = _getDeal(id);
        require(deal.status == Status.Released, "Invalid status");

        uint256 amount = sellerOwed[id];
        require(amount > 0, "Nothing to claim");
        sellerOwed[id] = 0;
        usdc.safeTransfer(deal.sellerPayout, amount);
        emit SellerWithdrawn(id, deal.sellerPayout, amount);
    }

    function refund(uint256 id) external nonReentrant {
        Deal storage deal = _getDeal(id);
        require(msg.sender == deal.seller, "Not seller");
        require(deal.status == Status.Accepted || deal.status == Status.Delivered, "Invalid status");

        deal.status = Status.Refunded;
        emit Refunded(id, deal.buyer, deal.amount);
        usdc.safeTransfer(deal.buyer, deal.amount);
    }

    function reclaimExpired(uint256 id) external nonReentrant {
        Deal storage deal = _getDeal(id);
        require(msg.sender == deal.buyer, "Not buyer");
        require(deal.status == Status.Funded || deal.status == Status.Accepted, "Invalid status");
        require(block.timestamp > deal.deliverBy, "Delivery deadline not passed");

        deal.status = Status.Refunded;
        emit Refunded(id, deal.buyer, deal.amount);
        usdc.safeTransfer(deal.buyer, deal.amount);
    }

    function claimAfterReviewWindow(uint256 id) external nonReentrant {
        Deal storage deal = _getDeal(id);
        require(msg.sender == deal.seller, "Not seller");
        // Disputed deals cannot pass this status check.
        require(deal.status == Status.Delivered, "Invalid status");
        require(deal.reviewWindow != 0, "Auto-release disabled");
        require(block.timestamp > deal.deliveredAt + deal.reviewWindow, "Review window not passed");

        require(sellerOwed[id] == 0, "Seller already credited");
        deal.status = Status.Released;
        sellerOwed[id] = deal.amount;
        emit Released(id, deal.seller, deal.amount);
    }

    /// @notice Either buyer or seller may raise a dispute while Delivered if the deal has an arbiter.
    /// @dev The buyer must act within a nonzero review window; the seller has no time limit while Delivered.
    function raiseDispute(uint256 id) external nonReentrant {
        Deal storage deal = _getDeal(id);
        require(msg.sender == deal.buyer || msg.sender == deal.seller, "Not buyer or seller");
        require(deal.status == Status.Delivered, "Invalid status");
        require(msg.sender == deal.seller || deal.reviewWindow == 0 || block.timestamp <= deal.deliveredAt + deal.reviewWindow, "Review window passed");
        require(deal.arbiter != address(0), "No arbiter");

        deal.status = Status.Disputed;
        deal.disputedAt = block.timestamp;
        emit DisputeRaised(id);
    }

    function resolveDispute(uint256 id, uint256 sellerAmount) external nonReentrant {
        Deal storage deal = _getDeal(id);
        require(msg.sender == deal.arbiter, "Not arbiter");
        require(deal.status == Status.Disputed, "Invalid status");
        require(sellerAmount <= deal.amount, "Exceeds escrow amount");

        uint256 buyerAmount = deal.amount - sellerAmount;
        claimable[id][deal.seller] = sellerAmount;
        claimable[id][deal.buyer] = buyerAmount;
        deal.status = Status.Resolved;
        emit DisputeResolved(id, sellerAmount, buyerAmount);
    }

    function claimResolved(uint256 id) external nonReentrant {
        _claimResolved(id, msg.sender);
    }

    /// @notice Anyone may claim for a party; funds go to the buyer or the seller's current payout.
    /// @param beneficiary The original buyer or seller whose entitlement is claimed.
    function claimResolved(uint256 id, address beneficiary) external nonReentrant {
        _claimResolved(id, beneficiary);
    }

    function _claimResolved(uint256 id, address beneficiary) private {
        Deal storage deal = _getDeal(id);
        require(beneficiary == deal.buyer || beneficiary == deal.seller, "Not buyer or seller");
        require(deal.status == Status.Resolved, "Invalid status");

        uint256 amount = claimable[id][beneficiary];
        require(amount > 0, "Nothing to claim");
        claimable[id][beneficiary] = 0;
        address payout = beneficiary == deal.seller ? deal.sellerPayout : deal.buyer;
        usdc.safeTransfer(payout, amount);
    }

    /// @notice Refund a still-unresolved dispute after the arbiter timeout has elapsed.
    function refundStaleDispute(uint256 id) external nonReentrant {
        Deal storage deal = _getDeal(id);
        require(msg.sender == deal.buyer, "Not buyer");
        require(deal.status == Status.Disputed, "Invalid status");
        require(block.timestamp > deal.disputedAt + ARBITER_TIMEOUT, "Arbiter timeout not passed");

        deal.status = Status.Refunded;
        emit Refunded(id, deal.buyer, deal.amount);
        usdc.safeTransfer(deal.buyer, deal.amount);
    }

    function getDeal(uint256 id) external view returns (Deal memory) {
        return _getDeal(id);
    }

    function dealCount() external view returns (uint256) {
        return _deals.length;
    }

    function dealsOf(address user) external view returns (uint256[] memory) {
        return _userDeals[user];
    }

    function claimableOf(uint256 id, address user) external view returns (uint256) {
        return claimable[id][user];
    }

    function _getDeal(uint256 id) private view returns (Deal storage deal) {
        require(id < _deals.length, "Invalid deal id");
        return _deals[id];
    }
}
