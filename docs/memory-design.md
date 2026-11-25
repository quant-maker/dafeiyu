# 大肥鱼的记忆系统 —— 设计与讨论稿

> 目标：让她记得住、想得起、还能被我看见。
> 三个约束：跑在手机上、只有网关（chat + embedding）可用、我对她的记忆要能一眼看懂。

---

## 0. 现在是什么样（v0.15.6 实测）

| 层 | 实现 | 位置 | 硬伤 |
|---|---|---|---|
| 事实 | `Memory.facts`：`List<String>`，上限 24 条，`merge()` 用「子串互相包含」去重，超出 **FIFO 丢最早的一条** | `lib/main.dart:322-355` | 没有重要度、没有时间、没有主题；「我叫小七」可能被第 25 条闲聊挤掉 |
| 情景 | `Archive`：每 20 轮把对话压成 200 字摘要 + 2560 维向量，余弦检索 k=3，阈值 0.3 | `lib/memory/archive.dart` | **单层**，没有天/周/月分层；`_summarized` 指针只在内存，重启可能重复摘要 |
| 存储 | 全部塞 `SharedPreferences`，档案是**一个 JSON 字符串**，上限 2000 条 | `feiyu.archive.v1` | 2560 维×4 位小数 ≈ 20KB/条 → 2000 条 ≈ **40MB**；每次 `add` 全量重写、启动全量解析（O(n)），web 端 localStorage 5MB 直接爆 |
| 检索 | 只用 query embedding 单跳 + 关键词兜底 | `lib/main.dart:2708` | 没有关键词索引、没有时间窗、没有沿关系联想、没有重排 |
| 结构 | 无实体、无关系 | — | 回答不了「上次那个项目现在怎么样了」 |

一句话：**现在是三张便利贴，不是记忆。**

---

## 1. 四层记忆 + 一张星图

```
                    ┌──────────── 星图（Entity Graph）────────────┐
                    │  人 · 项目 · 地点 · 主题 · 承诺   + 关系边   │  ← 我"看见"的那层
                    └───────────────┬─────────────────────────────┘
                                    │ 每颗星都能展开到证据
  L3 归档   MonthCard ← WeekCard ← DayCard ←（只折上一层，谱系永活）
  L2 语义   Fact(subject, predicate, object, confidence, 首次/最近, 证据id)
  L1 情景   Episode(时间, 说了什么, 摘要, 原文指针, 向量, 重要度)
  L0 工作   当前会话最近 N 轮 + 今天两条摘要（现在就有）
```

四条设计铁律（从 billion-context 直接搬，理由见 §6）：

1. **只压增量，绝不重写历史** —— 旧摘要一旦生成就不再重新生成，新内容在自己那一层压。留存率不随轮数复合衰减（每轮重摘会 ρ^k 几何衰减，四轮只剩 3–13%）。
2. **模型驱动** —— 什么时候压、压哪段、留什么由她自己判断；阈值触发只会「不感知 / 无法拒绝 / 无法选择」。
3. **保留谱系** —— 每个块记住 `directIds` 与 `effectiveIds`（覆盖的全部原始消息），任何一层都能展开到底。
4. **可逆** —— 衰减只降权重不删数据；失效的事实标 `invalidatedAt` 而不是 DELETE。

---

## 2. 数据模型（drift / SQLite）

