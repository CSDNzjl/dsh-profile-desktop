# dsh-profile-desktop

DeepSeek Harness 的 **profile 插件配置** 备份仓库。用于在多台电脑之间同步插件安装状态。

## 这个仓库是什么

DSH 的插件组合由 profile 目录决定（默认 `%USERPROFILE%\.dsh\profiles\<profile>\`）。这个仓库保存了其中**可安全公开的部分**：

| 文件 | 作用 |
|---|---|
| `package.json` | 依赖清单 + `dsh.profile.bundles`（决定装哪些插件、按什么顺序组成插件树） |
| `cordis.patch.yml` | 用户补丁层：模型默认值、权限预设、插件参数覆盖 |
| `cordis.yml` | profile 根（空数组，组合全靠 patch 叠加） |
| `pnpm-lock.yaml` | 锁定精确版本，保证换机器装出一模一样的依赖树 |
| `pnpm-workspace.yaml` | pnpm 行为配置（`nodeLinker: hoisted` 等，**必须保留**） |

## 这个仓库**不**包含什么

以下内容含敏感信息，已被 `.gitignore` 排除，永远不要提交：

- `.credentials.yaml` —— API token（OpenAI/OpenCode/GitHub 等）
- `remote-workspaces/machines.json` —— SSH 机器清单，**含明文密码**
- `dsh-pocket/token` 、`token-lan` —— 局域网/公网访问密码
- `sessions/` —— 会话记录（体积大且含对话内容）

换机器后需要**手动重新配置**这些。

## 在新电脑上恢复

### 前置条件

1. 已安装 DeepSeek Harness
2. 已安装 Node.js（用于跑 pnpm）

### 一键恢复

```powershell
git clone https://github.com/CSDNzjl/dsh-profile-desktop.git
cd dsh-profile-desktop
powershell -ExecutionPolicy Bypass -File .\restore.ps1
```

`restore.ps1` 会：

1. 把 5 个配置文件复制到 `%USERPROFILE%\.dsh\profiles\desktop\`
2. 自动定位 DSH 自带的 pnpm（`dsh-runtimes\*\dependencies\pnpm`）
3. 执行 `pnpm install` 装齐所有插件

### 手动恢复（脚本失败时）

```powershell
# 1. 复制配置
$src = ".\*.json", ".\*.yaml", ".\*.yml"
Copy-Item $src "$env:USERPROFILE\.dsh\profiles\desktop\" -Force

# 2. 装依赖（用 DSH 自带的 node + pnpm）
$node = "$env:USERPROFILE\.dsh\dsh-runtimes\dsh-primary-runtime\dependencies\node\bin\node.exe"
$pnpm = "$env:USERPROFILE\.dsh\dsh-runtimes\dsh-primary-runtime\dependencies\pnpm\bin\pnpm.mjs"
& $node $pnpm install --dir "$env:USERPROFILE\.dsh\profiles\desktop"
```

### 恢复后还要做

重启 DSH，然后：

1. **重新登录各服务** —— OpenCode Go / DeepSeek 账号等，token 不在仓库里
2. **重新配置 dsh-remote 机器** —— 按 `machines.json` 格式自己写，或走设置页
3. **检查 dsh-pocket 密码** —— 会重新生成，需要重新扫码

## 当前插件清单

见 `package.json` 的 `dsh.profile.bundles`。维护时注意：

- **`dsh-remote` 已关闭自更新**（`updateMode: off`）。它的 auto 模式会在启动时就地覆盖包文件、删除 pnpm 建的嵌套依赖链接（如 `iconv-lite`），导致加载失败。升级请手动改版本号 + 重新 `pnpm install`。
- `pnpm-workspace.yaml` 里的 `nodeLinker: hoisted` 是必须的，DSH profile 用的是扁平布局。

## 更新这个备份

在本机改完插件配置后：

```powershell
$src = "$env:USERPROFILE\.dsh\profiles\desktop"
Copy-Item "$src\package.json","$src\cordis.patch.yml","$src\cordis.yml","$src\pnpm-lock.yaml","$src\pnpm-workspace.yaml" . -Force
git add -A
git commit -m "sync: 插件配置更新"
git push
```

**提交前务必确认 `git status` 里没有出现凭据或 machines.json。**
