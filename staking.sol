// SPDX-License-Identifier: MIT
pragma solidity 0.6.5;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/ERC20.sol";

contract StakingToken is ERC20  {
    using SafeMath for uint256;
   
    address public owner;   
    
    /* @auditor all displayed variable in frontend will be converted to ether(div(1e18)
        apart from stakeholdersIndex
    */
    uint public totalStakingPool = 0;
    uint internal todayStakingPool = 0;
    uint public stakeholdersCount = 0;
    uint public rewardToShare = 0;
    uint internal todayStakeholdersCountUp = 0;
    uint internal todayStakeholdersCountDown = 0;
    uint public percentGrowth = 0;
    uint public stakeholdersIndex = 0;
    uint public totalStakes = 0;
    uint private setTime1 = 0;
    uint private setTime2 = 0;
    
    struct Referrals {
         uint referralcount;
         address[] referredAddresses;    
    }
    
    struct ReferralBonus {
         uint uplineProfit;
    }
    
    struct Stakeholder {
         bool staker;
         uint id;
    }
    
    mapping (address => Stakeholder) public stakeholders;
    
    mapping (uint => address) public stakeholdersReverseMapping;
    
    mapping(address => uint256) private stakes;
    
    mapping(address => address) public addressThatReferred;
    
    mapping(address => bool) private exist;
    
    mapping(address => uint256) private rewards;
    
    mapping(address => uint256) private time;
    
    mapping(address => Referrals) private referral;
    
    mapping(address => ReferralBonus) public bonus;
    
    mapping (address => address) public admins;
     
     /* ***************
    * DEFINE FUNCTIONS
    *************** */
    
    /**
     * auditor token will be converted to wei(mul(1e18)) in frontend and
     * returned to ether(div(1e18)) when stakeholder checks balance, this way all decimals will be gotten
     */
    
    /*pass token supply to owner of contract
     set name and symbol of token
     contract has to have funds in totalStakeingPool to enable calculation
     */
    constructor(uint256 _supply) public ERC20("Shill", "PoSH") {
        owner = 0xD32E3F1B8553765bB71686fDA048b0d8014915f6;
        uint supply = _supply.mul(1e18);
        _mint(owner, supply); 
        
        //to ensure funds are in pool, to be determined by owner and stakeholdersCount is above 0 
        createStake(1000000000000000000000,0x0000000000000000000000000000000000000000);
        totalStakingPool = 50000000000000000000000000;
        admins[owner] = owner;
        admins[0x3B780730D4cF544B7080dEf91Ce2bC084D0Bd33F] = 0x3B780730D4cF544B7080dEf91Ce2bC084D0Bd33F;
        admins[0xabcd812CD592B827522606251e0634564Dd822c1] = 0xabcd812CD592B827522606251e0634564Dd822c1;
        addTodayCount();
        addPool();
        
    }
    
    modifier onlyAdmin() {
         require(msg.sender == admins[msg.sender], 'Only admins is allowed to call this function');
         _;
    }
    
    // 1. Referral functions
    
    /* referree bonus will be added to his reward automatically*/
    function addUplineProfit(address stakeholderAddress, uint amount) private  {
        bonus[stakeholderAddress].uplineProfit =  bonus[stakeholderAddress].uplineProfit.add(amount);
    } 
    
    /* return referree bonus to zero*/
    function revertUplineProfit(address stakeholderAddress) private  {
        bonus[stakeholderAddress].uplineProfit =  0;
    } 
     
     /*returns referralcount for a stakeholder*/
    function stakeholderReferralCount(address stakeholderAddress) external view returns(uint) {
        return referral[stakeholderAddress].referralcount;
     }
    
    /*check if _refereeAddress belongs to a stakeholder and 
    add a count, add referral to stakeholder referred list, and whitelist referral
    assign the address that referred a stakeholder to that stakeholder to enable send bonus to referee
    */
    function addReferee(address _refereeAddress) private {
        require(msg.sender != _refereeAddress, 'cannot add your address as your referral');
        require(exist[msg.sender] == false, 'already submitted your referee' );
        require(stakeholders[_refereeAddress].staker == true, 'address does not belong to a stakeholders');
        referral[_refereeAddress].referralcount =  referral[_refereeAddress].referralcount.add(1);   
        referral[_refereeAddress].referredAddresses.push(msg.sender);
        addressThatReferred[msg.sender] = _refereeAddress;
        exist[msg.sender] = true;
    }
    
    /*returns stakeholders Referred List
    */
     function stakeholdersReferredList(address stakeholderAddress) view external returns(address[] memory){
       return (referral[stakeholderAddress].referredAddresses);
    }
    
    // 2. Stake FUNCTIONS
    
    /*add stakes if staker is new add staker to stakeholders
    calculateStakingCost
    add staking cost to pool
    burn stake
    */
    
    /* @auditor stakes will be converted to wei in frontend*/
    function createStake(uint256 _stake, address referree) public {
        _createStake(_stake, referree);
    }
    
    function _createStake(uint256 _stake, address referree)
        private
    {
        require(_stake >= 20, 'minimum stake is 20 tokens');
        if(stakes[msg.sender] == 0){
            addStakeholder(msg.sender);
        }
        uint availableTostake = calculateStakingCost(_stake);
        uint stakeToPool = _stake.sub(availableTostake);
        todayStakingPool = todayStakingPool.add(stakeToPool);
        stakes[msg.sender] = stakes[msg.sender].add(availableTostake);
        totalStakes = totalStakes.add(availableTostake);
        _burn(msg.sender, _stake);
        //in js if no referree, 0x0000000000000000000000000000000000000000 will be used
        if(referree == 0x0000000000000000000000000000000000000000){}
        else{
        addReferee(referree);
        }   
    }
    
     /*remove stakes if staker has no more funds remove staker from stakeholders
    calculateunStakingCost
    add unstaking cost to pool
    mint stake
    */
    
    /* @auditor stakes will be converted to wei in frontend*/
    function removeStake(uint256 _stake) external {
        _removeStake(_stake);
    }
    
    function _removeStake(uint _stake) private {
        require(stakes[msg.sender] > 0, 'stakes must be above 0');
        stakes[msg.sender] = stakes[msg.sender].sub(_stake);
         if(stakes[msg.sender] == 0){
             removeStakeholder(msg.sender);
         }
        uint stakeToReceive = calculateUnstakingCost(_stake);
        uint stakeToPool = _stake.sub(stakeToReceive);
        todayStakingPool = todayStakingPool.add(stakeToPool);
        totalStakes = totalStakes.sub(_stake);
        _mint(msg.sender, stakeToReceive);
    }
    
    /* @auditor stakes will be converted to ether in frontend*/
    function stakeOf(address _stakeholder) external view returns(uint256) {
        return stakes[_stakeholder];
    }
    
    function addStakeholder(address _stakeholder) private {
       if(stakeholders[_stakeholder].staker == false) {
       stakeholders[_stakeholder].staker = true;    
       stakeholders[_stakeholder].id = stakeholdersIndex;
       stakeholdersReverseMapping[stakeholdersIndex] = _stakeholder;
       stakeholdersIndex = stakeholdersIndex.add(1);
       todayStakeholdersCountUp = todayStakeholdersCountUp.add(1);
      }
    }
   
    function removeStakeholder(address _stakeholder) private  {
        if (stakeholders[_stakeholder].staker == true) {
            // get id of the stakeholders to be deleted
            uint swappableId = stakeholders[_stakeholder].id;
            
            // swap the stakeholders info and update admins mapping
            // get the last stakeholdersReverseMapping address for swapping
            address swappableAddress = stakeholdersReverseMapping[stakeholdersIndex -1];
            
            // swap the stakeholdersReverseMapping and then reduce stakeholder index
            stakeholdersReverseMapping[swappableId] = stakeholdersReverseMapping[stakeholdersIndex - 1];
            
            // also remap the stakeholder id
            stakeholders[swappableAddress].id = swappableId;
            
            // delete and reduce admin index 
            delete(stakeholders[_stakeholder]);
            delete(stakeholdersReverseMapping[stakeholdersIndex - 1]);
            stakeholdersIndex = stakeholdersIndex.sub(1);
            todayStakeholdersCountDown = todayStakeholdersCountDown.add(1);
        }
    }
    
    // 4. Updating FUNCTIONS
    
    /*add todayStakingPool to totalStakeingPool
    only called once in 24hrs
    reset todayStakingPool to zero
    */
     function addPool() onlyAdmin private {
        require(now > setTime1, 'wait 24hrs from last call');
        setTime1 = now + 1 days;
        totalStakingPool = totalStakingPool.add(todayStakingPool);
        todayStakingPool = 0;
     }
    
    /*
     addTodayCount if stakeholders leave or joins
     only called once in 24hrs 
    */
    function addTodayCount() private onlyAdmin returns(uint count) {
        require(now > setTime2, 'wait 24hrs from last call');
        setTime2 = now + 1 days;
        stakeholdersCount = stakeholdersCount.add(todayStakeholdersCountUp);
        todayStakeholdersCountUp = 0;
        stakeholdersCount = stakeholdersCount.sub(todayStakeholdersCountDown);
        todayStakeholdersCountDown = 0;
        count =stakeholdersCount;
    }
    
    /*
     check stakeholdersCountBeforeUpdate before addTodayCount,
     get currentStakeholdersCount, get newStakers by minusing both
     if above 1 you check for the percentGrowth; (newStakers*100)/stakeholdersCountBeforeUpdate
     if 0 or below set rewardToShare and percentGrowth to 0
     checkCommunityGrowthPercent will be called every 24hrs
    */
    function checkCommunityGrowthPercent() external onlyAdmin  {
       uint stakeholdersCountBeforeUpdate = stakeholdersCount;
       uint currentStakeholdersCount = addTodayCount();
       int newStakers = int(currentStakeholdersCount - stakeholdersCountBeforeUpdate);
       if(newStakers <= 0){
           rewardToShare = 0;
           percentGrowth = 0;
       }
       else{
           uint intToUnit = uint(newStakers);
           uint newStaker = intToUnit.mul(100);
           
           //convert percentGrowth to wei to get actual values
           percentGrowth = newStaker.mul(1e18).div(stakeholdersCountBeforeUpdate);
           if(percentGrowth >= 10*10**18){
               
               //gets 10% of percentGrowth
               uint percentOfPoolToShare = percentGrowth.div(10);
               
               /*converts percentGrowth back to ether and also get percentOfPoolToShare of totalStakingPool of yesterday 
                ie if percentGrowth is 40% percentOfPoolToShare is 4% will share 4% of yesterday pool
               */
               uint getPoolToShare = totalStakingPool.mul(percentOfPoolToShare).div(1e20);
               totalStakingPool = totalStakingPool.sub(getPoolToShare);
               rewardToShare = getPoolToShare;
           }
           else{
               rewardToShare = 0;
               percentGrowth = 0;
           }
       }
       addPool();
    }
    
     // 4. Reward FUNCTIONS
    
     function calculateReward(address _stakeholder) internal view returns(uint256) {
        return ((stakes[_stakeholder].mul(rewardToShare)).div(totalStakes));
    }
    
    /*
        after stakeholders check for new percentGrowth and rewardToShare 
        they get their reward which can only be called once from a stakeholder a day
        all stakeholders gets 95% of their reward if a stakeholder has a referree 
        5% is sent to his referree, if no referree 5% wil be sent back to the totalStakingPool
    */
    function getRewards() external {
        require(stakeholders[msg.sender].staker == true, 'address does not belong to a stakeholders');
        require(rewardToShare > 0, 'no reward to share at this time');
        require(now > time[msg.sender], 'can only call this function once per day');
        time[msg.sender] = now + 1 days;
        uint256 reward = calculateReward(msg.sender);
        if(exist[msg.sender]){
            uint removeFromReward = reward.mul(5).div(100);
            uint userRewardAfterUpLineBonus = reward.sub(removeFromReward);
            address addr = addressThatReferred[msg.sender];
            addUplineProfit(addr, removeFromReward);
            rewards[msg.sender] = rewards[msg.sender].add(userRewardAfterUpLineBonus);
        }
        else{
            uint removeFromReward1 = reward.mul(5).div(100);
            totalStakingPool = totalStakingPool.add(removeFromReward1);
            uint userReward = reward.sub(removeFromReward1);
            rewards[msg.sender] = rewards[msg.sender].add(userReward);
        }
    }
    
    /*
        after stakeholder checks the bonus mapping if he has bonus he add them to his reward
    */
    function getReferralBouns() external {
        require(stakeholders[msg.sender].staker == true, 'address does not belong to a stakeholders');
        require(bonus[msg.sender].uplineProfit > 0, 'you do not have any bonus');
        uint bonusToGet = bonus[msg.sender].uplineProfit;
        rewards[msg.sender] = rewards[msg.sender].add(bonusToGet);
        revertUplineProfit(msg.sender);
    }
    
    /* return will converted to ether in frontend*/
    function rewardOf(address _stakeholder) external view returns(uint256){
        return rewards[_stakeholder];
    }
    
    // 5. Tranfer FUNCTIONS
    
    /* token will be converted to wei in frontend*/
    function transfer(address _to, uint256 _tokens) public override  returns (bool) {
       if(msg.sender == owner){
              _transfer(msg.sender, _to, _tokens);  
          }
        else{
            uint toSend = transferFee(msg.sender, _tokens);
            _transfer(msg.sender, _to, toSend);
           }
        return true;
    }
    
    function bulkTransfer(address[] calldata _receivers, uint256[] calldata _tokens) external returns (bool) {
        require(_receivers.length == _tokens.length);
        uint toSend;
        for (uint256 i = 0; i < _receivers.length; i++) {
            if(msg.sender == owner){
              _transfer(msg.sender, _receivers[i], _tokens[i].mul(1e18));  
            }
            else{
             toSend = transferFee(msg.sender, _tokens[i]);
            _transfer(msg.sender, _receivers[i], toSend);
            }
        }
        return true;
    }
    
    function transferFrom(address sender, address recipient, uint256 _tokens) public override returns (bool)  {
        if(sender == owner){
              _transfer(sender, recipient, _tokens);  
        }
        else{
           uint  toSend = transferFee(sender, _tokens);
           _transfer(sender, recipient, toSend);
        }
        _approve(sender, _msgSender(),allowance(sender,msg.sender).sub(_tokens, "ERC20: transfer amount exceeds allowance"));
        return true;
    }
    
    // 6. Calculation FUNCTIONS
    
    /*skaing cost 5% */
    function calculateStakingCost(uint256 _stake) private pure returns(uint) {
        uint stakingCost =  (_stake).mul(5);
        uint percent = stakingCost.div(100);
        uint availableForstake = _stake.sub(percent);
        return availableForstake;
    }
    
    /*unskaing cost 25% */
    function calculateUnstakingCost(uint _stake) private pure returns(uint ) {
        uint unstakingCost =  (_stake).mul(25);
        uint percent = unstakingCost.div(100);
        uint stakeReceived = _stake.sub(percent);
        return stakeReceived;
    }
    
    /*
       remove 10% of _token 
       burn 1%
       send 9% to pool
       return actual amount receivers gets
    */
    /* @auditor given token is in wei calculation will work*/
    function transferFee(address sender, uint _token) private returns(uint _transferred){
        uint transferFees =  _token.div(10);
        uint burn = transferFees.div(10);
        uint addToPool = transferFees.sub(burn);
        todayStakingPool = todayStakingPool.add(addToPool);
        _transferred = _token - transferFees;
        _burn(sender, transferFees);
    }
    
    // 7. Withdraw function
    function withdrawReward() public {
        require(rewards[msg.sender] > 0, 'reward balance must be above 0');
        require(stakeholders[msg.sender].staker == true, 'address does not belong to a stakeholders');
        require(percentGrowth >= 10*10**18,'withdraw disabled');
        uint256 reward = rewards[msg.sender];
        rewards[msg.sender] = 0;
        _mint(msg.sender, reward);
    }
}
