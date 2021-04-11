pragma solidity ^0.6.6;

import "@chainlink/contracts/src/v0.6/interfaces/AggregatorV3Interface.sol";
import "@chainlink/contracts/src/v0.6/ChainlinkClient.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract LandPriceOracle is ChainlinkClient, Ownable {
    AggregatorV3Interface internal priceFeedMANAETH;
    AggregatorV3Interface internal priceFeedEthUSD;
    uint256 public landPriceInMana;
    address private oracle;
    bytes32 private jobId;
    uint256 private fee;

    constructor() public {
        // On Kovan displaying the USD price instead although chainlink has ETH/MANA
        // https://market.link/feeds/a2bd0cee-8150-4298-8290-ae45ea29e88c?network=42
        // MainNet - https://market.link/feeds/a572e5a5-6c2a-4f56-80a6-bd976a5de845?network=1 and https://data.chain.link/mana-eth
        priceFeedMANAETH = AggregatorV3Interface(
            0x1b93D8E109cfeDcBb3Cc74eD761DE286d5771511
        );
        // Since we can't get the price from chainlink with one feed, we will have to calculate it.
        priceFeedEthUSD = AggregatorV3Interface(
            0x9326BFA02ADD2366b30bacB125260Af641031331
        );

        setPublicChainlinkToken();
        oracle = 0x2f90A6D021db21e1B2A077c5a37B3C7E75D15b7e;
        jobId = 0x3239666139616131336266313436383738386237636334613530306134356238;
        fee = 0.1 * 10**18; // 0.1 LINK
    }

    mapping(address => bool) public oracleWhitelisted;
    // List of addresses who can update prices.
    modifier oracleWhitelist() {
        require(
            oracleWhitelisted[msg.sender] == true,
            "Reason: No permission to update."
        );
        _;
    }

    // Set contracts that are able to make request to update the price
    function setOracleWhitelist(address _address) public onlyOwner {
        oracleWhitelisted[_address] = true;
    }

    /**
     * Returns the latest ETH price in USD
     */
    function getLatestETHPrice() public view returns (uint256) {
        (
            uint80 roundID,
            int256 ETHprice,
            uint256 startedAt,
            uint256 timeStamp,
            uint80 answeredInRound
        ) = priceFeedEthUSD.latestRoundData();
        return uint256(ETHprice);
    }

    /**
     * Returns the latest MANA price in USD
     */
    function getLatestManaPrice() public view returns (uint256) {
        (
            uint80 roundID,
            int256 manaPrice,
            uint256 startedAt,
            uint256 timeStamp,
            uint80 answeredInRound
        ) = priceFeedMANAETH.latestRoundData();
        return uint256(manaPrice);
    }

    // Calculates how much Mana can you get per one ETH
    function manaPerEth() public view returns (uint256) {
        uint256 ManaPrice = getLatestManaPrice();
        uint256 ETHPrice = getLatestETHPrice();
        return (ManaPrice * ETHPrice) / 1e8;
    }

    function landIndexTokenPerEth() public view returns (uint256) {
        uint256 lastManaPerEth = manaPerEth();
        uint256 lastLandIndexTokenPerEth =
            (lastManaPerEth * 1e18) / landPriceInMana;
        return lastLandIndexTokenPerEth;
    }

    function requestLandData()
        public
        oracleWhitelist
        returns (bytes32 requestId)
    {
        Chainlink.Request memory request =
            buildChainlinkRequest(jobId, address(this), this.fulfill.selector);

        // Set the URL to perform the GET request on
        request.add(
            "get",
            "https://whispering-beyond-26434.herokuapp.com/decentraland/orders/price-mean/750"
        );
        request.add("path", "mean");
        // Sends the request
        return sendChainlinkRequestTo(oracle, request, fee);
    }

    /**
     * Receive the response in the form of uint256
     */

    function fulfill(bytes32 _requestId, uint256 _landPriceInMana)
        public
        recordChainlinkFulfillment(_requestId)
    {
        landPriceInMana = _landPriceInMana;
    }
}
