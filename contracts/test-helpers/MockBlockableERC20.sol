// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice MockERC20-compatible storage layout (slots 0-2) plus a per-recipient block list.
/// @dev Etch over an already-seeded MockERC20 at the USDC address: storage is preserved.
///      mode 1 => transfer to a blocked recipient reverts; mode 2 => it returns false.
contract MockBlockableERC20 {
    mapping(address => uint256) public balanceOf; // slot 0
    mapping(address => mapping(address => uint256)) public allowance; // slot 1
    uint256 public totalSupply; // slot 2
    mapping(address => uint8) public blockMode; // slot 3

    event Transfer(address indexed from, address indexed to, uint256 value);

    function setBlock(address who, uint8 mode) external {
        blockMode[who] = mode;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        if (blockMode[to] == 1) revert("blocked");
        if (blockMode[to] == 2) return false;
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        require(allowed >= amount, "allowance");
        if (allowed != type(uint256).max) allowance[from][msg.sender] = allowed - amount;
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        require(balanceOf[from] >= amount, "balance");
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
    }
}
