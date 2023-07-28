Dynametric is a full-range constant product market maker, inspired by Uniswap v2. 
It has three major differences:
1. Fees are dynamic. This benefits traders by not fragmenting liquidity and LPs by simplifying the UX, as well as enabling LPs to take higher fees during times of increased volatility. This mechanism design is inspired by Trader Joe v2's dynamic fees.
2. Fees are asymmetric. When the AMM price differs from the true price, the fee is manipulated. Traders that push the AMM price closer to the true price pay a smaller fee; traders that push the AMM price further from the true price pay a larger fee. This mechanism design is inspired by Alex Nezlobin's proposal (https://twitter.com/0x94305/status/1674857993740111872).
3. The contract is a singleton contract. This is mostly for simplicity's sake, as this is a Proof of Concept.

Types of Users:
- traders
- liquidity providers

Traders:
- swap exact input tokens for some amount of output tokens (with slippage protections)
- swap some input tokens for exact amount of output tokens (with slippage protections)

Liquidity providers:
- create liquidity pools
- add liquidity by depositing an equal amount of both tokens in a pool
- remove liquidity by withdrawing tokens from a pool

Roadmap:
- [x] swapExactInputForOutput
- [x] createPool
- [x] scripting
- [x] testing
- [x] fees
- [x] testing
- [x] dynamic fees
- [x] testing
- [x] swapInputForExactOutput 
- [x] testing 
- [x] refactoring
- [x] add liquidity (+ refactoring)
- [x] remove liquidity (+ refactoring)
- [ ] testing
- [x] refactoring
- [ ] invariant testing (special attention to dynamic fees)
<!-- - [ ] asymmetric fees -->
<!-- - [ ] testing -->
  

////////////////////////////////////////////
///////////    OPEN QUESTIONS    ///////////
////////////////////////////////////////////

1. Should I add the Pool to both sides of the mapping? If so, I'll need to create an array of pools, with each mapping being to a uint256
2. 