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

    //     function testDepositAndWithdraw() public {
    //         vm.createSelectFork(vm.envString("ETH_RPC_URL"), 32821975);

    //         governor = new Governor(30, 0x794a61358D6845594F94dc1DB02A252b5b4814aD);

    //         vm.startPrank(0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270);

    //         wmatic.approve(address(governor), 10);
    //         uint256 myAllowance = wmatic.allowance(
    //             address(0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270),
    //             address(governor)
    //         );
    //         assert(myAllowance == 10);

    //         //Check that the course isn't staked yet
    //         assert(governor.totalStaked() == 0);
    //         assert(governor.courseStaked(0) == false);

    //         //Stake 1 WMATIC for courseId 0
    //         governor.teacherStaking(0);
    //         assert(governor.totalStaked() == 1);
    //         assert(governor.courseStaked(0) == true);

    //         //Withdraw the funds, course is now not valid, totalStaked back to 0
    //         governor.teacherWithdraw(0);
    //         assert(governor.totalStaked() == 0);
    //         assert(governor.courseStaked(0) == false);
    //     }

    // function testChainlinkKeeper() public {
    //     vm.createSelectFork(vm.envString("ETH_RPC_URL"), 32821975);

    //     governor = new Governor(30, 0x794a61358D6845594F94dc1DB02A252b5b4814aD);

    //     vm.startPrank(0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270);

    //     wmatic.approve(address(governor), 50);

    //     governor.teacherStaking(0);
    //     governor.teacherStaking(1);
    //     governor.teacherStaking(2);
    //     governor.teacherStaking(3);
    //     governor.teacherStaking(4);
    //     governor.teacherStaking(5);
    //     governor.teacherStaking(6);
    //     governor.teacherStaking(7);

    //     assertEq(wmatic.balanceOf(address(governor)), 8);

    //     vm.stopPrank();

    //     assert(governor.checkUpkeep("") == false);

    //     //Doesn't deposit to AAVE since balance < minReserve
    //     assert(wmatic.balanceOf(address(governor)) == 8);
    //     assert(aWmatic.balanceOf(address(governor)) == 0);

    //     vm.warp(1662592767);
    //     assert(governor.checkUpkeep("") == true);

    //     //Deposit 3 wmatic to AAVE since governor balance was > than minReserve
    //     governor.performUpkeep("");
    //     assertEq(wmatic.balanceOf(address(governor)), 5);
    //     assertEq(aWmatic.balanceOf(address(governor)), 3);

    //     //Testing reward increase
    //     vm.warp(1992592767);
    //     governor.performUpkeep("");
    //     console.log("Start Bal", aWmatic.balanceOf(address(governor)));

    //     vm.warp(2992592767);
    //     governor.performUpkeep("");
    //     console.log("After bal", aWmatic.balanceOf(address(governor)));

    //     // assert(aWmatic.balanceOf(address(governor)) == 0);
    //     // assert(wmatic.balanceOf(address(governor)) == 8);
    // }

    function testAccessControlTeacher() public {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), 32821975);

        sbt = new SBT("myURLAddress");
        governor = new Governor(30, address(sbt));
        address wMaticOwner = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;

        assert(sbt.isEducator(wMaticOwner) == false);
        sbt.addEducator(wMaticOwner);
        assert(sbt.isEducator(wMaticOwner) == true);

        sbt.setGovernor(address(governor));

        vm.startPrank(wMaticOwner);

        wmatic.approve(address(governor), 10000);
        assert(sbt.getTestEducator(0) == address(0));
        assert(governor.courseStaked(0) == false);
        assert(wmatic.balanceOf(address(governor)) == 0);
        sbt.createSBT(1, "myStringTest");
        assert(sbt.getTestEducator(0) == wMaticOwner);
        assert(governor.courseStaked(0) == true);
        assert(wmatic.balanceOf(address(governor)) == 1);

        sbt.createSBT(1, "BJYq5rIpyBWkXErKfsXAgDNx");
        sbt.createSBT(1, "BJYq5rIpyBWkXErKfsXAgDN");
        sbt.createSBT(1, "BJYq5rIpyBWkXErKfsXAgDNxX");
        sbt.createSBT(1, "BJYq5rIpyBWkXErKfsXAgDNxsa");
        sbt.createSBT(1, "BJYq5rIpyBWkXErKfsXAgDNxasdaw");
        sbt.createSBT(1, "BJYq5rIpyBWkXErKfsXAgDNxadwad");

        assert(wmatic.balanceOf(address(governor)) == 7);
        assert(aWmatic.balanceOf(address(governor)) == 0);

        assert(governor.checkUpkeep("") == false);

        vm.warp(1662592767);
        assert(governor.checkUpkeep("") == true);
        governor.performUpkeep("");
        assert(wmatic.balanceOf(address(governor)) == 5);
        assert(aWmatic.balanceOf(address(governor)) == 2);

        vm.stopPrank();

        //Expect that next call will fail since current address is not an educator
        vm.expectRevert(abi.encodePacked("Not an educator"));
        sbt.createSBT(1, "myStringTest");

        //Expect next call will fail since calling governor's function directly and not passing though SBT contract
        vm.expectRevert(abi.encodePacked("Not SBT contract"));
        governor.teacherStaking(0, 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270);

        //Test course withdrawal
        assert(governor.courseStaked(5) == true);
        vm.startPrank(wMaticOwner);

        sbt.withdrawCourse(5);
        assert(governor.courseStaked(5) == false);
        assert(wmatic.balanceOf(address(governor)) == 4);
    }
}

