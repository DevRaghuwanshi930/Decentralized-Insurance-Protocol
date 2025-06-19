// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract Project {
    address public owner;
    uint256 public totalPremiumPool;
    uint256 public claimCounter;
    
    struct Policy {
        uint256 policyId;
        address policyholder;
        uint256 premiumAmount;
        uint256 coverageAmount;
        uint256 startTime;
        uint256 duration;
        bool isActive;
        string policyType;
    }
    
    struct Claim {
        uint256 claimId;
        uint256 policyId;
        address claimant;
        uint256 claimAmount;
        string description;
        bool isApproved;
        bool isPaid;
        uint256 claimTime;
    }
    
    mapping(uint256 => Policy) public policies;
    mapping(uint256 => Claim) public claims;
    mapping(address => uint256[]) public userPolicies;
    
    uint256 public nextPolicyId = 1;
    uint256 public nextClaimId = 1;
    
    event PolicyCreated(uint256 indexed policyId, address indexed policyholder, uint256 premiumAmount, uint256 coverageAmount);
    event ClaimSubmitted(uint256 indexed claimId, uint256 indexed policyId, address indexed claimant, uint256 claimAmount);
    event ClaimProcessed(uint256 indexed claimId, bool approved, uint256 payoutAmount);
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can perform this action");
        _;
    }
    
    modifier validPolicy(uint256 _policyId) {
        require(_policyId > 0 && _policyId < nextPolicyId, "Invalid policy ID");
        require(policies[_policyId].isActive, "Policy is not active");
        _;
    }
    
    constructor() {
        owner = msg.sender;
    }
    
    // Core Function 1: Purchase Insurance Policy
    function purchasePolicy(
        uint256 _coverageAmount,
        uint256 _duration,
        string memory _policyType
    ) external payable returns (uint256) {
        require(msg.value > 0, "Premium amount must be greater than 0");
        require(_coverageAmount > 0, "Coverage amount must be greater than 0");
        require(_duration > 0, "Duration must be greater than 0");
        require(_coverageAmount <= msg.value * 10, "Coverage amount too high for premium");
        
        uint256 policyId = nextPolicyId++;
        
        policies[policyId] = Policy({
            policyId: policyId,
            policyholder: msg.sender,
            premiumAmount: msg.value,
            coverageAmount: _coverageAmount,
            startTime: block.timestamp,
            duration: _duration,
            isActive: true,
            policyType: _policyType
        });
        
        userPolicies[msg.sender].push(policyId);
        totalPremiumPool += msg.value;
        
        emit PolicyCreated(policyId, msg.sender, msg.value, _coverageAmount);
        
        return policyId;
    }
    
    // Core Function 2: Submit Insurance Claim
    function submitClaim(
        uint256 _policyId,
        uint256 _claimAmount,
        string memory _description
    ) external validPolicy(_policyId) returns (uint256) {
        Policy storage policy = policies[_policyId];
        require(msg.sender == policy.policyholder, "Only policyholder can submit claim");
        require(block.timestamp <= policy.startTime + policy.duration, "Policy has expired");
        require(_claimAmount <= policy.coverageAmount, "Claim amount exceeds coverage");
        require(_claimAmount > 0, "Claim amount must be greater than 0");
        
        uint256 claimId = nextClaimId++;
        
        claims[claimId] = Claim({
            claimId: claimId,
            policyId: _policyId,
            claimant: msg.sender,
            claimAmount: _claimAmount,
            description: _description,
            isApproved: false,
            isPaid: false,
            claimTime: block.timestamp
        });
        
        claimCounter++;
        
        emit ClaimSubmitted(claimId, _policyId, msg.sender, _claimAmount);
        
        return claimId;
    }
    
    // Core Function 3: Process Claim (Admin Function)
    function processClaim(uint256 _claimId, bool _approve) external onlyOwner {
        require(_claimId > 0 && _claimId < nextClaimId, "Invalid claim ID");
        
        Claim storage claim = claims[_claimId];
        require(!claim.isPaid, "Claim already processed");
        
        claim.isApproved = _approve;
        
        if (_approve) {
            require(address(this).balance >= claim.claimAmount, "Insufficient contract balance");
            
            claim.isPaid = true;
            totalPremiumPool -= claim.claimAmount;
            
            payable(claim.claimant).transfer(claim.claimAmount);
            
            emit ClaimProcessed(_claimId, true, claim.claimAmount);
        } else {
            emit ClaimProcessed(_claimId, false, 0);
        }
    }
    
    // Utility Functions
    function getPolicyDetails(uint256 _policyId) external view returns (Policy memory) {
        return policies[_policyId];
    }
    
    function getClaimDetails(uint256 _claimId) external view returns (Claim memory) {
        return claims[_claimId];
    }
    
    function getUserPolicies(address _user) external view returns (uint256[] memory) {
        return userPolicies[_user];
    }
    
    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }
    
    function isPolicyActive(uint256 _policyId) external view returns (bool) {
        if (_policyId == 0 || _policyId >= nextPolicyId) return false;
        
        Policy memory policy = policies[_policyId];
        return policy.isActive && (block.timestamp <= policy.startTime + policy.duration);
    }
    
    // Emergency function to withdraw funds (only owner)
    function emergencyWithdraw() external onlyOwner {
        payable(owner).transfer(address(this).balance);
    }
}
