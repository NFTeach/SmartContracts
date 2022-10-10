// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./SBT.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@aave/contracts/interfaces/IPoolAddressesProvider.sol";
import "@aave/contracts/interfaces/IPool.sol";

/*
09/06: TODO: Set up chainlink Keeper to update balance one a week with AAVE
             Write foundry test to check if it works
*/

contract Governor is Ownable {
    IERC20 public wmatic = IERC20(0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270);
    IERC20 public aWmatic = IERC20(0x6d80113e533a2C0fe82EaBD35f1875DcEA89Ea97);
    IPool public aavePool = IPool(0x794a61358D6845594F94dc1DB02A252b5b4814aD);
    SBT public sbt;

    /* -------------------------------------------------------------------------- */
    /*                              STATE VARIABLES                             */
    /* -------------------------------------------------------------------------- */

    //Amount of Wmatic needed to stake a course
    uint256 immutable stakeAmount = 1;

    uint256 public totalStaked; //in WMatic
    uint256 public interval; //in seconds, for Chainlink keeper
    uint256 public lastTimeStamp;
    uint256 public minReserve = 5; //in WMatic

    mapping(address => uint256) public teacherBalance;
    mapping(uint256 => bool) public courseStaked;

    /* -------------------------------------------------------------------------- */
    /*                                   EVENTS                                   */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice emited when Chainlink Keeper deposit some Wmatic into AAVE's pool
     * @param amount amount of Wmatic deposited into AAVE
     */
    event aaveDeposit(uint256 amount);

    /**
     * @notice emited when an educator withdraw a course and gets refundedm or when Chainlink Keeper deposit some Wmatic into AAVE's pool
     * @param amount amount of Wmatic withdrew from AAVE
     */
    event aaveWithdraw(uint256 amount);

    /* -------------------------------------------------------------------------- */
    /*                                 CONSTRUCTOR                                */
    /* -------------------------------------------------------------------------- */

    constructor(uint256 updateInterval, address deployedSBT) {
        interval = updateInterval;
        lastTimeStamp = block.timestamp;
        wmatic.approve(address(aavePool), type(uint256).max - 1);
        sbt = SBT(deployedSBT);
    }

    /* -------------------------------------------------------------------------- */
    /*                              CUSTOM MODIFIERS                              */
    /* -------------------------------------------------------------------------- */

    modifier onlySBT() {
        require(msg.sender == address(sbt), "Not SBT contract");
        _;
    }

    /* -------------------------------------------------------------------------- */
    /*                             EXTERNAL FUNCTIONS                             */
    /* -------------------------------------------------------------------------- */

    function teacherStaking(uint256 _courseId, address _educator)
        external
        onlySBT
    {
        require(
            wmatic.allowance(_educator, address(this)) >= stakeAmount,
            "Make sure you approve the Wmatic contract"
        );
        require(
            wmatic.balanceOf(_educator) >= stakeAmount,
            "Not enough WMatic"
        );

        wmatic.transferFrom(_educator, address(this), stakeAmount);

        courseStaked[_courseId] = true;
        teacherBalance[_educator] = teacherBalance[_educator] + stakeAmount;
        totalStaked = totalStaked + stakeAmount;
    }

    function teacherWithdraw(uint256 _courseId, address _educator)
        external
        onlySBT
    {
        require(wmatic.balanceOf(address(this)) >= 1, "Not enough Wmatic");

        courseStaked[_courseId] = false;
        teacherBalance[_educator] = teacherBalance[_educator] - stakeAmount;
        totalStaked = totalStaked - stakeAmount;
        wmatic.transfer(_educator, stakeAmount);
    }

    //TODO: Check if the returned bytes are needed
    function checkUpkeep(bytes calldata)
        external
        view
        returns (bool upkeepNeeded)
    {
        upkeepNeeded = (block.timestamp - lastTimeStamp) > interval;
    }

    function performUpkeep(bytes calldata) external {
        //We highly recommend revalidating the upkeep in the performUpkeep function
        if ((block.timestamp - lastTimeStamp) > interval) {
            lastTimeStamp = block.timestamp;
            if (wmatic.balanceOf(address(this)) > 0) {
                uint256 currWmaticBal = wmatic.balanceOf(address(this));
                if (currWmaticBal > minReserve) {
                    uint256 amountToDeposit = currWmaticBal - minReserve;
                    _aaveDeposit(amountToDeposit);
                } else if (currWmaticBal < minReserve) {
                    uint256 amountToWithdraw = minReserve - currWmaticBal;
                    //Check to see if Governor has enough aWmatic to withdraw Wmatic in order to refill the reserve
                    if (amountToWithdraw < aWmatic.balanceOf(address(this))) {
                        _aaveWithdraw(amountToWithdraw);
                    }
                }
            }
        }
    }

    /* -------------------------------------------------------------------------- */
    /*                              Owner Functions                               */
    /* -------------------------------------------------------------------------- */

    function redeemAWmatic(uint256 _amount) external onlyOwner {
        _aaveWithdraw(_amount);
    }

    function setNewMinReserve(uint256 _newReserveAmount) external onlyOwner {
        minReserve = _newReserveAmount;
    }

    function setNewInterval(uint256 _newIntervale) external onlyOwner {
        interval = _newIntervale;
    }

    /* -------------------------------------------------------------------------- */
    /*                             Internal Functions                             */
    /* -------------------------------------------------------------------------- */

    function _aaveDeposit(uint256 _amount) internal {
        if (_amount > 0) {
            aavePool.supply(address(wmatic), _amount, address(this), 0);
            emit aaveDeposit(_amount);
        }
    }

    function _aaveWithdraw(uint256 _amount) internal {
        uint256 amountAwmatic = aWmatic.balanceOf(address(this));
        if (amountAwmatic >= _amount) {
            aWmatic.approve(address(aavePool), _amount);
            aavePool.withdraw(address(wmatic), _amount, address(this));
            emit aaveWithdraw(_amount);
        }
    }
}

// receive() external payable {}
// fallback() external payable {}
// }
