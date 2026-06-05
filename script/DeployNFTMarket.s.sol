// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {BootCampS2} from "../src/BootCampS2.sol";
import {MyToken} from "../src/MyToken.sol";
import {NFTMarket} from "../src/NFTMarket.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

contract DeployNFTMarketScript is Script {
    string private constant DEPLOYMENT_PATH =
        "../backend/deployments/anvil-nft-market.json";

    function run()
        external
        returns (MyToken token, BootCampS2 nft, NFTMarket market)
    {
        string memory symbol = vm.envOr("TOKEN_SYMBOL", string("ETT"));
        string memory rpcUrl = vm.envOr(
            "RPC_URL",
            string("http://127.0.0.1:8545")
        );
        address buyer = vm.envOr(
            "BUYER_ADDRESS",
            address(0xd799F70165a9704eCF66994d6384685183E4060b)
        );

        vm.startBroadcast();
        address seller = msg.sender;
        token = new MyToken(symbol);
        nft = new BootCampS2();
        bytes memory marketInitData = abi.encodeWithSelector(
            NFTMarket.initialize.selector,
            address(token),
            address(nft),
            seller
        );
        address marketProxy = Upgrades.deployUUPSProxy(
            "NFTMarket.sol:NFTMarket",
            marketInitData
        );
        market = NFTMarket(marketProxy);
        vm.stopBroadcast();

        _writeDeployment(rpcUrl, seller, buyer, token, nft, market);
    }

    function _writeDeployment(
        string memory rpcUrl,
        address seller,
        address buyer,
        MyToken token,
        BootCampS2 nft,
        NFTMarket market
    ) private {
        string memory json = string.concat(
            "{\n",
            '  "rpcUrl": "',
            rpcUrl,
            '",\n',
            '  "chainId": ',
            vm.toString(block.chainid),
            ",\n",
            '  "contracts": {\n',
            '    "token": "',
            vm.toString(address(token)),
            '",\n',
            '    "nft": "',
            vm.toString(address(nft)),
            '",\n',
            '    "market": "',
            vm.toString(address(market)),
            '"\n',
            "  },\n",
            '  "accounts": {\n',
            '    "seller": "',
            vm.toString(seller),
            '",\n',
            '    "buyer": "',
            vm.toString(buyer),
            '"\n',
            "  },\n",
            '  "deployedAt": "',
            vm.toString(block.timestamp),
            '"\n',
            "}\n"
        );

        vm.writeFile(DEPLOYMENT_PATH, json);
    }
}
