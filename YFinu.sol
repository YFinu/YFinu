//SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract YFinu is ERC20Capped, Ownable {
    uint256 constant MAX_SUPPLY = 30000 * 10**18;
    uint256 vestCount;

    constructor() ERC20Capped(MAX_SUPPLY) ERC20("YFinu", "YFinu") Ownable() {
        _mint(owner(), MAX_SUPPLY);
    }

    function vestTokens(address _vestContract, uint256 _amount)
        external
        onlyOwner
    {
        require(vestCount < 3);
        transfer(_vestContract, _amount);
        vestCount += 1;
    }
}
