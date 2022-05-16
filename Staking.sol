//SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract Staking is Ownable, ReentrancyGuard {
    struct StakeData {
        uint256 stakeAmount;
        uint256 lastUpdate;
    }
    struct AprData {
        uint256 apr;
        uint256 updateTime;
    }

    uint8 isActive = 1;
    address internal yFinuContract;
    mapping(address => StakeData) public stakes;
    uint256 public totalStakeValue;
    uint256 public currentAPR;
    bool internal aprChanged = true;
    uint256 internal aprCounter;
    AprData[] internal aprArr;

    constructor(
        address _yFinuAddress,
        uint256 _apr,
        address _owner
    ) Ownable() {
        yFinuContract = _yFinuAddress;
        setRewardAPR(_apr);
        transferOwnership(_owner);
    }

    /*
     * @notice A method to check if an address is a stakeholder.
     * @param _address The address to verify.
     * @return bool, uint256 Whether the address is a stakeholder,
     * and if so its position in the stakeholders array.
     */
    function isStakeActive(address _stakeHolder) public view returns (bool) {
        if (stakes[_stakeHolder].stakeAmount >= 1000000000000) return true;
        return false;
    }

    function stake(uint256 _stakeVal) external active nonReentrant {
        address _sender = _msgSender();

        require(_stakeVal > 0, "Cannot stake zero");
        require(yFinuContract != address(0), "YFinu contract not init");
        require(
            IERC20(yFinuContract).transferFrom(
                _sender,
                address(this),
                _stakeVal
            ),
            "Approve Token For Staking"
        );
        uint256 _rewardEarned = pendingReward(_sender);
        stakes[_sender].lastUpdate = block.timestamp;

        uint256 _totalAmnt = _stakeVal + _rewardEarned;
        stakes[_sender].stakeAmount += _totalAmnt;
        totalStakeValue += _totalAmnt;
        emit Staked(msg.sender, _totalAmnt);
    }

    function compound() external active nonReentrant {
        address _sender = _msgSender();
        require(yFinuContract != address(0), "YFinu contract not init");
        require(isStakeActive(_msgSender()), "Not Active Staker");
        uint256 _rewardEarned = pendingReward(_sender);
        require(_rewardEarned > 0, "Should be Non Zero");
        stakes[_sender].lastUpdate = block.timestamp;
        stakes[_sender].stakeAmount += _rewardEarned;
        totalStakeValue += _rewardEarned;
        emit Compound(_sender, _rewardEarned);
    }

    function unStake(uint256 _unstakeVal) external nonReentrant {
        address _sender = _msgSender();
        require(_unstakeVal != 0, "Cannot stake zero");
        require(
            _unstakeVal <= stakes[_sender].stakeAmount,
            "Amount should be less than staked amount"
        );
        require(yFinuContract != address(0), "YFinu contract not init");

        uint256 _rewardEarned = pendingReward(_sender);
        stakes[_sender].lastUpdate = block.timestamp;

        stakes[_sender].stakeAmount -= _unstakeVal;
        totalStakeValue -= _unstakeVal;

        uint256 _amount = _rewardEarned + _unstakeVal;
        require(
            IERC20(yFinuContract).transfer(_sender, _amount),
            "Token Transfer failed"
        );
        if (stakes[_sender].stakeAmount == 0) {
            delete stakes[_sender];
        }
        emit Withdraw(_sender, _amount);
    }

    function pendingReward(address _stakeHolder) public view returns (uint256) {
        if (
            stakes[_stakeHolder].lastUpdate == 0 ||
            stakes[_stakeHolder].stakeAmount < 1000000000000
        ) return 0;

        uint256 _len = aprArr.length;
        uint256 _reward;
        uint256 _timeGap;
        if (_len == 1) {
            _timeGap = block.timestamp - stakes[_stakeHolder].lastUpdate;
            _reward = aprFormula(_timeGap, _stakeHolder, 0);
        } else if (
            stakes[_stakeHolder].lastUpdate >= aprArr[_len - 1].updateTime
        ) {
            _timeGap = block.timestamp - stakes[_stakeHolder].lastUpdate;
            _reward = aprFormula(_timeGap, _stakeHolder, _len - 1);
        } else {
            for (uint256 i = 0; i < _len; i++) {
                if (i + 1 == _len) {
                    _timeGap = block.timestamp - aprArr[i].updateTime;
                    _reward += aprFormula(_timeGap, _stakeHolder, i);
                } else {
                    _timeGap = aprArr[i + 1].updateTime - aprArr[i].updateTime;
                    _reward += aprFormula(_timeGap, _stakeHolder, i);
                }
            }
        }
        return _reward;
    }

    /** Calculates residual amount which will be wasted if claimed before day completion */
    function pendingResidual(address _stakeHolder)
        public
        view
        returns (uint256)
    {
        if (
            stakes[_stakeHolder].lastUpdate == 0 ||
            stakes[_stakeHolder].stakeAmount < 1000000000000
        ) return 0;

        uint256 _len = aprArr.length;
        uint256 _reward;
        uint256 _timeGap;
        if (_len == 1) {
            _timeGap = block.timestamp - stakes[_stakeHolder].lastUpdate;
            _reward = grossFormula(_timeGap, _stakeHolder, 0);
        } else if (
            stakes[_stakeHolder].lastUpdate >= aprArr[_len - 1].updateTime
        ) {
            _timeGap = block.timestamp - stakes[_stakeHolder].lastUpdate;
            _reward = grossFormula(_timeGap, _stakeHolder, _len - 1);
        } else {
            for (uint256 i = 0; i < _len; i++) {
                if (i + 1 == _len) {
                    _timeGap = block.timestamp - aprArr[i].updateTime;
                    _reward += grossFormula(_timeGap, _stakeHolder, i);
                } else {
                    _timeGap = aprArr[i + 1].updateTime - aprArr[i].updateTime;
                    _reward += grossFormula(_timeGap, _stakeHolder, i);
                }
            }
        }
        return _reward - pendingReward(_stakeHolder);
    }

    function aprFormula(
        uint256 _timeGap,
        address _stakeHolder,
        uint256 _tier
    ) internal view returns (uint256) {
        uint256 _reward = (((stakes[_stakeHolder].stakeAmount *
            aprArr[_tier].apr) / 100) * (_timeGap / (60 * 60 * 24))) / 365; /* 525600 */
        return _reward;
    }

    function grossFormula(
        uint256 _timeGap,
        address _stakeHolder,
        uint256 _tier
    ) public view returns (uint256) {
        uint256 _reward = (((stakes[_stakeHolder].stakeAmount *
            aprArr[_tier].apr) / 100) * _timeGap) / 31536000;
        return _reward;
    }

    //****Owner Functions */
    function setRewardAPR(uint256 _newRate) public onlyOwner {
        aprArr.push(AprData(_newRate, block.timestamp));
        currentAPR = _newRate;
    }

    function setYFinuContract(address _contract) public onlyOwner {
        yFinuContract = _contract;
    }

    function contractBalance() public view returns (uint256) {
        uint256 bal = IERC20(yFinuContract).balanceOf(address(this));
        return bal;
    }

    function isStakingActive(bool _active) external onlyOwner {
        isActive = (_active) ? 1 : 0;
    }

    function withdrawNonUserBalance(uint256 _amount) external onlyOwner {
        uint256 _tokenAllowed = contractBalance() - totalStakeValue;
        require(_amount <= _tokenAllowed, "Owner balance less than amount");
        IERC20(yFinuContract).transfer(_msgSender(), _amount);
    }

    modifier active() {
        require(isActive == 1, "Staking is paused");
        _;
    }
    //***Events*** */

    event Staked(address indexed _user, uint256 _amount);
    event Withdraw(address indexed _user, uint256 _amount);
    event Compound(address indexed _user, uint256 _amount);
}
