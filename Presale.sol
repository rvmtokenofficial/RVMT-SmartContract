/**
 *Submitted for verification at BscScan.com on 2024-05-14
 */

//SPDX-License-Identifier: MIT Licensed
pragma solidity ^0.8.25;

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _transferOwnership(_msgSender());
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(
            newOwner != address(0),
            "Ownable: new owner is the zero address"
        );
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

interface IERC20 {
    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);

    function totalSupply() external view returns (uint256);

    function balanceOf(address owner) external view returns (uint256);

    function allowance(
        address owner,
        address spender
    ) external view returns (uint256);

    function approve(address spender, uint256 value) external;

    function transfer(address to, uint256 value) external;

    function transferFrom(address from, address to, uint256 value) external;

    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
    event Transfer(address indexed from, address indexed to, uint256 value);
}

interface AggregatorV3Interface {
    function decimals() external view returns (uint8);

    function description() external view returns (string memory);

    function version() external view returns (uint256);

    function getRoundData(
        uint80 _roundId
    )
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );

    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );
}

contract Presale is Ownable {
    IERC20 public mainToken;
    IERC20 public USDT = IERC20(0x55d398326f99059fF775485246999027B3197955);

    AggregatorV3Interface public priceFeed;

    struct Phase {
        uint256 endTime;
        uint256 tokensToSell;
        uint256 totalSoldTokens;
        uint256 tokenPerUsdPrice;
    }
    mapping(uint256 => Phase) public phases;

    // Stats
    uint256 public totalStages;
    uint256 public currentStage;
    uint256 public soldToken;
    uint256 public referralTokens;
    uint256 public amountRaised;
    uint256 public amountRaisedUSDT;
    uint256 public uniqueBuyers;

    address payable public fundReceiver;

    bool public presaleStatus;
    bool public isPresaleEnded;
    uint256 public claimStartTime;

    //referral
    uint256 public referral_percentage = 10;

    address[] UsersAddresses;
    struct User {
        uint256 native_balance;
        uint256 usdt_balance;
        uint256 token_balance;
        uint256 claimed_tokens;
        uint256 referrals;
        uint256 referral_balance;
    }

    uint256[] public tokensToSell = [
        800000000000000000,
        1120000000000000000,
        1200000000000000000,
        1130000000000000000,
        1000000000000000000,
        750000000000000000
    ];
    uint256[] public endTimestamps = [
        1718323199,
        1720915199,
        1725235199,
        1729555199,
        1734307199,
        1738195199
    ];
    uint256[] public tokenPerUsdPrice = [
        335570400000,
        235294100000,
        168067200000,
        118623900000,
        84033600000,
        52493400000
    ];

    mapping(address => User) public users;
    mapping(address => bool) public isExist;

    event BuyToken(address indexed _user, uint256 indexed _amount);
    event ClaimToken(address indexed _user, uint256 indexed _amount);
    event UpdatePrice(uint256 _oldPrice, uint256 _newPrice);

    constructor(IERC20 _token) {
        require(
            tokensToSell.length == endTimestamps.length &&
                endTimestamps.length == tokenPerUsdPrice.length,
            "tokens and duration length mismatch"
        );
        mainToken = _token;
        fundReceiver = payable(0x6E036670ABF92b9Ce86Da521eBFf07A93EA9aec2);
        priceFeed = AggregatorV3Interface(
            0x0567F2323251f0Aab15c8dFb1967E4e8A7D42aeE
        );

        for (uint256 i = 0; i < tokensToSell.length; i++) {
            phases[i].endTime = endTimestamps[i];
            phases[i].tokensToSell = tokensToSell[i];
            phases[i].tokenPerUsdPrice = tokenPerUsdPrice[i];
        }
        totalStages = tokensToSell.length;
    }

    // to get real time price of Eth
    function getLatestPrice() public view returns (uint256) {
        (, int256 price, , , ) = priceFeed.latestRoundData();
        return uint256(price);
    }

    // to buy token during preSale time with Eth => for web3 use
    function buyToken() public payable {
        require(!isPresaleEnded, "Presale ended!");
        require(presaleStatus, " Presale is Paused, check back later");
        if (!isExist[msg.sender]) {
            isExist[msg.sender] = true;
            uniqueBuyers++;
            UsersAddresses.push(msg.sender);
        }
        fundReceiver.transfer(msg.value);
        // Check active phase
        uint256 activePhase = activePhaseInd();
        if (activePhase != currentStage) {
            currentStage = activePhase;
        }

        uint256 numberOfTokens;
        numberOfTokens = nativeToToken(msg.value, activePhase);
        require(
            phases[currentStage].totalSoldTokens + numberOfTokens <=
                phases[currentStage].tokensToSell,
            "Phase Limit Reached"
        );
        soldToken = soldToken + (numberOfTokens);
        amountRaised = amountRaised + (msg.value);

        users[msg.sender].native_balance =
            users[msg.sender].native_balance +
            (msg.value);
        users[msg.sender].token_balance =
            users[msg.sender].token_balance +
            (numberOfTokens);
        phases[currentStage].totalSoldTokens += numberOfTokens;
    }

    // to buy token during preSale time with USDT => for web3 use
    function buyTokenUSDT(uint256 amount) public {
        require(!isPresaleEnded, "Presale ended!");
        require(presaleStatus, " Presale is Paused, check back later");
        if (!isExist[msg.sender]) {
            isExist[msg.sender] = true;
            uniqueBuyers++;
            UsersAddresses.push(msg.sender);
        }
        USDT.transferFrom(msg.sender, fundReceiver, amount);
        // Check active phase
        uint256 activePhase = activePhaseInd();
        if (activePhase != currentStage) {
            currentStage = activePhase;
        }

        uint256 numberOfTokens;
        numberOfTokens = usdtToToken(amount, activePhase);
        require(
            phases[currentStage].totalSoldTokens + numberOfTokens <=
                phases[currentStage].tokensToSell,
            "Phase Limit Reached"
        );
        soldToken = soldToken + numberOfTokens;
        amountRaisedUSDT = amountRaisedUSDT + amount;

        users[msg.sender].usdt_balance += amount;

        users[msg.sender].token_balance =
            users[msg.sender].token_balance +
            numberOfTokens;
        phases[currentStage].totalSoldTokens += numberOfTokens;
    }

    //Referral Methods

    // to buy token with referral during preSale time with Eth => for web3 use
    function buyTokenReferral(address referrer) public payable {
        require(!isPresaleEnded, "Presale ended!");
        require(presaleStatus, " Presale is Paused, check back later");
        //check if referred user purchased tokens or not in the platform
        //require(isExist[referrer], " Referred User is not a participant");
        User storage referreduser = users[referrer];
        if (!isExist[msg.sender]) {
            isExist[msg.sender] = true;
            uniqueBuyers++;
            UsersAddresses.push(msg.sender);
            referreduser.referrals++;
        }
        fundReceiver.transfer(msg.value);
        // Check active phase
        uint256 activePhase = activePhaseInd();
        if (activePhase != currentStage) {
            currentStage = activePhase;
        }

        uint256 numberOfTokens;
        uint256 refnumberOfTokens;
        numberOfTokens = nativeToToken(msg.value, activePhase);
        refnumberOfTokens = (numberOfTokens * referral_percentage) / 100;
        require(
            phases[currentStage].totalSoldTokens +
                numberOfTokens +
                refnumberOfTokens <=
                phases[currentStage].tokensToSell,
            "Phase Limit Reached"
        );
        soldToken = soldToken + (numberOfTokens);
        referralTokens = referralTokens + (refnumberOfTokens);
        amountRaised = amountRaised + (msg.value);

        users[msg.sender].native_balance =
            users[msg.sender].native_balance +
            (msg.value);
        users[msg.sender].token_balance =
            users[msg.sender].token_balance +
            (numberOfTokens);
        //referred user balance updation
        referreduser.referral_balance =
            referreduser.referral_balance +
            (refnumberOfTokens);
        referreduser.token_balance =
            referreduser.token_balance +
            (refnumberOfTokens);
        phases[currentStage].totalSoldTokens += (numberOfTokens +
            refnumberOfTokens);
    }

    // to buy token with referral during preSale time with USDT => for web3 use
    function buyTokenUSDTReferral(address referrer, uint256 amount) public {
        require(!isPresaleEnded, "Presale ended!");
        require(presaleStatus, " Presale is Paused, check back later");
        //check if referred user purchased tokens or not in the platform
        //require(isExist[referrer], " Referred User is not a participant");
        User storage referreduser = users[referrer];
        if (!isExist[msg.sender]) {
            isExist[msg.sender] = true;
            uniqueBuyers++;
            UsersAddresses.push(msg.sender);
            referreduser.referrals++;
        }
        USDT.transferFrom(msg.sender, fundReceiver, amount);
        // Check active phase
        uint256 activePhase = activePhaseInd();
        if (activePhase != currentStage) {
            currentStage = activePhase;
        }

        uint256 numberOfTokens;
        uint256 refnumberOfTokens;
        numberOfTokens = usdtToToken(amount, activePhase);
        refnumberOfTokens = (numberOfTokens * referral_percentage) / 100;
        require(
            phases[currentStage].totalSoldTokens +
                numberOfTokens +
                refnumberOfTokens <=
                phases[currentStage].tokensToSell,
            "Phase Limit Reached"
        );
        soldToken = soldToken + numberOfTokens;
        referralTokens = referralTokens + (refnumberOfTokens);
        amountRaisedUSDT = amountRaisedUSDT + amount;

        users[msg.sender].usdt_balance += amount;

        users[msg.sender].token_balance =
            users[msg.sender].token_balance +
            numberOfTokens;
        //referred user balance updation
        referreduser.referral_balance =
            referreduser.referral_balance +
            (refnumberOfTokens);
        referreduser.token_balance =
            referreduser.token_balance +
            (refnumberOfTokens);
        phases[currentStage].totalSoldTokens += (numberOfTokens +
            refnumberOfTokens);
    }

    function claimTokens() external {
        require(isPresaleEnded, "Presale has not ended yet");
        require(isExist[msg.sender], "User don't exist");
        User storage user = users[msg.sender];
        require(user.token_balance > 0, "No tokens purchased");
        uint256 claimableTokens = user.token_balance - user.claimed_tokens;
        require(claimableTokens > 0, "No tokens to claim");
        user.claimed_tokens += claimableTokens;
        mainToken.transferFrom(owner(), msg.sender, claimableTokens);
        emit ClaimToken(msg.sender, claimableTokens);
    }

    function activePhaseInd() public view returns (uint256) {
        if (block.timestamp < phases[currentStage].endTime) {
            if (
                phases[currentStage].totalSoldTokens <
                phases[currentStage].tokensToSell
            ) {
                return currentStage;
            } else {
                return currentStage + 1;
            }
        } else {
            return currentStage + 1;
        }
    }

    function changeClaimAddress(
        address _oldAddress,
        address _newWallet
    ) public onlyOwner {
        require(isExist[_oldAddress], " Old User not a participant");
        User storage user = users[_oldAddress];
        User storage newUser = users[_newWallet];
        newUser.token_balance = user.token_balance;
        newUser.claimed_tokens = user.claimed_tokens;
        user.token_balance = 0;
        user.claimed_tokens = 0;
        isExist[_oldAddress] = false;
        isExist[_newWallet] = true;
    }

    function getPhaseDetail(
        uint256 phaseInd
    )
        external
        view
        returns (
            uint256 tokenToSell,
            uint256 soldTokens,
            uint256 priceUsd,
            uint256 duration
        )
    {
        Phase memory phase = phases[phaseInd];
        return (
            phase.tokensToSell,
            phase.totalSoldTokens,
            phase.tokenPerUsdPrice,
            phase.endTime
        );
    }

    function setPresaleStatus(bool _status) external onlyOwner {
        presaleStatus = _status;
    }

    function setReferralPercentage(uint256 newPercentage) external onlyOwner {
        referral_percentage = newPercentage;
    }

    function endPresale() external onlyOwner {
        isPresaleEnded = true;
        claimStartTime = block.timestamp;
    }

    //to check all users list
    function viewUsers() external view onlyOwner returns (address[] memory) {
        return UsersAddresses;
    }

    // to check number of token for given Eth
    function nativeToToken(
        uint256 _amount,
        uint256 phaseId
    ) public view returns (uint256) {
        uint256 ethToUsd = (_amount * (getLatestPrice())) / (1 ether);
        uint256 numberOfTokens = (ethToUsd * phases[phaseId].tokenPerUsdPrice) /
            (1e8);
        return numberOfTokens;
    }

    // to check number of token for given usdt
    function usdtToToken(
        uint256 _amount,
        uint256 phaseId
    ) public view returns (uint256) {
        uint256 numberOfTokens = (_amount * phases[phaseId].tokenPerUsdPrice) /
            (1e18);
        return numberOfTokens;
    }

    function updateInfos(
        uint256 _sold,
        uint256 _raised,
        uint256 _raisedInUsdt
    ) external onlyOwner {
        soldToken = _sold;
        amountRaised = _raised;
        amountRaisedUSDT = _raisedInUsdt;
    }

    // change tokens
    function updateToken(address _token) external onlyOwner {
        mainToken = IERC20(_token);
    }

    function updateEndTime(uint256 _phase, uint256 _time) public onlyOwner {
        phases[_phase].endTime = _time;
    }

    //change tokens for buy
    function updateStableTokens(IERC20 _USDT) external onlyOwner {
        USDT = IERC20(_USDT);
    }

    // to withdraw funds for liquidity
    function initiateTransfer(uint256 _value) external onlyOwner {
        fundReceiver.transfer(_value);
    }

    function changeFundReciever(address _addr) external onlyOwner {
        fundReceiver = payable(_addr);
    }

    function updatePriceFeed(
        AggregatorV3Interface _priceFeed
    ) external onlyOwner {
        priceFeed = _priceFeed;
    }

    // to withdraw out tokens
    function transferTokens(IERC20 token, uint256 _value) external onlyOwner {
        token.transfer(msg.sender, _value);
    }
}
