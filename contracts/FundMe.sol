// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import "./PriceConverter.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

error FundMe__NotOwner();
error FundMe__NotEnoughFunds(address from, uint256 amount, uint256 minimumAmount);
error FundMe__WithdrawFailed();
error FundMe__NoBalance();
event FundMe__AmoundFunded(address indexed from, uint256 amount);
event FundMe_AmountWithdrawed(address indexed to, uint256 amount);

contract FundMe {
    using PriceConverter for uint256;
    uint256 private constant MINIMUM_USD = 50 * 1 ether;
    address private immutable i_owner;
    AggregatorV3Interface private s_priceFeed;
    address[] private s_funders;
    mapping(address => uint256) addressToAmoundFunded;


    constructor(address priceFeed) {
        i_owner = msg.sender;
        s_priceFeed = AggregatorV3Interface(priceFeed);
    }

    modifier onlyOwner() {
        if (msg.sender != i_owner) revert FundMe__NotOwner();
        _;
    }

    modifier minimumFunds(uint256 value) {
        if(value.getConversionRate(s_priceFeed) < MINIMUM_USD) revert FundMe__NotEnoughFunds({ from: msg.sender, amount: value, minimumAmount: MINIMUM_USD });
        _;
    }

    function fund() external payable minimumFunds(msg.value) {
        s_funders.push(msg.sender);
        addressToAmoundFunded[msg.sender] += msg.value;
        emit FundMe__AmoundFunded(msg.sender, msg.value);
    }

    function receive() external payable minimumFunds(msg.value) {
        s_funders.push(msg.sender);
        addressToAmoundFunded[msg.sender] += msg.value;
        emit FundMe__AmoundFunded(msg.sender, msg.value);
    }

    function withdraw() external onlyOwner {
        uint256 totalBalance = address(this).balance;
        if (totalBalance == 0) revert FundMe__NoBalance();

        (bool success, ) = payable(i_owner).call{ value: totalBalance }("");
        if(!success) revert FundMe__WithdrawFailed();

        for(uint256 indx = 0; indx < s_funders.length; indx++ ) {
            addressToAmoundFunded[s_funders[indx]] = 0;
        } 

        s_funders = new address[](0);
        emit FundMe_AmountWithdrawed(i_owner, totalBalance);
    }

    function getVersion()  public view returns(uint256) {
        return s_priceFeed.version();
    }

    function getFunder(uint256 index) public view returns(address) {
        return s_funders[index];
    }

    function getOwner() public view returns(address) {
        return i_owner;
    }

    function getPriceFeed() public view returns(AggregatorV3Interface) {
        return s_priceFeed;
    }
}