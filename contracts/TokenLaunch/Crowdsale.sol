// SPDX-License-Identifier: GPL-3.0                        
pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

// Crowd Sale for Decipher Session
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

// contract Crowdsale is IMisoMarket, MISOAccessControls, BoringBatchable, SafeTransfer, Documents , ReentrancyGuard  {
contract Crowdsale is ReentrancyGuard, Ownable {
    using SafeMath for uint256;

    /// @notice The placeholder ETH address.
    address private constant ETH_ADDRESS = 0x0000000000000000000000000000000000000000;

    /// @notice The decimals of the auction token.
    uint256 private constant AUCTION_TOKEN_DECIMAL_PLACES = 18;
    uint256 private constant AUCTION_TOKEN_DECIMALS = 10 ** AUCTION_TOKEN_DECIMAL_PLACES;

    /** 
    * @notice rate - How many token units a buyer gets per token or wei.
    * The rate is the conversion between wei and the smallest and indivisible token unit.
    * So, if you are using a rate of 1 with a ERC20Detailed token with 3 decimals called TOK
    * 1 wei will give you 1 unit, or 0.001 TOK.
    */
    /// @notice goal - Minimum amount of funds to be raised in weis or tokens.
    struct MarketPrice {
        uint256 rate;
        uint256 goal; 
    }
    MarketPrice public marketPrice;

    /// @notice Starting time of crowdsale.
    /// @notice Ending time of crowdsale.
    /// @notice Total number of tokens to sell.
    struct MarketInfo {
        uint256 startTime;
        uint256 endTime; 
        uint256 totalTokens;
    }
    MarketInfo public marketInfo;

    /// @notice Amount of wei raised.
    /// @notice Whether crowdsale has been initialized or not.
    /// @notice Whether crowdsale has been finalized or not.
    struct MarketStatus {
        uint256 commitmentsTotal;
        bool finalized;
        bool usePointList;
    }
    MarketStatus public marketStatus;

    /// @notice The token being sold.
    address public auctionToken;
    /// @notice Address where funds are collected.
    address payable public wallet;
    /// @notice The currency the crowdsale accepts for payment. Can be ETH or token address.
    address public paymentCurrency;
    /// @notice Address that manages auction approvals.
    address public pointList;

    /// @notice The commited amount of accounts.
    mapping(address => uint256) public commitments;
    /// @notice Amount of tokens to claim per address.
    mapping(address => uint256) public claimed;

    /// @notice Event for all auction data. Emmited on deployment.
    event AuctionDeployed(address funder, address token, address paymentCurrency, uint256 totalTokens, address admin, address wallet);
    
    /// @notice Event for updating auction times.  Needs to be before auction starts.
    event AuctionTimeUpdated(uint256 startTime, uint256 endTime); 
    /// @notice Event for updating auction prices. Needs to be before auction starts.
    event AuctionPriceUpdated(uint256 rate, uint256 goal); 
    /// @notice Event for updating auction wallet. Needs to be before auction starts.
    event AuctionWalletUpdated(address wallet); 
    /// @notice Event for updating the point list.
    event AuctionPointListUpdated(address pointList, bool enabled);

    /// @notice Event for adding a commitment.
    event AddedCommitment(address addr, uint256 commitment);

    /// @notice Event for finalization of the crowdsale
    event AuctionFinalized();
    /// @notice Event for cancellation of the auction.
    event AuctionCancelled();

    /**
     * @notice Initializes main contract variables and transfers funds for the sale.
     * @dev Init function.
     * @param _funder The address that funds the token for crowdsale.
     * @param _token Address of the token being sold.
     * @param _paymentCurrency The currency the crowdsale accepts for payment. Can be ETH or token address.
     * @param _totalTokens The total number of tokens to sell in crowdsale.
     * @param _startTime Crowdsale start time.
     * @param _endTime Crowdsale end time.
     * @param _rate Number of token units a buyer gets per wei or token.
     * @param _goal Minimum amount of funds to be raised in weis or tokens.
     * @param _admin Address that can finalize auction.
     * @param _wallet Address where collected funds will be forwarded to.
     */
    function initCrowdsale(
        address _funder,
        address _token,
        address _paymentCurrency,
        uint256 _totalTokens,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _rate,
        uint256 _goal,
        address _admin,
        address payable _wallet
    ) public {
        require(_endTime < 10000000000, "Crowdsale: enter an unix timestamp in seconds, not miliseconds");
        require(_startTime >= block.timestamp, "Crowdsale: start time is before current time");
        require(_endTime > _startTime, "Crowdsale: start time is not before end time");
        require(_rate > 0, "Crowdsale: rate is 0");
        require(_wallet != address(0), "Crowdsale: wallet is the zero address");
        require(_admin != address(0), "Crowdsale: admin is the zero address");
        require(_totalTokens > 0, "Crowdsale: total tokens is 0");
        require(_goal > 0, "Crowdsale: goal is 0");
        require(ERC20(_token).decimals() == AUCTION_TOKEN_DECIMAL_PLACES, "Crowdsale: Token does not have 18 decimals");
        if (_paymentCurrency != ETH_ADDRESS) {
            require(ERC20(_paymentCurrency).decimals() > 0, "Crowdsale: Payment currency is not ERC20");
        }

        marketPrice.rate = _rate;
        marketPrice.goal = _goal;

        marketInfo.startTime = _startTime;
        marketInfo.endTime = _endTime;
        marketInfo.totalTokens = _totalTokens;

        auctionToken = _token;
        paymentCurrency = _paymentCurrency;
        wallet = _wallet;

        // ownable로 대체
        // initAccessControls(_admin);

        // require(_getTokenAmount(_goal) <= _totalTokens, "Crowdsale: goal should be equal to or lower than total tokens");

        _safeTransferFrom(auctionToken, _funder, address(this), _totalTokens);

        emit AuctionDeployed(_funder, _token, _paymentCurrency, _totalTokens, _admin, _wallet);
        emit AuctionTimeUpdated(_startTime, _endTime);
        emit AuctionPriceUpdated(_rate, _goal);
    }


    ///--------------------------------------------------------
    /// Commit to buying tokens!
    ///--------------------------------------------------------

    receive() external payable {
        revertBecauseUserDidNotProvideAgreement();
    }

    /** 
     * @dev Attribution to the awesome delta.financial contracts
    */  
    function marketParticipationAgreement() public pure returns (string memory) {
        return "I understand that I am interacting with a smart contract. I understand that tokens commited are subject to the token issuer and local laws where applicable. I reviewed code of the smart contract and understand it fully. I agree to not hold developers or other people associated with the project liable for any losses or misunderstandings";
    }
    /** 
     * @dev Not using modifiers is a purposeful choice for code readability.
    */ 
    function revertBecauseUserDidNotProvideAgreement() internal pure {
        revert("No agreement provided, please review the smart contract before interacting with it");
    }

    /**
     * @notice Checks the amount of ETH to commit and adds the commitment. Refunds the buyer if commit is too high.
     * @dev low level token purchase with ETH ***DO NOT OVERRIDE***
     * This function has a non-reentrancy guard, so it should not be called by
     * another `nonReentrant` function.
     * @param _beneficiary Recipient of the token purchase.
     */
    function commitEth(
        address payable _beneficiary,
        bool readAndAgreedToMarketParticipationAgreement
    ) 
        public payable   nonReentrant    
    {
        require(paymentCurrency == ETH_ADDRESS, "Crowdsale: Payment currency is not ETH"); 
        if(readAndAgreedToMarketParticipationAgreement == false) {
            revertBecauseUserDidNotProvideAgreement();
        }

        /// @dev Get ETH able to be committed.
        uint256 ethToTransfer = calculateCommitment(msg.value);

        /// @dev Accept ETH Payments.
        uint256 ethToRefund = msg.value.sub(ethToTransfer);
        if (ethToTransfer > 0) {
            _addCommitment(_beneficiary, ethToTransfer);
        }

        /// @dev Return any ETH to be refunded.
        if (ethToRefund > 0) {
            _beneficiary.transfer(ethToRefund);
        }

        /// @notice Revert if commitmentsTotal exceeds the balance
        require(marketStatus.commitmentsTotal <= address(this).balance, "CrowdSale: The committed ETH exceeds the balance");
    }

    /**
     * @notice Buy Tokens by commiting approved ERC20 tokens to this contract address.
     * @param _amount Amount of tokens to commit.
     */
    function commitTokens(uint256 _amount, bool readAndAgreedToMarketParticipationAgreement) public {
        commitTokensFrom(msg.sender, _amount, readAndAgreedToMarketParticipationAgreement);
    }

    /**
     * @notice Checks how much is user able to commit and processes that commitment.
     * @dev Users must approve contract prior to committing tokens to auction.
     * @param _from User ERC20 address.
     * @param _amount Amount of approved ERC20 tokens.
     */
    function commitTokensFrom(
        address _from,
        uint256 _amount,
        bool readAndAgreedToMarketParticipationAgreement
    ) 
        public   nonReentrant  
    {
        require(address(paymentCurrency) != ETH_ADDRESS, "Crowdsale: Payment currency is not a token");
        if(readAndAgreedToMarketParticipationAgreement == false) {
            revertBecauseUserDidNotProvideAgreement();
        }
        uint256 tokensToTransfer = calculateCommitment(_amount);
        if (tokensToTransfer > 0) {
            _safeTransferFrom(paymentCurrency, address(this),msg.sender, tokensToTransfer);
            _addCommitment(_from, tokensToTransfer);
        }
    }

    /**
     * @notice Checks if the commitment does not exceed the goal of this sale.
     * @param _commitment Number of tokens to be commited.
     * @return committed The amount able to be purchased during a sale.
     */
    function calculateCommitment(uint256 _commitment)
        public
        view
        returns (uint256 committed)
    {
        uint256 tokens = _getTokenAmount(_commitment);
        uint256 tokensCommited =_getTokenAmount(uint256(marketStatus.commitmentsTotal));
        if ( tokensCommited.add(tokens) > uint256(marketInfo.totalTokens)) {
            return _getTokenPrice(uint256(marketInfo.totalTokens).sub(tokensCommited));
        }
        return _commitment;
    }

    /**
     * @notice Updates commitment of the buyer and the amount raised, emits an event.
     * @param _addr Recipient of the token purchase.
     * @param _commitment Value in wei or token involved in the purchase.
     */
    function _addCommitment(address _addr, uint256 _commitment) internal {
        require(block.timestamp >= uint256(marketInfo.startTime) && block.timestamp <= uint256(marketInfo.endTime), "Crowdsale: outside auction hours");
        require(_addr != address(0), "Crowdsale: beneficiary is the zero address");
        require(!marketStatus.finalized, "CrowdSale: Auction is finalized");
        uint256 newCommitment = commitments[_addr].add(_commitment);
        // if (marketStatus.usePointList) {
        //     require(IPointList(pointList).hasPoints(_addr, newCommitment));
        // }

        commitments[_addr] = newCommitment;

        /// @dev Update state.
        marketStatus.commitmentsTotal = uint256(marketStatus.commitmentsTotal).add(_commitment);

        emit AddedCommitment(_addr, _commitment);
    }

    // function withdrawTokens() public  {
    //     withdrawTokens(msg.sender);
    // }

    /**
     * @notice Withdraws bought tokens, or returns commitment if the sale is unsuccessful.
     * @dev Withdraw tokens only after crowdsale ends.
     * @param beneficiary Whose tokens will be withdrawn.
     */
    function withdrawTokens(address payable beneficiary) public   nonReentrant  {    
        if (auctionSuccessful()) {
            require(marketStatus.finalized, "Crowdsale: not finalized");
            /// @dev Successful auction! Transfer claimed tokens.
            uint256 tokensToClaim = tokensClaimable(beneficiary);
            require(tokensToClaim > 0, "Crowdsale: no tokens to claim"); 
            claimed[beneficiary] = claimed[beneficiary].add(tokensToClaim);
            // _safeTokenPayment(auctionToken, beneficiary, tokensToClaim);            
            _safeTransferFrom(auctionToken, address(this), beneficiary, tokensClaimable(beneficiary));
        } else {
            /// @dev Auction did not meet reserve price.
            /// @dev Return committed funds back to user.
            require(block.timestamp > uint256(marketInfo.endTime), "Crowdsale: auction has not finished yet");
            uint256 accountBalance = commitments[beneficiary];
            commitments[beneficiary] = 0; // Stop multiple withdrawals and free some gas
            // _safeTokenPayment(paymentCurrency, beneficiary, accountBalance);
            _safeTransferFrom(paymentCurrency,address(this), beneficiary, accountBalance);
        }
    }

    /**
     * @notice Adjusts users commitment depending on amount already claimed and unclaimed tokens left.
     * @return claimerCommitment How many tokens the user is able to claim.
     */
    function tokensClaimable(address _user) public view returns (uint256 claimerCommitment) {
        uint256 unclaimedTokens = IERC20(auctionToken).balanceOf(address(this));
        claimerCommitment = _getTokenAmount(commitments[_user]);
        claimerCommitment = claimerCommitment.sub(claimed[_user]);

        if(claimerCommitment > unclaimedTokens){
            claimerCommitment = unclaimedTokens;
        }
    }
    
    //--------------------------------------------------------
    // Finalize Auction
    //--------------------------------------------------------
    
    /**
     * @notice Manually finalizes the Crowdsale.
     * @dev Must be called after crowdsale ends, to do some extra finalization work.
     * Calls the contracts finalization function.
     */
    function finalize() public nonReentrant {
        require(            
            // hasAdminRole(msg.sender) 
            wallet == msg.sender
            // || hasSmartContractRole(msg.sender) 
            || finalizeTimeExpired(),
            "Crowdsale: sender must be an admin"
        );
        MarketStatus storage status = marketStatus;
        require(!status.finalized, "Crowdsale: already finalized");
        MarketInfo storage info = marketInfo;
        require(info.totalTokens > 0, "Not initialized");
        require(auctionEnded(), "Crowdsale: Has not finished yet"); 

        if (auctionSuccessful()) {
            /// @dev Successful auction
            /// @dev Transfer contributed tokens to wallet.
            _safeTransferFrom(paymentCurrency, address(this),wallet, uint256(status.commitmentsTotal));
            /// @dev Transfer unsold tokens to wallet.
            uint256 soldTokens = _getTokenAmount(uint256(status.commitmentsTotal));
            uint256 unsoldTokens = uint256(info.totalTokens).sub(soldTokens);
            if(unsoldTokens > 0) {
                _safeTransferFrom(auctionToken, address(this), wallet, unsoldTokens);
            }
        } else {
            /// @dev Failed auction
            /// @dev Return auction tokens back to wallet.
            _safeTransferFrom(auctionToken,address(this), wallet, uint256(info.totalTokens));
        }

        status.finalized = true;

        emit AuctionFinalized();
    }

    /**
     * @notice Cancel Auction
     * @dev Admin can cancel the auction before it starts
     */
    function cancelAuction() public   nonReentrant  onlyOwner
    {
        // require(hasAdminRole(msg.sender));
        MarketStatus storage status = marketStatus;
        require(!status.finalized, "Crowdsale: already finalized");
        require( uint256(status.commitmentsTotal) == 0, "Crowdsale: Funds already raised" );

        _safeTransferFrom(auctionToken, address(this),wallet, uint256(marketInfo.totalTokens));

        status.finalized = true;
        emit AuctionCancelled();
    }

    function tokenPrice() public view returns (uint256) {
        return uint256(marketPrice.rate); 
    }

    function _getTokenPrice(uint256 _amount) internal view returns (uint256) {
        return _amount.mul(uint256(marketPrice.rate)).div(AUCTION_TOKEN_DECIMALS);   
    }

    function getTokenAmount(uint256 _amount) public view returns (uint256) {
        return _getTokenAmount(_amount);
    }

    /**
     * @notice Calculates the number of tokens to purchase.
     * @dev Override to extend the way in which ether is converted to tokens.
     * @param _amount Value in wei or token to be converted into tokens.
     * @return tokenAmount Number of tokens that can be purchased with the specified amount.
     */
    function _getTokenAmount(uint256 _amount) internal view returns (uint256) {
        return _amount.mul(AUCTION_TOKEN_DECIMALS).div(uint256(marketPrice.rate));
    }

    /**
     * @notice Checks if the sale is open.
     * @return isOpen True if the crowdsale is open, false otherwise.
     */
    function isOpen() public view returns (bool) {
        return block.timestamp >= uint256(marketInfo.startTime) && block.timestamp <= uint256(marketInfo.endTime);
    }

    /**
     * @notice Checks if the sale minimum amount was raised.
     * @return auctionSuccessful True if the commitmentsTotal is equal or higher than goal.
     */
    function auctionSuccessful() public view returns (bool) {
        return uint256(marketStatus.commitmentsTotal) >= uint256(marketPrice.goal);
    }

    /**
     * @notice Checks if the sale has ended.
     * @return auctionEnded True if sold out or time has ended.
     */
    function auctionEnded() public view returns (bool) {
        return block.timestamp > uint256(marketInfo.endTime) || 
        _getTokenAmount(uint256(marketStatus.commitmentsTotal) + 1) >= uint256(marketInfo.totalTokens);
    }

    /**
     * @notice Checks if the sale has been finalised.
     * @return bool True if sale has been finalised.
     */
    function finalized() public view returns (bool) {
        return marketStatus.finalized;
    }

    /**
     * @return True if 7 days have passed since the end of the auction
    */
    function finalizeTimeExpired() public view returns (bool) {
        return uint256(marketInfo.endTime) + 7 days < block.timestamp;
    }
    

    //--------------------------------------------------------
    // Documents
    //--------------------------------------------------------

    // function setDocument(string calldata _name, string calldata _data) onlyOwner external {
    //     // require(hasAdminRole(msg.sender) );
    //     _setDocument( _name, _data);
    // }

    // function setDocuments(string[] calldata _name, string[] calldata _data) onlyOwner external {
    //     // require(hasAdminRole(msg.sender) );
    //     uint256 numDocs = _name.length;
    //     for (uint256 i = 0; i < numDocs; i++) {
    //         _setDocument( _name[i], _data[i]);
    //     }
    // }

    // function removeDocument(string calldata _name) onlyOwner external {
    //     // require(hasAdminRole(msg.sender));
    //     _removeDocument(_name);
    // }

    //--------------------------------------------------------
    // Point Lists
    //--------------------------------------------------------


    // function setList(address _list) external {
    //     require(hasAdminRole(msg.sender));
    //     _setList(_list);
    // }

    // function enableList(bool _status) external {
    //     require(hasAdminRole(msg.sender));
    //     marketStatus.usePointList = _status;

    //     emit AuctionPointListUpdated(pointList, marketStatus.usePointList);
    // }

    // function _setList(address _pointList) private {
    //     if (_pointList != address(0)) {
    //         pointList = _pointList;
    //         marketStatus.usePointList = true;
    //     }

    //     emit AuctionPointListUpdated(pointList, marketStatus.usePointList);
    // }

    //--------------------------------------------------------
    // Setter Functions
    //--------------------------------------------------------

    /**
     * @notice Admin can set start and end time through this function.
     * @param _startTime Auction start time.
     * @param _endTime Auction end time.
     */
    function setAuctionTime(uint256 _startTime, uint256 _endTime) onlyOwner external {
        // require(hasAdminRole(msg.sender));
        require(_startTime < 10000000000, "Crowdsale: enter an unix timestamp in seconds, not miliseconds");
        require(_endTime < 10000000000, "Crowdsale: enter an unix timestamp in seconds, not miliseconds");
        require(_startTime >= block.timestamp, "Crowdsale: start time is before current time");
        require(_endTime > _startTime, "Crowdsale: end time must be older than start price");

        require(marketStatus.commitmentsTotal == 0, "Crowdsale: auction cannot have already started");

        marketInfo.startTime = (_startTime);
        marketInfo.endTime = (_endTime);
        
        emit AuctionTimeUpdated(_startTime,_endTime);
    }

    /**
     * @notice Admin can set auction price through this function.
     * @param _rate Price per token.
     * @param _goal Minimum amount raised and goal for the auction.
     */
    function setAuctionPrice(uint256 _rate, uint256 _goal) onlyOwner external {
        // require(hasAdminRole(msg.sender));
        require(_goal > 0, "Crowdsale: goal is 0");
        require(_rate > 0, "Crowdsale: rate is 0");
        require(marketStatus.commitmentsTotal == 0, "Crowdsale: auction cannot have already started");
        marketPrice.rate = (_rate);
        marketPrice.goal = (_goal);
        require(_getTokenAmount(_goal) <= uint256(marketInfo.totalTokens), "Crowdsale: minimum target exceeds hard cap");

        emit AuctionPriceUpdated(_rate,_goal);
    }

    /**
     * @notice Admin can set the auction wallet through this function.
     * @param _wallet Auction wallet is where funds will be sent.
     */
    function setAuctionWallet(address payable _wallet) onlyOwner external {
        // require(hasAdminRole(msg.sender));
        require(_wallet != address(0), "Crowdsale: wallet is the zero address");
        wallet = _wallet;

        emit AuctionWalletUpdated(_wallet);
    }
  function _safeTransferFrom(
        address _token,
        address _from,
        address _to,
        uint256 _value
    ) internal {
        if (_token == address(0)) {
            _to.call{value: _value}("");
        } else {
            ERC20(_token).approve(_to, _value);
            ERC20(_token).transferFrom(_from, _to, _value);
        }
    }

}