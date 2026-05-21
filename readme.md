Foundry 项目结构：

- `src/`：合约源码
- `test/`：单元测试
- `script/`：部署脚本

常用命令：

```bash
forge build
forge test
forge script script/DeployBank.s.sol:DeployBankScript --rpc-url <RPC_URL> --broadcast
```

当前合约包括 `Bank` / `BigBank` / `Admin` / `TokenBank` / `MyToken`，都已放入 `src/` 下，已可直接用 Foundry 编译。

