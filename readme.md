
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




 新建 frontend 目录，创建一个前端工程，为 TokenBank 合约添加前端界面：
1. 显示当前  Token 的余额，并且可以存款到 TokenBank
2. 存款后显示用户存款金额，同时支持用户取款。
3. 使用  wagmi  和  react  框架完成
