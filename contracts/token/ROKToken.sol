pragma solidity 0.4.10;


/// @title Abstract token contract - Functions to be implemented by token contracts.
contract Token {
    function transfer(address to, uint256 value) returns (bool success);
    function transferFrom(address from, address to, uint256 value) returns (bool success);
    function approve(address spender, uint256 value) returns (bool success);

    // This is not an abstract function, because solc won't recognize generated getter functions for public variables as functions.
    function totalSupply() constant returns (uint256 supply) {}
    function balanceOf(address owner) constant returns (uint256 balance);
    function allowance(address owner, address spender) constant returns (uint256 remaining);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}


/// @title Time limit Dutch auction contract - distribution of Rockchain tokens using a dutch auction limited in time
/// @author Sebastien Jehan - <sebastien.jehan@rockchain.org>
contract TimeLimitDutchAuction {

    /*
     *  Events
     */
    event BidSubmission(address indexed sender, uint256 amount);

    /*
     *  Constants
     */
	uint constant public MAX_BLOCK_COUNT = 100000; // Auction ends after 100K blocks (around 17 days)
    uint constant public MAX_TOKENS_SOLD = 50000000 * 10**18; // 50M
    uint constant public WAITING_PERIOD_BEFORE_TRADING = 7 days;

    /*
     *  Storage
     */
    Token public rockchainToken;
    address public wallet;
    address public owner;
    uint public ceiling;
    uint public startBlock;
    uint public endTime;
    uint public totalReceived;
    uint public finalPrice;
    mapping (address => uint) public bids;
	// follow the weighted average price while performing the auction
	uint public ongoingWeightedAveragePrice;
    Stages public stage;

    /*
     *  Enums
     */
    enum Stages {
        AuctionDeployed,
        AuctionSetUp,
        AuctionStarted,
        AuctionEnded,
        TradingStarted
    }

    /*
     *  Modifiers
     */
    modifier atStage(Stages _stage) {
        if (stage != _stage)
            // Contract not in expected state
            throw;
        _;
    }

    modifier isOwner() {
        if (msg.sender != owner)
            // Only owner is allowed to proceed
            throw;
        _;
    }

    modifier isWallet() {
        if (msg.sender != wallet)
            // Only wallet is allowed to proceed
            throw;
        _;
    }

    modifier isValidPayload() {
        if (msg.data.length != 4 && msg.data.length != 36)
            throw;
        _;
    }

    modifier timedTransitions() {
        if (stage == Stages.AuctionStarted && calcTokenPrice() <= calcStopPrice())
            finalizeAuction();
        if (stage == Stages.AuctionEnded && now > endTime + WAITING_PERIOD_BEFORE_TRADING)
            stage = Stages.TradingStarted;
        _;
    }

    /*
     *  Public functions
     */
    /// @dev Contract constructor function sets owner.
    /// @param _wallet Rockchain wallet.
    /// @param _ceiling Auction ceiling.
    function DutchAuction(address _wallet, uint _ceiling)
        public
    {
        if (_wallet == 0 || _ceiling == 0)
            // Arguments are null.
            throw;
        owner = msg.sender;
        wallet = _wallet;
        ceiling = _ceiling;
        stage = Stages.AuctionDeployed;
    }

    /// @dev Setup function sets external contracts' addresses.
    /// @param _rockchainToken Rockchain token address.
    function setup(address _rockchainToken)
        public
        isOwner
        atStage(Stages.AuctionDeployed)
    {
        if (_rockchainToken == 0)
            // Argument is null.
            throw;
        rockchainToken = Token(_rockchainToken);
        // Validate token balance
        if (rockchainToken.balanceOf(this) != MAX_TOKENS_SOLD)
            throw;
        stage = Stages.AuctionSetUp;
    }

    /// @dev Starts auction and sets startBlock.
    function startAuction()
        public
        isWallet
        atStage(Stages.AuctionSetUp)
    {
        stage = Stages.AuctionStarted;
        startBlock = block.number;
    }

    /// @dev Changes auction ceiling and start price factor before auction is started.
    /// @param _ceiling Updated auction ceiling.
    function changeSettings(uint _ceiling)
        public
        isWallet
        atStage(Stages.AuctionSetUp)
    {
        ceiling = _ceiling;
    }

    /// @dev Calculates current token price.
    /// @return Returns token price.
    function calcCurrentTokenPrice()
        public
        timedTransitions
        returns (uint)
    {
        if (stage == Stages.AuctionEnded || stage == Stages.TradingStarted)
            return finalPrice;
        return calcTokenPrice();
    }

    /// @dev Returns correct stage, even if a function with timedTransitions modifier has not yet been called yet.
    /// @return Returns current auction stage.
    function updateStage()
        public
        timedTransitions
        returns (Stages)
    {
        return stage;
    }

    /// @dev Allows to send a bid to the auction.
    /// @param receiver Bid will be assigned to this address if set.
    function bid(address receiver)
        public
        payable
        isValidPayload
        timedTransitions
        atStage(Stages.AuctionStarted)
        returns (uint amount)
    {
        // If a bid is done on behalf of a user via ShapeShift, the receiver address is set.
        if (receiver == 0)
            receiver = msg.sender;
        amount = msg.value;
        // Prevent that more than 90% of tokens are sold. Only relevant if cap not reached.
		uint currentTokenPrice = calcTokenPrice();
        uint maxWei = (MAX_TOKENS_SOLD / 10**18) * currentTokenPrice - totalReceived;
        uint maxWeiBasedOnTotalReceived = ceiling - totalReceived;
        if (maxWeiBasedOnTotalReceived < maxWei)
            maxWei = maxWeiBasedOnTotalReceived;
        // Only invest maximum possible amount.
        if (amount > maxWei) {
            amount = maxWei;
            // Send change back to receiver address. In case of a ShapeShift bid the user receives the change back directly.
            if (!receiver.send(msg.value - amount))
                // Sending failed
                throw;
        }
        // Forward funding to ether wallet
        if (amount == 0 || !wallet.send(amount))
            // No amount sent or sending failed
            throw;
        bids[receiver] += amount;
		
        totalReceived += amount;
		ongoingWeightedAveragePrice += currentTokenPrice*amount;
        if (maxWei == amount)
            // When maxWei is equal to the big amount the auction is ended and finalizeAuction is triggered.
            finalizeAuction();
        BidSubmission(receiver, amount);
    }

    /// @dev Claims tokens for bidder after auction.
    /// @param receiver Tokens will be assigned to this address if set.
    function claimTokens(address receiver)
        public
        isValidPayload
        timedTransitions
        atStage(Stages.TradingStarted)
    {
        if (receiver == 0)
            receiver = msg.sender;
        uint tokenCount = bids[receiver] * 10**18 / finalPrice;
        bids[receiver] = 0;
        rockchainToken.transfer(receiver, tokenCount);
    }

    /// @dev Calculates stop price triggering the end of the auction.
    /// @return Returns the stop price that ends the auction.
    function calcStopPrice()
        constant
        public
        returns (uint)
    {
        return 10**18 / (MAX_BLOCK_COUNT + 1);
    }
	
	/// @dev Calculates final price of the token after the auction end
    /// @return Returns the final token price common to all bidders
	function calcAuctionEndPrice()
	constant
        public
        returns (uint)
    {
        if (totalReceived > 0)
			return ongoingWeightedAveragePrice / totalReceived;
		else
			return calcStopPrice();
    }

    /// @dev Calculates token price.
    /// @return Returns token price.
    function calcTokenPrice()
        constant
        public
        returns (uint)
    {
        return 10**18 / (block.number - startBlock + 1);
    }

    /*
     *  Private functions
     */
    function finalizeAuction()
        private
    {
        stage = Stages.AuctionEnded;
        finalPrice = calcAuctionEndPrice();
        uint soldTokens = totalReceived * 10**18 / finalPrice;
        // Auction contract transfers all unsold tokens to Rockchain inventory address
        rockchainToken.transfer(wallet, MAX_TOKENS_SOLD - soldTokens);
        endTime = now;
    }
}
