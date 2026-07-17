# 超级 Agent 测试指南 · Kitchen Sink

一个「什么工具都塞进去」的 ConnectOnion agent，专门用来在 iOS 客户端里把**每一种事件界面**都点亮一遍，方便测试和改进 client。

---

## 1. 连接信息

| 项 | 值 |
|---|---|
| **地址** | `0x6c4ca3830c1723a0d8a3578d2e25aa7eed20affab3b1170285ae186edadf270c` |
| 传输 | relay（`wss://oo.openonion.ai`），远程可达，App 里直接找这个地址 |
| 身份 | `~/.co`（和你 App 里已有的那个 agent 同一个，**不用重新添加**） |
| 模型 | `co/gemini-2.5-flash`（OpenOnion 免费额度） |
| 脚本 | `scripts/super_agent.py`（本仓库） |

**启动 / 停止**（脚本用 `host()`，需在装了 `host()` 的兄弟仓库 `connectonion` 里跑）
```bash
# 启动（监听 :8000 + relay，远程可达）
cd "…/repo/connectonion"
uv run python "../capstone-project-26t2-9900-t11c-almond/scripts/super_agent.py"

# 停止：Ctrl-C，或
lsof -ti tcp:8000 | xargs kill
```
启动后终端会打印一份 `LOADED / SKIPPED` 能力报告，确认哪些工具真的挂上了。

---

## 2. 它有什么（特性）

**16 个演示工具 + 一批"真"工具 + 3 个插件**，覆盖客户端几乎所有可渲染的卡片/行。

### 工具

| 类别 | 工具 | 点亮的界面 | 需要配置 |
|---|---|---|---|
| 数学/工具 | `add/subtract/multiply_numbers`、`calculate`、`get_weather`、`current_time`、`random_number`、`roll_dice`、`flip_coin`、`word_count`、`reverse_text`、`is_prime`、`fibonacci`、`celsius_to_fahrenheit` | 工具调用（分组）卡 | — |
| 图片 | `generate_image` | agent 图片卡 | — |
| 交互·计划 | `propose_plan` | Plan Review 卡 | — |
| 交互·提问 | `ask_user` | Ask User 卡（选项 / 表单 / 密码） | — |
| 文件 | `read_file` | 工具卡（图片会转图片卡） | 视频转写才要 ffmpeg |
| 网络 | `web_fetch` | 工具卡 | — |
| 记忆/待办 | `memory`、`todo_list` | 工具卡 | — |
| **Shell（审批门控）** | `bash`、`shell` | **审批卡** → 再工具卡 | — |
| 浏览器 | `browser` | 工具卡；截图→图片卡 | 需装 Playwright + Chromium |

### 插件

| 插件 | 作用 |
|---|---|
| `re_act` | 每回合额外做「理解 + 反思」，产生 **thinking 行** |
| `image_result_formatter` | 把工具返回的 base64 图片上传并推给客户端 → 图片卡 |
| `shell_approval` | 拦截非只读 shell 命令 → 弹审批卡；只读命令（ls/cat…）自动放行 |

### 启动时被跳过（需要授权，不影响其他工具）

| 跳过 | 原因 | 怎么开 |
|---|---|---|
| `gmail`、`google_calendar` | `Missing scope`（Google OAuth 未授权） | 本机 `co auth google` 授权后重启脚本，会自动挂上 |

---

## 3. 怎么测试

在 App 里连上这个 agent，按下面发消息即可。分三档：**一句话就能测 / 需要额外条件 / 本 agent 触发不了**。

### ✅ 一句话就能测（发这句即可）

