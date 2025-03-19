// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {TrustfulOracle} from "./TrustfulOracle.sol";

contract TrustfulOracleInitializer {
    event NewTrustfulOracle(address oracleAddress);

    TrustfulOracle public oracle;

    //@audit-info this is the oracle initializer

    constructor(address[] memory sources, string[] memory symbols, uint256[] memory initialPrices) {
        oracle = new TrustfulOracle(sources, true); // deployed oracle
        oracle.setupInitialPrices(sources, symbols, initialPrices); // seting up the initial prices
        emit NewTrustfulOracle(address(oracle));
    }
}
