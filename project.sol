// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title SurveyRewards
 * @dev Contract for managing and distributing rewards for user satisfaction surveys
 */
contract SurveyRewards is Ownable, ReentrancyGuard {
    IERC20 public rewardToken;
    
    struct Survey {
        uint256 rewardAmount;
        bool isActive;
        mapping(address => bool) hasParticipated;
    }
    
    mapping(uint256 => Survey) public surveys;
    uint256 public surveyCount;
    
    event SurveyCreated(uint256 indexed surveyId, uint256 rewardAmount);
    event RewardClaimed(uint256 indexed surveyId, address indexed user, uint256 amount);
    event SurveyStatusChanged(uint256 indexed surveyId, bool isActive);
    event RewardTokenSet(address indexed tokenAddress);

    constructor() Ownable(msg.sender) {}
    
    /**
     * @dev Sets the reward token address
     * @param _tokenAddress Address of the ERC20 token to be used for rewards
     */
    function setRewardToken(address _tokenAddress) external onlyOwner {
        require(_tokenAddress != address(0), "Invalid token address");
        rewardToken = IERC20(_tokenAddress);
        emit RewardTokenSet(_tokenAddress);
    }
    
    /**
     * @dev Creates a new survey with specified reward amount
     * @param _rewardAmount Amount of tokens to reward for each survey completion
     */
    function createSurvey(uint256 _rewardAmount) external onlyOwner {
        require(_rewardAmount > 0, "Reward amount must be greater than 0");
        require(address(rewardToken) != address(0), "Reward token not set");
        
        uint256 surveyId = surveyCount++;
        Survey storage newSurvey = surveys[surveyId];
        newSurvey.rewardAmount = _rewardAmount;
        newSurvey.isActive = true;
        
        emit SurveyCreated(surveyId, _rewardAmount);
    }
    
    /**
     * @dev Submits survey response and claims reward
     * @param _surveyId ID of the survey being completed
     * @param _responseHash IPFS hash of the survey response
     */
    function submitSurveyAndClaimReward(
        uint256 _surveyId,
        string calldata _responseHash
    ) external nonReentrant {
        require(address(rewardToken) != address(0), "Reward token not set");
        Survey storage survey = surveys[_surveyId];
        require(survey.isActive, "Survey is not active");
        require(!survey.hasParticipated[msg.sender], "Already participated");
        require(bytes(_responseHash).length > 0, "Response hash required");
        
        uint256 rewardAmount = survey.rewardAmount;
        require(
            rewardToken.balanceOf(address(this)) >= rewardAmount,
            "Insufficient reward balance"
        );
        
        survey.hasParticipated[msg.sender] = true;
        require(
            rewardToken.transfer(msg.sender, rewardAmount),
            "Reward transfer failed"
        );
        
        emit RewardClaimed(_surveyId, msg.sender, rewardAmount);
    }
    
    /**
     * @dev Toggles the active status of a survey
     * @param _surveyId ID of the survey to toggle
     * @param _isActive New active status
     */
    function toggleSurveyStatus(uint256 _surveyId, bool _isActive) external onlyOwner {
        require(_surveyId < surveyCount, "Invalid survey ID");
        surveys[_surveyId].isActive = _isActive;
        emit SurveyStatusChanged(_surveyId, _isActive);
    }
    
    /**
     * @dev Withdraws any remaining tokens from the contract
     * @param _amount Amount of tokens to withdraw
     */
    function withdrawTokens(uint256 _amount) external onlyOwner {
        require(address(rewardToken) != address(0), "Reward token not set");
        require(
            rewardToken.transfer(owner(), _amount),
            "Token withdrawal failed"
        );
    }
    
    /**
     * @dev Checks if a user has participated in a specific survey
     * @param _surveyId Survey ID to check
     * @param _user Address of the user to check
     * @return bool indicating if user has participated
     */
    function hasParticipated(uint256 _surveyId, address _user)
        external
        view
        returns (bool)
    {
        return surveys[_surveyId].hasParticipated[_user];
    }
}