```sql
-- 情景：每次「值得记住的一次交流」
CREATE TABLE episode(
  id INTEGER PRIMARY KEY,
  at      INTEGER NOT NULL,        -- 毫秒时间戳
  session TEXT,                    -- 会话 id
  place   TEXT,                    -- 来自设备/照片/作息推断，可空
  title   TEXT NOT NULL,           -- 一句话：这件事是什么
  body    TEXT NOT NULL,           -- 摘要，≤300 字
  raw_ref TEXT,                    -- 原始消息 id 区间，用于展开
  weight  REAL NOT NULL DEFAULT 1, -- 重要度 1..5，归一化后使用
  vec     BLOB                     -- int8[1024]，见 §5
);
CREATE VIRTUAL TABLE episode_fts USING fts5(title, body, tokenize='unicode61');

-- 语义：可校验的事实（取代 24 条便利贴）
CREATE TABLE fact(
  id INTEGER PRIMARY KEY,
  subject TEXT NOT NULL,           -- '主人' / '大肥鱼' / '项目X'
  predicate TEXT NOT NULL,         -- '喜欢' / '在做' / '承诺过'
  object TEXT NOT NULL,
  confidence REAL NOT NULL,        -- 抽取置信度 0..1
  importance INTEGER NOT NULL,     -- 1..5
  first_seen INTEGER NOT NULL,
  last_seen  INTEGER NOT NULL,
  hit_count  INTEGER NOT NULL DEFAULT 1,
  evidence_episode INTEGER,        -- 指向 episode.id，可核对
  invalidated_at INTEGER           -- 有值 = 被更新的事实取代，不删
);

-- 实体：星图上的星
CREATE TABLE entity(
  id INTEGER PRIMARY KEY,
  name TEXT NOT NULL UNIQUE,       -- 归一化后
  alias TEXT,                      -- JSON 数组，'小七','七七' → 同一颗星
  kind TEXT NOT NULL,              -- person|project|place|topic|promise|thing
  importance INTEGER NOT NULL DEFAULT 3,
  strength REAL NOT NULL DEFAULT 1.0, -- 记忆强度，随时间衰减、被检索回涨
  first_seen INTEGER, last_touched INTEGER,
  summary TEXT,                    -- 这颗星的"说明"，可被重写（唯一允许重写的地方）
  x REAL, y REAL                   -- 布局缓存
);

-- 关系：星之间的边
CREATE TABLE edge(
  id INTEGER PRIMARY KEY,
  src INTEGER NOT NULL, dst INTEGER NOT NULL,
  kind TEXT NOT NULL,              -- semantic|temporal|causal|entity|mentions
  label TEXT,                      -- '同事' '正在做' '承诺' ...
  weight REAL NOT NULL DEFAULT 1,
  first_seen INTEGER, last_seen INTEGER,
  evidence_episode INTEGER,
  invalidated_at INTEGER
);

-- 分层块：DayCard / WeekCard / MonthCard
CREATE TABLE block(
  id INTEGER PRIMARY KEY,
  tier INTEGER NOT NULL,           -- 1=day 2=week 3=month
  topic TEXT,
  summary TEXT NOT NULL,
  direct_ids TEXT NOT NULL,        -- JSON: 上一层的 block id 或 episode id
  effective_ids TEXT NOT NULL,     -- JSON: 覆盖到的全部 episode id（谱系）
  created_at INTEGER NOT NULL,
  span_from INTEGER, span_to INTEGER
);
```

`block` 表就是 billion-context 的 `CompressionBlock`（tier / directIds / effectiveIds / survivedCount），只是把「消息」换成「片段/块」。

---

## 3. 写入（capture）——什么时候记

- **触发**：一轮结束 200ms 后异步跑；或事件驱动（出现新实体 / 偏好词 / 承诺词 / 情绪转折 / 用户纠正她）。
- **先本地筛**：字数 < 6、纯表情、纯语气词直接跳过，不花 token。
- **一次抽取，四类产出**（严格 JSON，失败就当没发生）：

```json
{ "episode": {"title":"...", "body":"...", "weight":3},
  "facts":   [{"s":"主人","p":"在做","o":"量化策略回测","c":0.9,"i":4}],
  "entities":[{"name":"量化策略","kind":"project","importance":4}],
  "edges":   [{"src":"主人","dst":"量化策略","kind":"semantic","label":"正在做"}] }
```

- **合并规则**：实体按 `name`/`alias` 归一；事实按 `(subject,predicate)` 唯一——新值把旧值 `invalidated_at = now`（**双时间：既记"当时为真"，也记"何时被推翻"**，Graphiti 的做法）；`last_seen`/`hit_count` 累加，重复提及让记忆变亮。
- **成本**：每天 100 轮 ≈ 20–30 次抽取 + 每条一个 embedding。抽取走便宜的模型，只在有新信息时调用。

---

## 4. 读取（recall）——怎么想起来

每轮组装 prompt 时，预算 **800–1200 token** 分三档给：

1. **常驻**：`Memory.asPrompt()` 的等价物（≤12 条高重要度事实）+ 今天最近的 2 条摘要。
2. **按需**：混合召回后取 top 8。
3. **联想**：从命中的实体出发，沿边 1 跳再取 top 4（HippoRAG 的 Personalized PageRank 简化版：以命中实体为种子做 2 轮随机游走，按停留概率排序）。

