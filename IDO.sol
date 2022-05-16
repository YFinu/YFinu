//SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract IDO is Ownable, ReentrancyGuard {
    address internal yFAddr;
    uint8 constant YFINUPERBNB = 2;
    uint256 internal minBuy = 0.1 ether;
    uint256 internal maxBuy = 5 ether;

    constructor(address yfAddr_, address owner_) Ownable() {
        yFAddr = yfAddr_;
        transferOwnership(owner_);
    }

    function setYfAddr(address yfAddr_) external onlyOwner {
        yFAddr = yfAddr_;
    }

    function withdrawYfInu() external onlyOwner {
        uint256 bal = IERC20(yFAddr).balanceOf(address(this));
        require(bal > 0, "Zero Yfinu Balance");
        IERC20(yFAddr).transfer(owner(), bal);
    }

    function withdrawBNB() external onlyOwner {
        uint256 bal = address(this).balance;
        require(bal > 0, "Zero BNB Balance");

        payable(owner()).transfer(bal);
    }

    function setMinMax(uint256 minVal_, uint256 maxVal_) external onlyOwner {
        minBuy = minVal_;
        maxBuy = maxVal_;
    }

    function contractYfinuBalance() public view returns (uint256) {
        uint256 bal = IERC20(yFAddr).balanceOf(address(this));
        return bal;
    }

    function contractBnbBalance() public view returns (uint256) {
        uint256 bal = address(this).balance;
        return bal;
    }

    function buyYfinu() external payable nonReentrant {
        require(msg.value >= minBuy && msg.value <= maxBuy);

        require(
            IERC20(yFAddr).balanceOf(msg.sender) < maxBuy,
            "Max Tokens Bought"
        );
        uint256 yfinuToTransfer_ = YFINUPERBNB * msg.value;
        require(
            yfinuToTransfer_ <= contractYfinuBalance(),
            "Almost Sold Out.Try Less amount."
        );
        // payable(owner()).transfer(msg.value);
        IERC20(yFAddr).transfer(msg.sender, yfinuToTransfer_);
    }
}
