// SPDX-License-Identifier: GPL-3.0                        
pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

// Hyperbolic Auction for Decipher Session
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/// @notice Attribution to delta.financial
/// @notice Attribution to dutchswap.com

contract HyperbolicAuction is  ReentrancyGuard, Ownable  {
    using SafeMath for uint256;

    /// @dev The placeholder ETH address.
    address private constant ETH_ADDRESS = 0x0000000000000000000000000000000000000000;

    /// @notice Main market variables.
    struct MarketInfo {
        uint256 startTime;
        uint256 endTime;
        uint256 totalTokens;
    }
    MarketInfo public marketInfo;

    /// @notice Market price variables.
    struct MarketPrice {
        uint256 minimumPrice;
        uint256 alpha;
        // GP: Can be added later as exponent factor
        // uint16 factor;
    }
    MarketPrice public marketPrice;

    /// @notice Market dynamic variables.
    struct MarketStatus {
        uint256 commitmentsTotal;
        bool finalized;
        bool usePointList;

    }
    MarketStatus public marketStatus;

    /// @notice The token being sold.
    address public auctionToken; 
    /// @notice The currency the auction accepts for payment. Can be ETH or token address.
    address public paymentCurrency;  
    /// @notice Where the auction funds will get paid.
    address payable public wallet;  
    /// @notice Address that manages auction approvals.
    address public pointList;

    /// @notice The commited amount of accounts.
    mapping(address => uint256) public commitments;
    /// @notice Amount of tokens to claim per address.
    mapping(address => uint256) public claimed;
    
    /// @notice Event for all auction data. Emmited on deployment.
    event AuctionDeployed(address funder, address token, uint256 totalTokens, address paymentCurrency, address admin, address wallet);

    /// @notice Event for updating auction times.  Needs to be before auction starts.
    event AuctionTimeUpdated(uint256 startTime, uint256 endTime); 
    /// @notice Event for updating auction prices. Needs to be before auction starts.
    event AuctionPriceUpdated(uint256 minimumPrice); 
    /// @notice Event for updating auction wallet. Needs to be before auction starts.
    event AuctionWalletUpdated(address wallet); 
    /// @notice Event for updating the point list.
    event AuctionPointListUpdated(address pointList, bool enabled);

    /// @notice Event for adding a commitment.
    event AddedCommitment(address addr, uint256 commitment);
    /// @notice Event for token withdrawals.
    event TokensWithdrawn(address token, address to, uint256 amount);

    /// @notice Event for finalization of the auction.
    event AuctionFinalized();
    /// @notice Event for cancellation of the auction.
    event AuctionCancelled();

    /**
     * @notice Initializes main contract variables and transfers funds for the auction.
     * @dev Init function
     * @param _funder The address that funds the token for HyperbolicAuction
     * @param _token Address of the token being sold
     * @param _paymentCurrency The currency the HyperbolicAuction accepts for payment. Can be ETH or token address
     * @param _totalTokens The total number of tokens to sell in auction
     * @param _startTime Auction start time
     * @param _endTime Auction end time
     * @param _factor Inflection point of the auction
     * @param _minimumPrice The minimum auction price
     * @param _wallet Address where collected funds will be forwarded to
     */
    function initAuction(
        address _funder,
        address _token,
        uint256 _totalTokens,
        uint256 _startTime,
        uint256 _endTime,
        address _paymentCurrency,
        uint256 _factor,
        uint256 _minimumPrice,
        address payable _wallet
    ) public {
        require(_endTime < 10000000000, "HyperbolicAuction: enter an unix timestamp in seconds, not miliseconds");
        require(_startTime >= block.timestamp, "HyperbolicAuction: start time is before current time");
        require(_totalTokens > 0,"HyperbolicAuction: total tokens must be greater than zero");
        require(_endTime > _startTime, "HyperbolicAuction: end time must be older than start time");
        require(_minimumPrice > 0, "HyperbolicAuction: minimum price must be greater than 0"); 
        require(_wallet != address(0), "HyperbolicAuction: wallet is the zero address");
        require(_token != address(0), "HyperbolicAuction: token is the zero address");
        require(ERC20(_token).decimals() == 18, "HyperbolicAuction: Token does not have 18 decimals");
        if (_paymentCurrency != ETH_ADDRESS) {
            require(ERC20(_paymentCurrency).decimals() > 0, "HyperbolicAuction: Payment currency is not ERC20");
        }

        marketInfo.startTime =(_startTime);
        marketInfo.endTime =(_endTime);
        marketInfo.totalTokens =(_totalTokens);

        marketPrice.minimumPrice =(_minimumPrice);

        auctionToken = _token;
        paymentCurrency = _paymentCurrency;
        wallet = _wallet;

        // Ownable 로 대체
        // initAccessControls(_admin);
        
        // _setList(_pointList);

         // factor = exponent which can later be used to alter the curve
        uint256 _duration = _endTime - _startTime;
        uint256 _alpha = _duration.mul(_minimumPrice);
        marketPrice.alpha =(_alpha);

        _safeTransferFrom(_token, _funder, address(this), _totalTokens);

        // emit AuctionDeployed(_funder, _token, _totalTokens, _paymentCurrency, _admin, _wallet);
        // emit AuctionTimeUpdated(_startTime, _endTime);
        // emit AuctionPriceUpdated(_minimumPrice);
    }


    ///--------------------------------------------------------
    /// Auction Pricing
    ///--------------------------------------------------------

    /**
     * @notice Calculates the average price of each token from all commitments.
     * @return Average token price.
     */
    function tokenPrice() public view returns (uint256) {
        return uint256(marketStatus.commitmentsTotal)
            .mul(1e18).div(uint256(marketInfo.totalTokens));
    }

    /**
     * @notice Returns auction price in any time.
     * @return Fixed start price or minimum price if outside of auction time, otherwise calculated current price.
     */
    function priceFunction() public view returns (uint256) {
        /// @dev Return Auction Price
        if (block.timestamp <= uint256(marketInfo.startTime)) {
            return type(uint256).max;
        }
        if (block.timestamp >= uint256(marketInfo.endTime)) {
            return uint256(marketPrice.minimumPrice);
        }
        return _currentPrice();
    }

    /// @notice The current clearing price of the Hyperbolic auction
    function clearingPrice() public view returns (uint256) {
        /// @dev If auction successful, return tokenPrice
        if (tokenPrice() > priceFunction()) {
            return tokenPrice();
        }
        return priceFunction();
    }

    /**
     * @notice Calculates price during the auction.
     * @return Current auction price.
     */
    function _currentPrice() private view returns (uint256) {
        uint256 elapsed = block.timestamp.sub(uint256(marketInfo.startTime));
        uint256 currentPrice = uint256(marketPrice.alpha).div(elapsed);
        return currentPrice;
    }

    ///--------------------------------------------------------
    /// Commit to buying tokens!
    ///--------------------------------------------------------

    /**
     * @notice Buy Tokens by committing ETH to this contract address
     * @dev Needs sufficient gas limit for additional state changes
     */
    receive() external payable {
        revertBecauseUserDidNotProvideAgreement();
    }

    /** 
     * @dev Attribution to the awesome delta.financial contracts
    */  
    function marketParticipationAgreement() public pure returns (string memory) {
        return "I understand that I'm interacting with a smart contract. I understand that tokens commited are subject to the token issuer and local laws where applicable. I reviewed code of the smart contract and understand it fully. I agree to not hold developers or other people associated with the project liable for any losses or misunderstandings";
    }
    /** 
     * @dev Not using modifiers is a purposeful choice for code readability.
    */ 
    function revertBecauseUserDidNotProvideAgreement() internal pure {
        revert("No agreement provided, please review the smart contract before interacting with it");
    }

    /**
     * @notice Checks the amount of ETH to commit and adds the commitment. Refunds the buyer if commit is too high.
     * @param _beneficiary Auction participant ETH address.
     */
    function commitEth(
        address payable _beneficiary,
        bool readAndAgreedToMarketParticipationAgreement
    ) 
        public payable
    {
        require(paymentCurrency == ETH_ADDRESS, "HyperbolicAuction: payment currency is not ETH address"); 
        // Get ETH able to be committed
        if(readAndAgreedToMarketParticipationAgreement == false) {
            revertBecauseUserDidNotProvideAgreement();
        }
        require(msg.value > 0, "HyperbolicAuction: Value must be higher than 0");
        uint256 ethToTransfer = calculateCommitment(msg.value);

        uint256 ethToRefund = msg.value.sub(ethToTransfer);
        if (ethToTransfer > 0) {
            _addCommitment(_beneficiary, ethToTransfer);
        }
        /// @notice Return any ETH to be refunded.
        if (ethToRefund > 0) {
            _beneficiary.transfer(ethToRefund);
        }

        /// @notice Revert if commitmentsTotal exceeds the balance
        require(marketStatus.commitmentsTotal <= address(this).balance, "HyperbolicAuction: The committed ETH exceeds the balance");
    }

    /**
     * @notice Buy Tokens by commiting approved ERC20 tokens to this contract address.
     * @param _amount Amount of tokens to commit.
     */
    function commitTokens(uint256 _amount, bool readAndAgreedToMarketParticipationAgreement) public {
        commitTokensFrom(msg.sender, _amount, readAndAgreedToMarketParticipationAgreement);
    }

    /// @dev Users must approve contract prior to committing tokens to auction
    function commitTokensFrom(
        address _from,
        uint256 _amount,
        bool readAndAgreedToMarketParticipationAgreement
    )
        public   nonReentrant  
    {
        require(paymentCurrency != ETH_ADDRESS, "HyperbolicAuction: payment currency is not a token");
        if(readAndAgreedToMarketParticipationAgreement == false) {
            revertBecauseUserDidNotProvideAgreement();
        }
        uint256 tokensToTransfer = calculateCommitment(_amount);
        if (tokensToTransfer > 0) {
            _safeTransferFrom(paymentCurrency, msg.sender, address(this), tokensToTransfer);
            _addCommitment(_from, tokensToTransfer);
        }
    }

    /**
     * @notice Calculates total amount of tokens committed at current auction price.
     * @return Number of tokens commited.
     */
    function totalTokensCommitted() public view returns (uint256) {
        return uint256(marketStatus.commitmentsTotal).mul(1e18).div(clearingPrice());
    }

    /**
     * @notice Calculates the amount able to be committed during an auction.
     * @param _commitment Commitment user would like to make.
     * @return Amount allowed to commit.
     */
    function calculateCommitment(uint256 _commitment) public view returns (uint256 ) {
        uint256 maxCommitment = uint256(marketInfo.totalTokens).mul(clearingPrice()).div(1e18);
        if (uint256(marketStatus.commitmentsTotal).add(_commitment) > maxCommitment) {
            return maxCommitment.sub(uint256(marketStatus.commitmentsTotal));
        }
        return _commitment;
    }


    /**
     * @notice Updates commitment for this address and total commitment of the auction.
     * @param _addr Bidders address.
     * @param _commitment The amount to commit.
     */
    function _addCommitment(address _addr, uint256 _commitment) internal {
        require(block.timestamp >= uint256(marketInfo.startTime) && block.timestamp <= uint256(marketInfo.endTime), "HyperbolicAuction: outside auction hours"); 
        MarketStatus storage status = marketStatus;
        require(!status.finalized, "HyperbolicAuction: auction already finalized");

        uint256 newCommitment = commitments[_addr].add(_commitment);
        // if (status.usePointList) {
        //     require(IPointList(pointList).hasPoints(_addr, newCommitment));
        // }

        commitments[_addr] = newCommitment;
        status.commitmentsTotal =(uint256(status.commitmentsTotal).add(_commitment));
        emit AddedCommitment(_addr, _commitment);
    }


    ///--------------------------------------------------------
    /// Finalize Auction
    ///--------------------------------------------------------

    /**
     * @notice Successful if tokens sold equals totalTokens.
     * @return True if tokenPrice is bigger or equal clearingPrice.
     */
    function auctionSuccessful() public view returns (bool) {
        return tokenPrice() >= clearingPrice();
    }

    /**
     * @notice Checks if the auction has ended.
     * @return True if auction is successful or time has ended.
     */
    function auctionEnded() public view returns (bool) {
        return auctionSuccessful() || block.timestamp > uint256(marketInfo.endTime);
    }

    /**
     * @return Returns true if market has been finalized
     */
    function finalized() public view returns (bool) {
        return marketStatus.finalized;
    }

    /**
     * @return Returns true if 7 days have passed since the end of the auction
     */
    function finalizeTimeExpired() public view returns (bool) {
        return uint256(marketInfo.endTime) + 7 days < block.timestamp;
    }

    /**
     * @notice Auction finishes successfully above the reserve
     * @dev Transfer contract funds to initialized wallet.
     */
    function finalize()
        public   nonReentrant onlyOwner
    {
        require(
            // hasAdminRole(msg.sender) 
            //     || 
                wallet == msg.sender
                // || hasSmartContractRole(msg.sender) 
                || finalizeTimeExpired(), "HyperbolicAuction: sender must be an admin");
        MarketStatus storage status = marketStatus;
        MarketInfo storage info = marketInfo;
        require(info.totalTokens > 0, "Not initialized");

        require(!status.finalized, "HyperbolicAuction: auction already finalized");
        if (auctionSuccessful()) {
            /// @dev Successful auction
            /// @dev Transfer contributed tokens to wallet.
            // _safeTokenPayment(paymentCurrency, wallet, uint256(status.commitmentsTotal));
            _safeTransferFrom(paymentCurrency, address(this), wallet, status.commitmentsTotal);
        } else {
            /// @dev Failed auction
            /// @dev Return auction tokens back to wallet.
            require(block.timestamp > uint256(info.endTime), "HyperbolicAuction: auction has not finished yet"); 
            // _safeTokenPayment(auctionToken, wallet, uint256(info.totalTokens));
            _safeTransferFrom(auctionToken, address(this), wallet, info.totalTokens);
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
        require(!status.finalized, "HyperbolicAuction: auction already finalized");
        require( uint256(status.commitmentsTotal) == 0, "HyperbolicAuction: auction already committed" );

        // _safeTokenPayment(auctionToken, wallet, uint256(marketInfo.totalTokens));
        _safeTransferFrom(auctionToken, address(this), wallet, marketInfo.totalTokens);

        status.finalized = true;
        emit AuctionCancelled();
    }

    /** 
     * @notice How many tokens the user is able to claim.
     * @param _user Auction participant address.
     * @return claimerCommitment User commitments reduced by already claimed tokens.
     */
    function tokensClaimable(address _user) public view returns (uint256 claimerCommitment) {
        if (commitments[_user] == 0) return 0;
        uint256 unclaimedTokens = IERC20(auctionToken).balanceOf(address(this));
        claimerCommitment = commitments[_user].mul(uint256(marketInfo.totalTokens)).div(uint256(marketStatus.commitmentsTotal));
        claimerCommitment = claimerCommitment.sub(claimed[_user]);

        if(claimerCommitment > unclaimedTokens){
            claimerCommitment = unclaimedTokens;
        }
    }


//    /// @notice Withdraws bought tokens, or returns commitment if the sale is unsuccessful.
//     function withdrawTokens() public  {
//         withdrawTokens(msg.sender);
//     }

    /// @notice Withdraw your tokens once the Auction has ended.
    function withdrawTokens(address payable beneficiary) 
        public   nonReentrant 
    {
        if (auctionSuccessful()) {
            require(marketStatus.finalized, "HyperbolicAuction: not finalized");
            uint256 tokensToClaim = tokensClaimable(beneficiary);
            require(tokensToClaim > 0, "HyperbolicAuction: no tokens to claim"); 
            claimed[beneficiary] = claimed[beneficiary].add(tokensToClaim);

            // _safeTokenPayment(auctionToken, beneficiary, tokensToClaim);
            _safeTransferFrom(auctionToken, address(this), beneficiary, tokensToClaim);
        } else {
            /// @dev Auction did not meet reserve price.
            /// @dev Return committed funds back to user.
            require(block.timestamp > uint256(marketInfo.endTime), "HyperbolicAuction: auction has not finished yet");
            uint256 fundsCommitted = commitments[beneficiary];
            commitments[beneficiary] = 0; // Stop multiple withdrawals and free some gas
            // _safeTokenPayment(paymentCurrency, beneficiary, fundsCommitted);
            _safeTransferFrom(paymentCurrency, address(this), beneficiary, fundsCommitted);
        }
    }


    //--------------------------------------------------------
    // Documents
    //--------------------------------------------------------

    // function setDocument(string calldata _name, string calldata _data) external {
    //     require(hasAdminRole(msg.sender) );
    //     _setDocument( _name, _data);
    // }

    // function setDocuments(string[] calldata _name, string[] calldata _data) external {
    //     require(hasAdminRole(msg.sender) );
    //     uint256 numDocs = _name.length;
    //     for (uint256 i = 0; i < numDocs; i++) {
    //         _setDocument( _name[i], _data[i]);
    //     }
    // }

    // function removeDocument(string calldata _name) external {
    //     require(hasAdminRole(msg.sender));
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
    function setAuctionTime(uint256 _startTime, uint256 _endTime) external onlyOwner{
        // require(hasAdminRole(msg.sender));
        require(_startTime < 10000000000, "HyperbolicAuction: enter an unix timestamp in seconds, not miliseconds");
        require(_endTime < 10000000000, "HyperbolicAuction: enter an unix timestamp in seconds, not miliseconds");
        require(_startTime >= block.timestamp, "HyperbolicAuction: start time is before current time");
        require(_endTime > _startTime, "HyperbolicAuction: end time must be older than start price");
        require(marketStatus.commitmentsTotal == 0, "HyperbolicAuction: auction cannot have already started");

        marketInfo.startTime =(_startTime);
        marketInfo.endTime =(_endTime);

        uint256 _duration = marketInfo.endTime - marketInfo.startTime;        
        uint256 _alpha = uint256(_duration).mul(uint256(marketPrice.minimumPrice));
        marketPrice.alpha =(_alpha);
        
        emit AuctionTimeUpdated(_startTime,_endTime);
    }

    /**
     * @notice Admin can set start and min price through this function.
     * @param _minimumPrice Auction minimum price.
     */
    function setAuctionPrice( uint256 _minimumPrice) external onlyOwner{
        // require(hasAdminRole(msg.sender));
        require(_minimumPrice > 0, "HyperbolicAuction: minimum price must be greater than 0"); 
        require(marketStatus.commitmentsTotal == 0, "HyperbolicAuction: auction cannot have already started");

        marketPrice.minimumPrice =(_minimumPrice);

        uint256 _duration = marketInfo.endTime - marketInfo.startTime;        
        uint256 _alpha = uint256(_duration).mul(uint256(marketPrice.minimumPrice));
        marketPrice.alpha =(_alpha);

        emit AuctionPriceUpdated(_minimumPrice);
    }

    /**
     * @notice Admin can set the auction wallet through this function.
     * @param _wallet Auction wallet is where funds will be sent.
     */
    function setAuctionWallet(address payable _wallet) external onlyOwner{
        // require(hasAdminRole(msg.sender));
        require(_wallet != address(0), "HyperbolicAuction: wallet is the zero address");

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

    ///--------------------------------------------------------
    /// Market Launchers
    ///--------------------------------------------------------

    // function init(bytes calldata _data) external override payable {
    // }

    // /**
    //  * @notice Decodes and hands auction data to the initAuction function.
    //  * @param _data Encoded data for initialization.
    //  */
    // function initMarket(bytes calldata _data) public override {
    //     (
    //     address _funder,
    //     address _token,
    //     uint256 _totalTokens,
    //     uint256 _startTime,
    //     uint256 _endTime,
    //     address _paymentCurrency,
    //     uint256 _factor,
    //     uint256 _minimumPrice,
    //     address _admin,
    //     address _pointList,
    //     address payable _wallet
    //     ) = abi.decode(_data, (
    //         address,
    //         address,
    //         uint256,
    //         uint256,
    //         uint256,
    //         address,
    //         uint256,
    //         uint256,
    //         address,
    //         address,
    //         address
    //     ));
    //     initAuction(_funder, _token, _totalTokens, _startTime, _endTime, _paymentCurrency, _factor, _minimumPrice, _admin, _pointList, _wallet);
    // }

    // /**
    //  * @notice Collects data to initialize the auction and encodes them.
    //  * @param _funder The address that funds the token for HyperbolicAuction.
    //  * @param _token Address of the token being sold.
    //  * @param _totalTokens The total number of tokens to sell in auction.
    //  * @param _startTime Auction start time.
    //  * @param _endTime Auction end time.
    //  * @param _paymentCurrency The currency the HyperbolicAuction accepts for payment. Can be ETH or token address.
    //  * @param _factor Inflection point of the auction.
    //  * @param _minimumPrice The minimum auction price.
    //  * @param _wallet Address where collected funds will be forwarded to.
    //  * @return _data All the data in bytes format.
    //  */
    // function getAuctionInitData(
    //     address _funder,
    //     address _token,
    //     uint256 _totalTokens,
    //     uint256 _startTime,
    //     uint256 _endTime,
    //     address _paymentCurrency,
    //     uint256 _factor,
    //     uint256 _minimumPrice,
    //     address _admin,
    //     address _pointList,
    //     address payable _wallet
    // )
    //     external pure returns (bytes memory _data) {
    //         return abi.encode(
    //             _funder,
    //             _token,
    //             _totalTokens,
    //             _startTime,
    //             _endTime,
    //             _paymentCurrency,
    //             _factor,
    //             _minimumPrice,
    //             _admin,
    //             _pointList,
    //             _wallet
    //         );
    //     }

    // function getBaseInformation() external view returns(
    //     address , 
    //     uint256 ,
    //     uint256 ,
    //     bool 
    // ) {
    //     return (auctionToken, marketInfo.startTime, marketInfo.endTime, marketStatus.finalized);
    // }
    
    // function getTotalTokens() external view returns(uint256) {
    //     return uint256(marketInfo.totalTokens);
    // }
}