混合打分（Generative Agents 的 recency × importance × relevance，加时间与重复增强）：

```
score = 0.5·rel + 0.2·imp + 0.2·rec + 0.1·rep
rel  = max(cos(q,e), bm25_norm(q,e))          # 向量与关键词取大，互为兜底
imp  = weight/5
rec  = exp(-Δdays / 14)                        # 两周半衰
rep  = min(hit_count/5, 1)
```

图扩展的节点用 `strength` 排序，`strength` 由衰减 + 命中回涨维护：

```
strength ← max(0.15, strength · exp(-Δt/τ))
命中一次：strength ← min(1, strength + 0.3)
τ: person 180d / project 90d / topic 30d / 琐事 7d
```

低于阈值不删，只是星变暗、召回权重降低（可逆）。

---

## 5. 向量与检索工程

- 网关实测可用：`Qwen/Qwen3-Embedding-4B`，**2560 维**，单条 147–572ms（`/embeddings`，与 chat 同一个 key）。
- 2560×4B = 10KB/条太胖。方案：**int8 量化 + 维数截断到 1024**（Qwen3-Embedding 支持 MRL 截断，截断后 L2 归一化仍可用）→ **1KB/条**，10 万条 = 100MB，手机也能扛。
- 检索：先 FTS5 关键词取 200 条，再在候选上算 int8 余弦（AVX-less，Dart 里手写 SIMD-ish 批量点积，1 万条 × 1024 维 ≈ 10M 次乘加，几十毫秒）；向量全扫只在「候选不足」时兜底。
- 若截断质量不达标 → 退一步：只对最近 20000 条建向量，其余靠 FTS + 图扩展（记忆的「远层」本来就该靠关键词和关系找）。
- 落库：SQLite（drift）。手机走 native sqlite3（FTS5 自带 BM25）；web 走 drift 的 wasm（多约 1.1MB，相对现在 34MB 的 web 包可接受）。

---

## 6. 星图（Galaxy）—— 我要看懂的那一层

### 视觉

```
        ·            ✦ 项目:回测        ·
          ✦ 同事:阿May      ╲
               ╲            ✦ 主题:量化
        ✦ 主人 ────────✦ 承诺:周末讲这个
               ╱            ╱
        ✦ 地点:公司工位   ✦ 事件:昨天熬夜
   （亮 = 最近/常被想起；暗 = 久未触碰；大小 = 重要度；光晕 = 今天激活过）
```

- **颜色**：人=玉绿 `#8FD3C4`、项目=琥珀 `#E0B15F`、地点=雾蓝 `#7FA6C9`、主题=灰紫 `#A79BC4`、承诺=珊瑚 `#D9786B`、事件=白点。
- **大小** `r = 4 + 10·(importance/5)·strength`
- **亮度/透明**：`alpha = 0.25 + 0.75·strength` —— 久不想起的星慢慢暗下去，但还在那儿。
- **边**：语义边实线、时间边虚线；`alpha` 随 `weight`；被「当前话题」波及的边脉冲一次。
- **布局**：力导向（斥力 O(n²) 用网格分桶降到 O(n)，吸引沿边、向心力轻微拉向中心），**只算一次存 `entity.x/y`**，拓扑变化才增量重算（每次 ≤120 帧，后台 isolate 跑）。
  - 备选：径向星系（中心=我，环=人/项目/主题/事件，按最近性螺旋排列）。先做力导向，效果不好再换。
- **星座**：社区发现（标签传播，几十行）把密集子图染色成「星座」，点击星座先把成员折叠成一颗大星 + 名字，再点展开——解决节点 >300 时的视觉爆炸。

### 交互

| 动作 | 效果 |
|---|---|
| 拖动 / 双指缩放 | `InteractiveViewer` 变换，不重排 |
| 点一颗星 | 底部升起卡片：这颗星是什么、几条关系、最近 3 条证据（可点开原文） |
| 长按「让她讲这件」 | 把这颗星 + 一跳邻居塞进下一轮上下文，她会主动提起 |
| 右上角时间滑杆 | 拖到过去某天 → 星图回到那天的状态（双时间模型送的礼物） |
| 设置里「记忆体检」 | 条数、占用 MB、最近 7 天召回次数、导出 JSON、清空 |

### 实现

