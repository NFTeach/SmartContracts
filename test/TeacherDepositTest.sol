// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/SBT.sol";
import "../src/Governor.sol";
import "@aave/contracts/interfaces/IPoolAddressesProvider.sol";
import "@aave/contracts/interfaces/IPool.sol";

interface IERC20Like {
    function balanceOf(address _addr) external view returns (uint256);

    function transfer(address dst, uint256 wad) external returns (bool);

    function approve(address guy, uint256 wad) external returns (bool);

    function allowance(address owner, address spender)
        external
        view
        returns (uint256);
}

contract TeacherDepositTest is Test {
    Governor public governor;
    SBT public sbt;

    IERC20Like wmatic = IERC20Like(0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270);
    IERC20Like aWmatic = IERC20Like(0x6d80113e533a2C0fe82EaBD35f1875DcEA89Ea97);
    IPool public aavePool = IPool(0x794a61358D6845594F94dc1DB02A252b5b4814aD);

    //WMatic address on polygon
    address wMaticOwner = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;

    //Set up contract and course creation
    function testSetup() public {
        //Fork polygon mainnet
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), 32821975);

        //Deploy SBT and Governor
        sbt = new SBT("myURLAddress");
        governor = new Governor(30, address(sbt));

        //Pre and Post check of addEducator()
        assert(sbt.isEducator(wMaticOwner) == false);
        sbt.addEducator(wMaticOwner);
        assert(sbt.isEducator(wMaticOwner) == true);

        sbt.setGovernor(address(governor));

        //Create new course fron newly created educator
        vm.startPrank(wMaticOwner);

        wmatic.approve(address(governor), 10000);

        assert(sbt.getTestEducator(0) == address(0));
        assert(governor.courseStaked(0) == false);
        assert(wmatic.balanceOf(address(governor)) == 0);
        sbt.createSBT(0, "myStringTest");
        assert(sbt.getTestEducator(0) == wMaticOwner);
        assert(governor.courseStaked(0) == true);
        assert(wmatic.balanceOf(address(governor)) == 1);

        vm.stopPrank();
    }

    function testDirectCallGovernor() public {
        testSetup();

        //Expect next call will fail since calling governor's function directly and not passing though SBT contract
        vm.expectRevert(abi.encodePacked("Not SBT contract"));
        governor.teacherStaking(0, 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270);
    }

    function testNonEducatorTestCreation() public {
        testSetup();

        //Expect that next call will fail since current address is not an educator
        vm.expectRevert(abi.encodePacked("Not an educator"));
        sbt.createSBT(1, "myStringTest");
    }

    function testSBTCreation() public {
        testSetup();

        address newStudent = address(0xdeadbeef);

        //Pre and Post check for addStudent()
        assert(sbt.isStudent(newStudent) == false);
        sbt.addStudent(newStudent);
        assert(sbt.isStudent(newStudent) == true);

        //Pre and Post check for validateStudentTest
        assert(sbt.isAllowedMint(newStudent, 0) == false);
        sbt.validateStudentTest(newStudent, 0);
        assert(sbt.isAllowedMint(newStudent, 0) == true);

        vm.startPrank(newStudent);
        sbt.mintSBT(
            0,
            "https://ipfs.moralis.io:2053/ipfs/QmT2GdiwZGq4u5uDjWKvZyviJVG27LduF6aj7JD3v7kVsE",
            "myCourseObjectId"
        );

        assertEq(
            sbt.getCertificate(newStudent, 0),
            "https://ipfs.moralis.io:2053/ipfs/QmT2GdiwZGq4u5uDjWKvZyviJVG27LduF6aj7JD3v7kVsE"
        );

        vm.stopPrank();
    }

    function testChainlinkKeeper() public {
        testSetup();

        vm.startPrank(wMaticOwner);

        //Create 6 SBT so that there is 7 wmatic stacked on the contract and the chainlink keeper can send 2 wmatic to AAVE for staking
        sbt.createSBT(1, "BJYq5rIpyBWkXErKfsXAgDNx");
        sbt.createSBT(1, "BJYq5rIpyBWkXErKfsXAgDN");
        sbt.createSBT(1, "BJYq5rIpyBWkXErKfsXAgDNxX");
        sbt.createSBT(1, "BJYq5rIpyBWkXErKfsXAgDNxsa");
        sbt.createSBT(1, "BJYq5rIpyBWkXErKfsXAgDNxasdaw");
        sbt.createSBT(1, "BJYq5rIpyBWkXErKfsXAgDNxadwad");

        //Pre AAVE deposit check - Balance of contract is 7wmatic and 0 aWmatic
        assert(wmatic.balanceOf(address(governor)) == 7);
        assert(aWmatic.balanceOf(address(governor)) == 0);

        assert(governor.checkUpkeep("") == false);

        //Move the blockchain forward so that enought time has passed for the chainlink keeper to do its thing
        vm.warp(1662592767);

        assert(governor.checkUpkeep("") == true);
        governor.performUpkeep("");

        //Post AAVE deposit check - 2 wmatic were deposited to 2 aWmatic were received
        assert(wmatic.balanceOf(address(governor)) == 5);
        assert(aWmatic.balanceOf(address(governor)) == 2);

        vm.stopPrank();
    }

    function testAAVEStaking() public {
        testChainlinkKeeper();

        //Test course withdrawal
        assert(governor.courseStaked(5) == true);
        vm.startPrank(wMaticOwner);

        //Take down a course, which unstake 1 wmatic, so now balance of contract is 4
        sbt.withdrawCourse(5);
        assert(governor.courseStaked(5) == false);
        assert(wmatic.balanceOf(address(governor)) == 4);

        // move the blockchain forward by a lot to see if awmatic balance increased, showing AAVE staking gains
        vm.warp(2992592767);
        //started at 2, now is 4 thanks to AAVE staking
        assert(aWmatic.balanceOf(address(governor)) == 4);
    }
}