//NOTE: testDepositToAAVE() and testWithdrawFromAAVE() now irrelevent since aaveSupply became internal. Only the chainlink keeper can access it

// function testDepositToAAVE() public {
//     vm.createSelectFork(vm.envString("ETH_RPC_URL"), 32821975);

//     governor = new Governor(30);

//     vm.startPrank(0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270);

//     wmatic.approve(address(governor), 10);
//     uint256 myAllowance = wmatic.allowance(
//         address(0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270),
//         address(governor)
//     );
//     assert(myAllowance == 10);

//     //Check that the course isn't staked yet
//     assert(governor.totalStaked() == 0);
//     assert(governor.courseStaked(0) == false);

//     //Stake 1 WMATIC for courseId 0
//     governor.teacherStaking(0);
//     assert(governor.totalStaked() == 1);
//     assert(governor.courseStaked(0) == true);

//     governor.teacherStaking(1);
//     assert(governor.totalStaked() == 2);
//     assert(governor.courseStaked(1) == true);

//     assert(governor.getGovernorWMaticBalance() == 2);

//     vm.stopPrank();

//     //Check governor has 0 awmatic, then do aave supply, and check again for awmatic
//     assert(aWmatic.balanceOf(address(governor)) == 0);

//     governor.aaveDeposit(wmatic.balanceOf(address(governor)));

//     assert(governor.getGovernorWMaticBalance() == 0);

//     assert(aWmatic.balanceOf(address(governor)) == 2);
// }

// function testWithdrawFromAAVE() public {
//     vm.createSelectFork(vm.envString("ETH_RPC_URL"), 32821975);

//     governor = new Governor(30);

//     vm.startPrank(0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270);

//     wmatic.approve(address(governor), 10);
//     uint256 myAllowance = wmatic.allowance(
//         address(0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270),
//         address(governor)
//     );

//     governor.teacherStaking(0);
//     governor.teacherStaking(1);

//     assert(governor.getGovernorWMaticBalance() == 2);

//     vm.stopPrank();

//     governor.aaveDeposit(wmatic.balanceOf(address(governor)));
//     assert(aWmatic.balanceOf(address(governor)) == 2);

//     governor.aaveWithdraw(2);
//     assert(wmatic.balanceOf(address(governor)) == 2);
//     assert(aWmatic.balanceOf(address(governor)) == 0);
// }