`CustomPainter` 自画（≈250 行 + 力导向 ≈150 行），**不引第三方**：`flutter_force_directed_graph` 是单线程 rebuild、`force_graph` 拖进 Forge2D 物理引擎，都不如自己算一遍存坐标。缩放用 `InteractiveViewer`，星点命中测试自己做（屏幕坐标反变换）。

---

## 7. 夜间整理（sleep）

应用不在前台 / 凌晨安静时段，跑一次「整理」（对应 mnemon 的 `idle-review`）：

1. 日结：当天 episodes → 一张 DayCard（KEEP：决定、承诺、情绪转折、新实体、精确数字；DROP：寒暄、重复、已提取的废话）。
2. 周结 / 月结：只在块数够时折下一层。
3. 社区发现 + 重算 `summary`。
4. 衰减：批量更新 `strength`。
5. 去重：近乎重复的事实合并，`hit_count` 相加。

手机端用 `workmanager`（Android）触发；web 端退化为「下次打开时补做」。

---

## 8. 分期

| 期 | 做什么 | 产出 | 估时 |
|---|---|---|---|
| **P0** | drift + 表结构 + 迁移（把现有 facts/archive 导入）+ 事实按重要度保留（去掉 24 条 FIFO） | 存储不炸，旧记忆不丢 | 1–2 天 |
| **P1** | Episode 抽取 + 日结 + 分层块（day/week/month）+ KEEP/DROP 提示词 | 记忆开始「有厚度」 | 2 天 |
| **P2** | 实体/关系抽取 + 别名归一 + 双时间失效 | 星图有了数据 | 2 天 |
| **P3** | 星图页面（布局 + 绘制 + 详情卡 + 「让她讲这件」+ 时间滑杆） | 我能看见了 | 2–3 天 |
| **P4** | 混合检索（FTS5 + int8 向量 + PPR 扩展 + 打分公式）+ 记忆体检面板 | 她真的想得起来 | 2 天 |
| **P5** | 夜间整理 + 导出/清空 + 隐私开关（只存本地不进 prompt） | 能长期用 | 1–2 天 |

P0 是地基，先做；P3 的星图可以提前到 P2 之后立刻做一版「只有事实没有关系」的雏形，先看效果再决定投入。

---

## 9. 可借的现成件（本机已装，免得重造）

