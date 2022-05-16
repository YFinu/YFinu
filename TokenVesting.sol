//SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";

contract TokenVesting is Ownable {
    event Released(uint256 amount);

    // beneficiary of tokens after they are released

    uint256 public totalLockedAmount;
    address vestedTokenAddr;
    address public beneficiary;
    uint256 public cliff;
    uint256 public start;
    uint256 public duration;

    uint256 public released;

    /**
     * @dev Creates a vesting contract that vests its balance of any ERC20 token to the
     * _beneficiary, gradually in a linear fashion until _start + _duration. By then all
     * of the balance will have vested.
     * @param _beneficiary address of the beneficiary to whom vested tokens are transferred
     * @param _cliff duration in seconds of the cliff in which tokens will begin to vest
     * @param _duration duration in seconds of the period in which the tokens will vest
     */

    constructor(
        address _vestedTokenAddr,
        address _beneficiary,
        uint256 _start,
        uint256 _cliff,
        uint256 _duration,
        address _owner,
        uint256 _lockedAmount
    ) Ownable() {
        require(_vestedTokenAddr != address(0));
        require(_beneficiary != address(0));
        require(_cliff <= _duration);
        transferOwnership(_owner);
        vestedTokenAddr = _vestedTokenAddr;
        beneficiary = _beneficiary;
        duration = _duration;
        cliff = _start + _cliff;
        start = _start;
        totalLockedAmount = _lockedAmount;
    }

    // /**
    //  * @notice Transfers vested tokens to beneficiary.
    //  */
    function release() public {
        uint256 unreleased = releasableAmount();

        require(unreleased > 0);
        released = released + unreleased;

        IERC20(vestedTokenAddr).transfer(beneficiary, unreleased);

        emit Released(unreleased);
    }

    // /**
    //  * @dev Calculates the amount that has already vested but hasn't been released yet.
    //  */
    function releasableAmount() public view returns (uint256) {
        return vestedAmount() - released;
    }

    // /**
    //  * @dev Calculates the amount that has already vested.
    //  */
    function vestedAmount() public view returns (uint256) {
        uint256 currentBalance = IERC20(vestedTokenAddr).balanceOf(
            address(this)
        );
        uint256 totalBalance = currentBalance + released;

        if (block.timestamp < cliff) {
            return 0;
        } else if (block.timestamp >= cliff + duration) {
            return totalBalance;
        } else {
            return (totalBalance * (block.timestamp - cliff)) / (duration);
        }
    }

    function totalUnclaimedAmount() public view returns (uint256) {
        uint256 _amount = IERC20(vestedTokenAddr).balanceOf(address(this));
        return _amount;
    }
}
