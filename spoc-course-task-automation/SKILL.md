---
name: spoc-course-task-automation
description: Automate SPOC (study.nju.edu.cn / CNMOOC) course completion — read every PDF page-by-page to trigger the platform's reading-progress record, post discussion replies, and submit assignment/exam answers. Use this skill when the user asks to complete, finish, or unlock "学习任务点 / 完成度 / 打勾 / 已读" on a SPOC/MOOC course page, or asks to publish discussion posts or submit homework on that platform.
agent_created: true
---

# SPOC 课程任务自动化

在 `study.nju.edu.cn`（SPOC，底层为 CNMOOC）上批量完成课程任务点，使课程目录里每个条目都显示绿色对勾。

## 依赖

本技能依赖 **browser-skill**（bsk CLI + 浏览器扩展）来驱动浏览器。若 `bsk status --json` 返回的 `browsers` 为空，或提示 `bsk: command not found`，说明依赖未就绪——先按同目录下 `从零开始配置教程.txt` 完成环境配置，再继续。

## 核心原则

平台判定"完成"的唯一依据是**真实的前端交互触发的上报请求**。仅调用后端接口（如 `updateStudyByRelative`）不会写入完成状态，必须模拟真实的翻页、发帖、提交动作。

三种任务类型与对应的完成机制：

| 类型 | itemtype | 触发动作 | 完成图标 |
|------|----------|----------|----------|
| 文档 / PDF | 20 | 逐页翻到最后一页 | `icon-doc-done` |
| 讨论题 | 40 | 在帖子里发布回复 | `icon-note-done` |
| 练习 / 作业 | 60 | 提交作业表单 | `icon-edit02-done` |

未完成图标为同名 `icon-disabled` 版本（如 `icon-doc icon-disabled`）。判定完成状态时，按图标 class 里是否含 `done` 来计数。

## 前置准备

- `bsk`（browser-skill CLI）不在 PATH 中，每条命令前加 `export PATH="$HOME/.local/bin:$PATH"`。
- 守护进程需单独启动：`BSK_AUTO_START=0 bsk daemon start --foreground` 放后台跑。
- 每条浏览器命令都要带同一个 `BSK_HOME` 与 `BSK_AUTO_START=0`。
- 优先用 `bsk session start` 自带窗口 + `bsk navigate` 导航，**不要**依赖 `tab borrow`（确认弹窗常弹不出来）。
- 用户浏览器需已登录 SPOC 账号。

## 执行流程

### 第 1 步：读取课程任务清单

导航到课程目录页 `https://study.nju.edu.cn/portal/session/unitNavigation/<courseId>.mooc`，用 `bsk evaluate` 导出全部任务点：

```js
(()=>{const as=[...document.querySelectorAll('a.lecture-action')];
return JSON.stringify(as.map(a=>({id:a.getAttribute('itemid'),ty:a.getAttribute('itemtype'),
c:a.querySelector('i')?a.querySelector('i').className.trim():'none'})))})()
```

记录每个条目的 `itemid`、`itemtype`、当前图标。区分出未完成的条目。

### 第 2 步：完成文档（itemtype=20）

取文档页总页数，然后**逐页点击下一页**，让前端逐页上报。核心请求为：

```
GET /study/updateDurationDoc.mooc?itemId={id}&duration=15&pn={页码}
翻到最后一页时额外发：?over=2&itemId={id}&duration=15
```

用 `scripts/run_doc.sh <itemid>` 批处理单个文档。脚本逻辑：
1. 打开 `https://study.nju.edu.cn/study/initplay/<itemid>.mooc`
2. 读 `.flexpaper_lblTotalPages` 拿总页数
3. 循环点击 `.flexpaper_bttnPrevNext`（下一页）直到最后一页
4. 停留数秒，让末页的 `over=2` 上报完成

**要点**：翻页必须按顺序进行，跳跃到末页无效；每页之间留 0.6–0.8 秒间隔。

### 第 3 步：发布讨论（itemtype=40）

用户会要求针对每个讨论题发表**不少于指定字数**的观点。此时先阅读 PDF 原文与已有回帖了解题目背景，再撰写切题的回答（不要写通用套话，"按答对得分"的主观题会由同学互评）。

发布方式：写入 `#post_area` 富文本框，再**真实点击** `#btn_submit_post`（"发布"按钮）。

**易错点**：
- 发帖按钮是 `#btn_submit_post`，不是 `#forumSubmit`（后者属于隐藏的"发新帖"表单 `#form_plus`）。
- 直接 `.click()` 可能无效，必须让 bsk 执行真实鼠标点击（用 `bsk snapshot` 取 `"发布"` 的 `@eN` 引用后 `bsk click`）。
- 发布成功的判据：`#post_area` 内容被清空，且网络日志出现 `POST /thread/{tid}/replyThread-10.mooc`。

用 `scripts/post_reply.sh <itemid> <内容文件>` 执行；内容文件为纯文本，空行分段。

### 第 4 步：提交作业（itemtype=60）

进入作业页会先弹"考核说明"弹窗，需先点"我知道了"才看得到题目。

主观题答题框是 UMeditor 富文本，在含"学术诚信"文字的 `<form>` 内，按顺序取 `[contenteditable=true]`，第 i 个对应第 i 题。按题目顺序写入 HTML 段落（`<p>` 包裹），再真实点击 `#submit_exam` 提交。

核心请求：`POST /examSubmit/{courseId}/saveExam/...mooc`。提交成功后页面显示"您已提交作业"，且截止前可重复提交覆盖（以最后一次为准）。

用 `scripts/submit_homework.sh <itemid> <答案目录>` 执行；答案目录内按 `q1.txt`、`q2.txt`… 命名，每个文件空行分段。

### 第 5 步：验收

回到课程目录页，重新统计完成数，确认 `done == total`。截图留存证据。若仍有未完成项，检查是否被弹窗遮挡或页面未加载完。

## 环境注意

- 长页面全页截图容易超时，改用视口截图；截图前先 `scrollIntoView`。
- 每次导航后需等待 6–8 秒，页面为异步渲染。
- 富文本编辑器不接受 `.value` 赋值，只能改 `innerHTML` 并派发 `input`、`keyup` 事件。
- 完成后用 `bsk session stop <id>` 结束会话并归还标签页。

## 参考

- `references/platform-mechanics.md`：完整的接口清单、选择器表与实测数据。

---

<sub>整理：婉清</sub>