- `dsh-mnemon` 三层策略：runtime 常驻 / documents 叙事 / spaces 证据，每轮配额「1 次文档查询 4 条 / 2 次召回共 6 条 / 1 次图遍历」，声明 `idle-review` 与 `runtime-capacity` 两个 workflow —— **和我们的四层结构一一对应**，只是它跑在 Host 上，手机端得自建。
- `dsh-mnemon-provider-mnemon-native`：typed relations `temporal|semantic|causal|entity` + soft delete；`-holographic`：本地结构化事实 + trust metadata + entities + evidence。→ 数据模型照搬，省得发明。
- `billion-context`：块结构、只压增量、KEEP/DROP 清单、`decompress` 可逆、`mNNNNN` 稳定 id —— 见 `paper/模型驱动的分层增量压缩-免训练多代上下文管理.md`。
- 外部参考：[Graphiti](https://help.getzep.com/graphiti/getting-started/overview)（双时间 + 边失效 + 混合检索 + 社区）、[HippoRAG](https://github.com/OSU-NLP-Group/HippoRAG)（PPR 多跳联想）、[A-Mem](https://github.com/WujiangXu/A-mem)（Zettelkasten 式自动建链）、[Generative Agents](https://dl.acm.org/doi/fullHtml/10.1145/3586183.3606763)（recency×importance×relevance）、[Mem0 对比](https://dawnloop.ai/blog/mem0-vs-zep-vs-letta)。

---

## 10. 待你拍板

1. **存储层**：drift（SQLite FTS5，web 多 1.1MB wasm）还是继续 SharedPreferences + 分片 JSON？我推荐 drift。
2. **向量**：截断到 1024 维 int8（省 10 倍，可能要折损一点召回）还是保留 2560 维但只索引最近 2 万条？
3. **星图布局**：力导向（自然、能看出聚类）还是径向星系（更像"星系"、更稳）？
4. **主动性联动**：星图上久未触碰的星，要不要成为「主动找你」的素材来源（比如"上次那个回测跑完了吗"）？
5. **隐私**：默认允许把摘要/事实发给网关（现在就是这样），还是要加「敏感话题只存本地不进 prompt」的自动识别？

---

## 11. 拍板结果与 P0 进度

已定（2026-11-25）：

1. **sqlite / drift**，web 用 wasm。
2. **向量 int8 + 截断到 1024 维**（等价于线性变换的降维，MRL 友好）。
3. **星图布局我定**：力导向 + 社区聚类。
4. **要**：久未触碰的星进入「主动找你」的候选素材。
5. **隐私我定**：默认本地优先，敏感话题自动打 `local_only` 不进 prompt、不外发。

P0 已完成（代码在 `lib/memory/`）：

- `db.dart` + `db.g.dart`：六张表（`episodes / facts / entities / edges / blocks / meta`）、`episode_fts` 触发器、索引、`schemaVersion = 1`。
  - 坑：事实表列名不能叫 `text`（撞 drift 的 `Table.text()`），已改名 `content`。
- `db_conn_io.dart`（`NativeDatabase.createInBackground`）/ `db_conn_web.dart`（`WasmDatabase.open` + worker）/ `db_conn.dart`（条件导出）。
- `scoring.dart`：`recencyScore`、`decayStrength`（下限 0.15）、`reinforce`、`hybridScore`（0.5/0.2/0.2/0.1）、`cosine`、`quantizeVector`（int8）、`cosineInt8`；`test/scoring_test.dart` 11 例覆盖边界。
- `store.dart`：事实 CRUD、`mergeFacts`（相似合并 + 重要度加权淘汰，取代 24 条 FIFO）、`addEpisode`、`recentDigest`、`search`（FTS LIKE 候选 + int8 余弦 + 混合打分）、`_migrateLegacy`（把 `feiyu.memory.v1` / `feiyu.archive.v1` 导进来，旧 key 留作备份）。
- `main.dart`：删掉旧 `Memory` 类，`_store` 常驻，`_factsPrompt` / `_digest` 注入 system prompt，设置页记忆列表改为查库（可增删改，不再有 24 条上限）。
- web 资源：`web/sqlite3.wasm`（0.67MB，来自 drift 的 extension 目录）、`web/drift_worker.js`（`dart compile js` 编译 `web/drift_worker.dart`，1.2MB）。

下一步 P1：Episode 抽取（每 N 轮）、日结、分层块 day/week/month。

## 12. P1–P5 进度

| 期 | 内容 | 状态 |
| --- | --- | --- |
| P1 | 情景抽取、日结、周结、月结（`timeline.dart` / `digest.dart` / `curator.dart`） | 完成（v0.15.9） |
| P2 | 实体与关系（`graph.dart`，六种星、边权随重复加强、`invalidatedAt` 失效） | 完成（v0.16.0） |
| P3 | 星图页（力导向 + 社区聚类 + 时间滑杆 + 「让她讲这件」） | 完成（v0.16.0） |
| P4 | 混合检索（FTS + 向量 + 图扩展）、记忆体检（冲突/快灭的星）、旧事钩子 | 完成（v0.16.1） |
| P5 | 夜间整理（褪色/剪边/裁员）、导出与清空、敏感话题 `local_only` | 完成（v0.16.1） |

几个落地时的细节，跟原方案有出入，记在这里免得以后又绕回去：

1. **日结是「只增不改」的**：某天的日结写下去就不再重写，之后那天的情景也只能追加到更上层的周结里。理由同 billion-context——重写历史会让「同一件事被反复概述」而越来越糊。
2. **一轮最多熬 3 篇日结**（`maxDayCardsPerRun`）：首次启用时库里可能压着几十天，一口气全熬会连打几十次模型调用，既慢又费钱，所以宁可分几晚慢慢补。
3. **`local_only` 是硬隔离，不是提示词里的自觉**：`factsPrompt`、`timelinePrompt`、`curator._foldDays`、`search(includeLocalOnly:)` 四处都真的把它们过滤掉了。敏感情景不进日结，因为日结会被当成 prompt 外发；不进星图，因为星图里的 summary 会进「让她讲这件」。
4. **敏感判定是关键词表**（`digest.dart` 的 `sensitiveMarkers`），不是模型判断。宁可多标：标错只是这条不参与对话，标漏就是外发。
5. **夜间整理先褪色再结账**：`nightlySweep()` 在 `runMaintenance()` 之前跑，否则刚被裁掉的老情景就再也折不进日结了。

