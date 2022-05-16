//SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./YFinu.sol";
import "./IDO.sol";
import "./TokenVesting.sol";
import "./Staking.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";

contract YFinuFactory is Ownable {
    address public yfInuTokenCAddr;
    address public idoAddr;
    address[] public vestCAddr;
    address public stakingCAddr;

    constructor(
        uint256 _stakeRewardAllocation,
        uint256 _idoAllocation,
        address[] memory _beneficiaryAddr,
        uint256[] memory _start,
        uint256[] memory _cliff,
        uint256[] memory _duration,
        uint256[] memory _token
    ) {
        YFinu yfinu = new YFinu();
        yfInuTokenCAddr = address(yfinu);

        //IDO
        IDO ido = new IDO(yfInuTokenCAddr, _msgSender());
        idoAddr = address(ido);
        yfinu.transfer(idoAddr, _idoAllocation);

        //Staking
        Staking staking = new Staking(yfInuTokenCAddr, 10, _msgSender());
        stakingCAddr = address(staking);
        yfinu.transfer(stakingCAddr, _stakeRewardAllocation);

        for (uint8 i = 0; i < 1; i += 1) {
            TokenVesting tokenVest = new TokenVesting(
                yfInuTokenCAddr,
                _beneficiaryAddr[i],
                _start[i],
                _cliff[i],
                _duration[i],
                _msgSender(),
                _token[i]
            );
            vestCAddr.push(address(tokenVest));
            yfinu.vestTokens(vestCAddr[i], _token[i]);
        }
        yfinu.transfer(_msgSender(), yfinu.balanceOf(address(this)));
        yfinu.transferOwnership(_msgSender());
    }
}
