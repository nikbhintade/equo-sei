// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// Uncomment this line to use console.log
// import "hardhat/console.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "./interfaces/IDistribution.sol";
import "./interfaces/IStaking.sol";

contract LStaking is Ownable, AccessControl, ERC20Burnable, ReentrancyGuard {
    /// total amount staked with contract
    uint totalStakedTokens;

    /// total amount which is not staked yet and will be staked next epoch
    uint pendingStakeTokens;

    /// total amount which is not unstaked yet and will be staked next epoch
    uint pendingUnstakeTokens;

    /// struct for undelegation request
    struct UnstakeRequest {
        uint256 unstakeAmount;
        uint256 unstakedate;
    }

    /// struct for validator un/delegation
    struct ValidatorStakeInfo {
        address validatorAddress;
        uint256 amount;
    }

    /// array to track undelegation requests
    mapping(address => UnstakeRequest[]) unstakeRequests;

    /// BOT role for AccessControl
    bytes32 public constant DELEGATION_BOT_ROLE =
        keccak256("DELEGATION_BOT_ROLE");

    constructor() Ownable(msg.sender) ERC20("EQUO Staked SEI", "eqSEI") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /// public function for user to stake
    function stakeTokens() public payable nonReentrant {
        require(msg.value >= 0.1 ether, "InsufficientStakeAmount: min 0.1 SEI");
        pendingStakeTokens += msg.value;

        uint256 mintAmount = getExchangeRate() * msg.value;
        _mint(msg.sender, mintAmount);
    }

    /// public function for user to submit unstake request
    function requestUnstake(uint256 amount) public nonReentrant {
        require(amount >= 0.1 ether, "InsufficientUnstakeAmount: min 0.1 SEI");

        uint256 withdrawAmount = amount / getExchangeRate();
        uint256 unlockTime = block.timestamp + 21 days + 2 hours;

        UnstakeRequest memory request = UnstakeRequest(amount, unlockTime);

        pendingUnstakeTokens += withdrawAmount;

        unstakeRequests[msg.sender].push(request);

        burnFrom(msg.sender, amount);
    }

    /// bot function to undelegate tokens based on request of the users on hourly basis
    function processUnstakeRequests(
        ValidatorStakeInfo[] calldata _validators
    ) public onlyRole(DELEGATION_BOT_ROLE) {
        for (uint i = 0; i < _validators.length; i++) {
            STAKING_CONTRACT.undelegate(
                Strings.toHexString(_validators[i].validatorAddress),
                _validators[i].amount
            );
        }
    }

    /// bot function for delegating staked tokens to different validators
    function delegateToValidators(
        ValidatorStakeInfo[] calldata _validators
    ) public onlyRole(DELEGATION_BOT_ROLE) {
        for (uint i = 0; i < _validators.length; i++) {
            STAKING_CONTRACT.delegate(
                Strings.toHexString(_validators[i].validatorAddress)
            );
        }
    }

    /// bot function for redelegating staked token from one validator to other validator
    function redelegateTokens(
        ValidatorStakeInfo[] calldata _validators
    ) public onlyRole(DELEGATION_BOT_ROLE) {}

    /// withdraw processed unstake request
    function withdrawUnstakedTokens() public returns (bool) {}

    /// function to set the address of the bot
    function setDelegationBotAddress() public view onlyOwner returns (uint) {}

    /// function that returns exchange rate of the LST
    function getExchangeRate() public view returns (uint) {
        return totalStakedTokens / totalSupply();
    }
}
