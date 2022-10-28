// SPDX-License-Identifier: MIT (OUTDATED)
pragma solidity ^0.8.14;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interface/IGovernor.sol";

/**
 * @title NFTeach
 * @author olivierdem
 * @notice Allows Educators to upload course/test content for students to view, and a token for students to mint upon completion.
 */
contract SBT is ERC1155, Ownable {
    IGovernor public governor;

    /* -------------------------------------------------------------------------- */
    /*                                   EVENTS                                   */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice emitted when a new educator is added
     * @param educator address of the new educator
     */
    event AddEducator(address educator);

    /**
     * @notice emitted when a new student is added
     * @param student address of the new student
     */
    event AddStudent(address student);

    /**
     * @notice emited when new test is created
     * @param tokenId Id of the new test and corresponding token
     * @param educator address of the educator who creates the test
     * @param mintPrice price of minting the SBT after test completion
     */
    event CreateSBT(
        uint256 tokenId,
        address educator,
        uint256 mintPrice,
        string courseObjectId
    );

    /**
     * @notice emited when an educator validates a students completion of a test
     * @param tokenId id of the test and corresponding token
     * @param student address of the student which completed the test
     */
    event ValidateTest(uint256 tokenId, address student);

    /**
     * @notice emitted when SBT is minted by a student
     * @param tokenId Id of the test and corresponding token
     * @param student address of the student which completed the test
     */
    event MintSBT(uint256 tokenId, address student);

    /**
     * @notice emitted when an educator withdraws their payoff
     * @param educator address of the withdrawing educator
     * @param amount total amount of payoff withdrawn by educator
     */
    event Withdrawl(address educator, uint256 amount);

    /* -------------------------------------------------------------------------- */
    /*                               Structures                                   */
    /* -------------------------------------------------------------------------- */

    //Test object that keeps track of Educator's address, test hash, lifetime payout from students,
    //price to mint SBT, number of students that passed the test.

    /**
     * @dev Test struct to represent the test associated with each SBT
     * @param educator address of the educator which created the test
     * @param lifetimePayout total amount of funds collected from students minting tokens
     * @param price price to mint SBT after completion of associated test; set by educator
     * @param nbCompleted the number of students who have completed the test
     */
    struct Test {
        address educator;
        uint256 lifetimePayout;
        uint256 price;
        uint256 nbCompleted;
        uint256 staked;
        bool active;
        bool slashed;
    }

    /**
     * @dev Student struct to keep track of each student's information
     * @param classCompleted the number of classes the student has completed
     * @param sbtMinted the number of SBTs the student has minted
     * @param allowedMint mapping to track which SBTs the student can mint
     */
    struct Student {
        uint8 classCompleted;
        uint8 sbtMinted;
        mapping(uint256 => bool) allowedMint;
        bool active;
    }

    /**
     * @dev Educator struct to keep track of each educator's information
     * @param lifetimePayout the total amount of funds the educator has accumulated
     * @param classesCreated the number of classes the educator has created
     */
    struct Educator {
        uint256 lifetimePayout;
        uint256 classesCreated;
        uint256 nbStudentsMinted;
        bool active;
    }

    /* -------------------------------------------------------------------------- */
    /*                             STATE VARIABLES                                */
    /* -------------------------------------------------------------------------- */

    uint256 public stakingRequired = 0.0001 ether;
    // Incrementing tokenId
    uint256 public counterIDs;

    /* -------------------------------------------------------------------------- */
    /*                                 MAPPINGS                                   */
    /* -------------------------------------------------------------------------- */

    // Mapping from tokenId to the educator address which created it
    mapping(uint256 => address) public tokenIdToEducatorAddress;
    // Mapping from tokenId to Test struct
    mapping(uint256 => Test) public tests;
    // Mapping from address to the balance owed to each educator
    mapping(address => uint256) public payout;
    // Mapping from address to Educator struct
    mapping(address => Educator) public educators;
    // Mapping from address to Student struct
    mapping(address => Student) students;

    /* -------------------------------------------------------------------------- */
    /*                                 MODIFIERS                                  */
    /* -------------------------------------------------------------------------- */

    modifier onlyEducator() {
        require(educators[msg.sender].active == true, "Not an educator");
        _;
    }

    modifier onlyStudent() {
        require(students[msg.sender].active == true, "Not a student");
        _;
    }

    /* -------------------------------------------------------------------------- */
    /*                                 CONSTRUCTOR                                */
    /* -------------------------------------------------------------------------- */

    constructor(string memory _uri) ERC1155(_uri) {}

    /* -------------------------------------------------------------------------- */
    /*                             EXTERNAL FUNCTIONS                             */
    /* -------------------------------------------------------------------------- */

    function setURI(string memory newURI) external onlyOwner {
        _setURI(newURI);
    }

    function setGovernor(address _governor) external onlyOwner {
        governor = IGovernor(_governor);
    }

    /**
     * @dev Called whenever a new educator is created
     */
    function addEducator(address _newEducator) external onlyOwner {
        require(
            educators[_newEducator].active == false,
            "Educator already exists"
        );

        educators[_newEducator].active = true;

        emit AddEducator(_newEducator);
    }

    /**
     * @dev Called whenever a new student is created
     */
    function addStudent(address _newStudent) public onlyOwner {
        require(
            students[_newStudent].active == false,
            "Student already exists"
        );

        students[_newStudent].active = true;

        emit AddStudent(_newStudent);
    }

    /**
     * @dev Called whenever a new test and corresponding token are created
     * @param _price educator set price to mintSBT after test completion
     */
    function createSBT(uint256 _price, string calldata _courseObjectId)
        external
        onlyEducator
    {
        //sends the staked ETH to the governor contract for staking operations
        governor.teacherStaking(counterIDs, msg.sender);
        tests[counterIDs] = Test(msg.sender, 0, _price, 0, 1, true, false);
        educators[msg.sender].classesCreated += 1;

        emit CreateSBT(counterIDs, msg.sender, _price, _courseObjectId);

        counterIDs += 1;
    }

    /**
     * @dev Called whenever a student completes a test, validated by owner
     */
    function validateStudentTest(address _student, uint256 _tokenId)
        public
        onlyOwner
    {
        require(tests[_tokenId].educator != address(0), "Token doesn't exist");
        require(
            balanceOf(_student, _tokenId) == 0,
            "Student already has this token"
        );
        require(
            students[_student].allowedMint[_tokenId] == false,
            "Student already allowed to mint"
        );

        // Increment the number of times the test has been completed
        tests[_tokenId].nbCompleted += 1;
        // Increment the number of classes the student has completed
        students[_student].classCompleted += 1;
        // Allow the student to mint the token
        students[_student].allowedMint[_tokenId] = true;

        emit ValidateTest(_tokenId, _student);
    }

    /**
     * @dev Called whenever a student mints a token after completion of the corresponding test
     */
    function mintSBT(uint256 _tokenId) public payable onlyStudent {
        // Student must have permission to mint the token
        require(
            students[msg.sender].allowedMint[_tokenId],
            "Student is not allowed to mint this token"
        );
        require(
            msg.value == tests[_tokenId].price || tests[_tokenId].price == 0,
            "Incorrect amount"
        );
        require(
            tests[_tokenId].active && !tests[_tokenId].slashed,
            "This course isn't available"
        );

        // Track how much is owed to the educator
        payout[tests[_tokenId].educator] += tests[_tokenId].price;

        // Prevent students from minting twice
        students[msg.sender].allowedMint[_tokenId] = false;
        students[msg.sender].sbtMinted += 1;
        educators[tests[_tokenId].educator].nbStudentsMinted += 1;

        _mint(msg.sender, _tokenId, 1, "");

        emit MintSBT(_tokenId, msg.sender);
    }

    /**
     * @dev Called whenever an educator withdraws the funds accumulated from token mints
     */
    function withdrawCoursesPayoff() public onlyEducator {
        require(payout[msg.sender] > 0, "No funds left to withdraw");
        uint256 leftToPay = payout[msg.sender];
        educators[msg.sender].lifetimePayout += leftToPay;
        payout[msg.sender] = 0;

        (bool success, ) = address(payable(msg.sender)).call{value: leftToPay}(
            ""
        );
        require(success, "Call failed");

        emit Withdrawl(msg.sender, leftToPay);
    }

    function withdrawCourse(uint256 _tokenId) public onlyEducator {
        require(tests[_tokenId].active, "Course already deactivated");
        require(tests[_tokenId].staked > 0, "Course has no stake");
        require(msg.sender == tests[_tokenId].educator, "Not your course");

        governor.teacherWithdraw(_tokenId, msg.sender);
    }

    /* -------------------------------------------------------------------------- */
    /*                                  Getters                                   */
    /* -------------------------------------------------------------------------- */

    /// @return whether an address is an educator
    function isEducator(address _address) public view returns (bool) {
        return (educators[_address].active);
    }

    /// @return whether an address is a student
    function isStudent(address _address) public view returns (bool) {
        return (students[_address].active);
    }

    /// @return the number of classes an educator has created
    function nbClassesCreated(address _educator) public view returns (uint256) {
        return (educators[_educator].classesCreated);
    }

    /// @return the number of classes a student has completed
    function nbClassesCompleted(address _student)
        public
        view
        returns (uint256)
    {
        return (students[_student].classCompleted);
    }

    /// @return the educator of a test
    function getTestEducator(uint256 _tokenId) public view returns (address) {
        return (tests[_tokenId].educator);
    }

    /// @return the current amount owed to the educator on the contract
    function getEducatorCurrentPayout(address _educator)
        public
        view
        returns (uint256)
    {
        return (payout[_educator]);
    }

    /// @return the number of times a test has been completed
    function nbTestCompletions(uint256 _tokenId) public view returns (uint256) {
        return (tests[_tokenId].nbCompleted);
    }

    /// @return whether a student is allowed to mint a token
    function isAllowedMint(address _student, uint256 _tokenId)
        public
        view
        returns (bool)
    {
        return (students[_student].allowedMint[_tokenId]);
    }

    /// @return the number of tokens a student has minted
    function nbMinted(address _student) public view returns (uint256) {
        return (students[_student].sbtMinted);
    }

    function getEducatorNbMinted(address _educator)
        public
        view
        returns (uint256)
    {
        return (educators[_educator].nbStudentsMinted);
    }

    function getEducatorLifetimePayout(address _educator)
        public
        view
        returns (uint256)
    {
        return (educators[_educator].lifetimePayout);
    }
}

/*
 *  Constructor Uri
 *  https://gateway.moralisipfs.com/ipfs/
 */