| 想看的界面 | 发这句 | 会看到 |
|---|---|---|
| 用户气泡 | 任意，如 `你好` | 右侧气泡（带附件时上方有缩略图条） |
| **回复气泡 + 打字机** | `一句话介绍你自己` | 左侧 serif 回复逐字浮现 + 洋葱光标，末尾出现 Copy/Regenerate/Share + 模型名脚注 |
| **thinking 行** | `17×23 等于多少？一步步算` | 发送后立刻出现剥洋葱动画行；LLM 调用中显示模型名，结束显示 token 数 |
| **工具（分组）卡** | `报一下悉尼天气，再掷 3 个骰子，再算 12*(4+5)` | 连续多次工具调用折叠成一张「N tool calls」卡，可展开看每次参数/结果 |
| 单个工具也走分组卡 | `悉尼今天天气？` | 一张工具卡（单个也是这个卡，不是 ToolCallCard） |
| **Ask User·选项** | `先问我一个问题：我喜欢 Python 还是 JavaScript，给这两个选项` | 带选项按钮的提问卡，会话进入等待 |
| **Ask User·表单/密码** | `让我填个表单：name 和 api_key（密码字段），再继续` | 带标签的表单，密码用 SecureField，必填校验 + Submit |
| **Plan Review 卡** | `给我出一个多步计划，先让我确认`（或 `test the plan flow`） | 蓝色计划卡：可展开的 Markdown 计划 + Approve / Revise + 反馈框 |
| **审批卡** | `用 shell 跑 mkdir /tmp/co_demo`（或 `test approval`） | 橙色「Approval needed」卡 + Approve / Always / Skip；批准后才执行 |
| **图片卡** | `生成一张红色的图片` | 回复下方内嵌图片（最大 360pt） |
| **发送/停止切换** | `打开浏览器访问 example.com，等 15 秒再总结`（任意长任务） | 生成期间 Send 箭头变 Stop 方块 |
| 记忆 / 待办 | `记住我喜欢紫色` / `帮我加个 todo：写报告` | 对应工具卡 |
| 网页抓取 | `抓一下 https://example.com 的正文` | 工具卡显示抓取结果 |
| 语音听写 | 点麦克风按钮说话（真机） | 录音波形条 + 「Listening m:ss」状态、实时转写进输入框 |

### ⚠️ 需要额外条件

| 界面 | 触发 | 前置条件 |
|---|---|---|
| 浏览器截图 → 图片卡 | `打开浏览器截个图` | 本机装好 Playwright + Chromium |
| 附件 sheet / 预览条 / files_received | 点 `+` 选图/文件后发送 | agent 要声明接受 image/file 输入（AgentAcceptedInputs） |
| 错误 / 重连横幅 | 发消息后停掉 agent 服务器或断网 | 需要制造断线 |
| 会话恢复 | 发几条 → 强退重开会话 | 重连时服务器用 `chat_items` 重建整条时间线 |
| Skill 命令面板 | 输入 `/` | 面板会打开但**列表为空**——本 agent 未声明任何 skill |
| Gmail / 日历工具 | `看看我今天的日程` | Google OAuth（见 §2），否则工具自跳过、不产生工具调用 |

### ❌ 本 agent 触发不了（需要 `co_ai` 才加载的插件）

这些界面客户端支持，但**我们这个 super_agent 没装对应插件**，发什么都不会出。想测就把 App 连到一个 `co` CLI 起的 `co_ai` agent（它加载了下列插件）：

| 界面 | 需要的插件（本 agent 未装） |
|---|---|
| Intent 行「Understanding…」 | `system_reminder`（本 agent 用 `re_act`，只出 thinking 行） |
| Evaluation 行 | `eval` |
| Context 压缩行 | `auto_compact` |
| tool_blocked 提示 | `prefer_write_tool` |
| diff_preview 预览 | `DiffWriter` |
| ULW 续跑检查点 | `ulw` |
| 验证/邀请码/付费卡 | 服务端 trust-gate 配置（本 agent `trust=open`，不触发） |

---

## 4. 五分钟冒烟测试（按顺序发）

一条龙覆盖大部分界面：

1. `你好，一句话介绍你自己` — 打字机 + thinking 行 + 回复动作条
2. `报一下悉尼天气，再掷 3 个骰子，再算 12*(4+5)` — 工具分组卡
3. `先问我一个问题：Python 还是 JavaScript，给这两个选项` — Ask User 卡（点一个选项）
4. `给我出一个多步计划先让我确认` — Plan Review 卡（点 Approve / Revise）
5. `用 shell 跑 mkdir /tmp/co_demo` — 审批卡（点 Approve）
6. `生成一张紫色的图片` — 图片卡
7. `记住我喜欢紫色` + `帮我加个 todo：写报告` — 记忆/待办工具卡

---

## 5. 注意事项

- **只连 almond 仓库那份 App**（`capstone-project-26t2-9900-t11c-almond`，main）。旁边的 `connectonion-ios`（xcode26 分支）是旧的扁平版，没有打字机、没有工具分组卡，上面的用例会对不上。
- **回复没有 token 级流式**：`host()` 全程只推结构化事件（llm_call/tool_call/thinking…），正文只在最后一帧 `OUTPUT` 里到达；客户端的"打字机"是拿到全文后自己逐字放出来的。任何指望「实时 assistant token」的代码都是死代码。
- **审批只对非只读命令弹卡**：`ls / cat / grep` 之类会被自动放行；要看审批卡就用 `mkdir / rm / touch` 这类写操作。
- **图片卡需 `OPENONION_API_KEY`**（上传用）——本 agent 已用 `~/.co` 认证，自带。
- **改进 client**：哪个界面渲染不对、或想让它多支持某类事件（如 diff_preview / eval），把截图或现象发我，对着源码改。
