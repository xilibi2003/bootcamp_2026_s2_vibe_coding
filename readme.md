
这是一个 Foundry 项目， 项目结构：

- `src/`：合约源码
- `test/`：单元测试
- `script/`：部署脚本

常用命令：

```bash
forge build
forge test
forge script script/DeployBank.s.sol:DeployBankScript --rpc-url <RPC_URL> --broadcast
```


编写一个新市场合约 NFTMarket, 使用 MyToken 来买 BootCampS2 NFT  , NFTMarket 有两个方法：

list(): NFT 持有者可上架 NFT（设置价格 多少个 TOKEN 购买 NFT  ）
buyNFT(uint tokenID, uint amount): 编写购买 NFT 方法 ，转入对应的TOKEN，获取对应的  NFT 


实现 ERC20 扩展 Token 所要求的接收者方法 tokensReceived ，在 tokensReceived 中实现NFT 购买功能(注意扩展的转账需要添加一个额外数据参数)。