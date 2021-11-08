pragma solidity >=0.6.0 <0.7.0;

import "hardhat/console.sol";
import "./ExampleExternalContract.sol"; //https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol

contract Staker {

  ExampleExternalContract public exampleExternalContract;

  mapping (address => uint256) public balances;
  uint256 public constant threshold = .009 ether;
  uint256 public deadline = now + 1 minutes;
  enum State { Staking, OpenForWithdraw, Success }
  State state = State.Staking;

  event Stake(address author, uint256 amount);

  constructor(address exampleExternalContractAddress) public {
    exampleExternalContract = ExampleExternalContract(exampleExternalContractAddress);
  }



  // Collect funds in a payable `stake()` function and track individual `balances` with a mapping:
  //  ( make sure to add a `Stake(address,uint256)` event and emit it for the frontend <List/> display )
  function stake() public payable {
      require (state == State.Staking, "Staking no longer enabled");

      balances[msg.sender] = balances[msg.sender] + msg.value;
      emit Stake(msg.sender, msg.value);
  }


  // After some `deadline` allow anyone to call an `execute()` function
  //  It should either call `exampleExternalContract.complete{value: address(this).balance}()` to send all the value
  function execute() public returns (bool) {
      require (now > deadline, "Deadline not reached yet");
      require (state != State.Success, "Balance successfully sent! No more need to execute.");
      require (state != State.OpenForWithdraw, "Execute called after deadline, before threshold met. Withdraw enabled.");

      //We are past the deadline => either complete payment or enable withdraws
      if (address(this).balance > threshold) {
        exampleExternalContract.complete{value: address(this).balance}();
        state = State.Success;
        return true;
      } else {
        state = State.OpenForWithdraw;
        return false;
      }
  }


  // if the `threshold` was not met, allow everyone to call a `withdraw()` function
  function withdraw(address payable recipient) public returns (uint256) {
    require(state == State.OpenForWithdraw, "Not open for withdraw");
    require(balances[msg.sender] > 0, "No money to withdraw");

    uint256 amount = balances[msg.sender];
    balances[msg.sender] = 0;
    recipient.transfer(amount);
    return amount;
  }



  // Add a `timeLeft()` view function that returns the time left before the deadline for the frontend
  function timeLeft() public view returns (uint256) {
    if (now >= deadline) return 0;
    return deadline - now;
  }

  function openForWithdraw() public view returns (bool) {
    return state == State.OpenForWithdraw;
  }

  // Add a receive function to catch any eth inadvertantly sent to the contract address itself
  receive() external payable {
    require(state == State.Staking, "Staking no longer enabled");
    stake();
  }

}