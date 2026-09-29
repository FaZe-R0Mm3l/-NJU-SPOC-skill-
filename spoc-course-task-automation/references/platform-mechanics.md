# SPOC 平台机制参考（实测于 2026-09-29）

## 一、页面与全局标识

| 项目 | 值 / 位置 |
|------|-----------|
| 课程目录页 | `https://study.nju.edu.cn/portal/session/unitNavigation/<courseId>.mooc` |
| 资源播放页 | `https://study.nju.edu.cn/study/initplay/<itemid>.mooc` |
| 全局课程 ID | `window.courseOpenId`（如 `"12345"`，请以实际页面为准） |
| 任务点元素 | `a.lecture-action`，属性 `itemid`、`itemtype`、`title` |
| 文档单页图片 | `https://studyrsc.nju.edu.cn/view/doc.spoc?viewer=html&resid=<resid>&format=jpg&start=<n>` |

## 二、任务类型（itemtype）

| itemtype | 含义 | 完成图标 |
|----------|------|----------|
| 20 | 文档 / PDF | `icon-doc-done` |
| 40 | 讨论题 | `icon-note-done` |
| 60 | 练习 / 作业 | `icon-edit02-done` |

未完成时图标为 `icon-doc icon-disabled` / `icon-note icon-disabled` / `icon-edit02 icon-disabled`。

## 三、完成上报接口

### 文档阅读

每翻一页触发：

```
GET /study/updateDurationDoc.mooc?itemId=<id>&duration=15&pn=<页码>
```

翻到最后一页时额外触发（`over=2` 是完成标志）：

```
GET /study/updateDurationDoc.mooc?over=2&itemId=<id>&duration=15
```

另有学习时长日志：`POST /log/study.mooc?...&ii=<itemid>&it=60...&at=<秒数>`。

**关键**：直接调 `updateStudyByRelative(relativeId, itemType)`（`POST /study/update/relative.mooc`）**不会**写入完成状态，刷新后图标仍是灰色。必须靠真实翻页。

### 讨论发帖

真实点击"发布"后触发：

```
POST /thread/<threadId>/replyThread-10.mooc
POST /post-<threadId>-1.mooc
```

### 作业提交

```
POST /examSubmit/<courseId>/saveExam/<stage>/<paperId>/<examId>.mooc
```

提交后页面出现"您已提交作业。在提交截止之前，如有需要您可以更新提交作业内容！"

## 四、关键选择器

### 文档阅读器（FlexPaper 2.1.2）

| 用途 | 选择器 |
|------|--------|
| 总页数 | `.flexpaper_lblTotalPages`（文本形如 ` / 15`） |
| 当前页码输入框 | `.flexpaper_txtPageNumber` |
| 下一页按钮 | `.flexpaper_bttnPrevNext` |
| 单页容器 | `#pageContainer_<n>_reader_wrapper` |

阅读器回调（挂在 `window.__READER_EVENT_CALLBACK`）：
- `PAGECHANG_<resid>`：翻页时调用
- `FINISH_<resid>`：到达末页时调用
- `HEART_<resid>`：心跳
- `SHOTFINISH_<resid>`：截图完成

### 讨论区

| 用途 | 选择器 |
|------|--------|
| 回复富文本框 | `#post_area`（contenteditable，位于 `#form_post` 内） |
| **发布按钮** | `#btn_submit_post` |
| 隐藏的发新帖表单 | `#form_plus`（内含 `#thread_title`，按钮 `#forumSubmit`） |
| 楼中楼输入框 | `.input-area`（多个，默认不可见） |

**易错**：`#forumSubmit` 与 `#btn_submit_post` 都叫"提交/发布"，前者属于隐藏表单，点了没反应。

### 作业页

| 用途 | 选择器 |
|------|--------|
| 诚信声明表单 | 含文字"学术诚信"的 `<form>` |
| 答题框 | 该 form 内 `[contenteditable=true]`，按顺序对应第 1..N 题 |
| 隐藏 textarea | `#umeditor_textarea_editorValue`（多个，勿直接赋值） |
| **提交按钮** | `#submit_exam` |
| 考核说明弹窗 | 关闭按钮文字为"我知道了" |

## 五、富文本写入方式

UMeditor 编辑器不响应 `.value` 赋值，必须：

```js
const e = document.getElementById('post_area');           // 或 form 内第 i 个 contenteditable
e.innerHTML = ['<p>第一段</p>','<p>第二段</p>'].join('');
e.dispatchEvent(new Event('input', {bubbles:true}));
e.dispatchEvent(new Event('keyup', {bubbles:true}));
```

## 六、验收方法

回到课程目录页执行：

```js
(()=>{const as=[...document.querySelectorAll('a.lecture-action')];
const r=as.map(a=>({i:a.getAttribute('itemid'),ty:a.getAttribute('itemtype'),
c:a.querySelector('i')?a.querySelector('i').className.trim():'none'}));
return JSON.stringify({total:r.length,done:r.filter(x=>/done/.test(x.c)).length,
undone:r.filter(x=>!/done/.test(x.c))})})()
```

`done == total` 即全部完成。

## 七、实测数据（2026-09-29）

- 单门课程任务点数量视课程而定，本项目实测 26 个：19 个 PDF（itemtype=20）+ 6 个讨论题（40）+ 1 个练习题（60）。
- PDF 页数常见 6–28 页，逐页翻完单个文档约 20–60 秒。
- 讨论题需 800 字以上，由同学互评（考核占比：被批阅分数 80% + 批阅数量 15% + 批阅质量 5%）。
- 练习题 4 道主观论述题，满分 100，截止前可重复提交。

## 八、常见故障

| 现象 | 原因 | 处理 |
|------|------|------|
| 调接口后刷新仍为灰 | 后端不认直调接口 | 改用真实翻页 |
| 点"发布"无请求 | 点到了 `#forumSubmit` | 改用 `#btn_submit_post` + 真实鼠标点击 |
| 作业页看不到题目 | 被"考核说明"弹窗遮挡 | 先点"我知道了" |
| 全页截图 timeout | 长页面像素读取超时 | 改视口截图，先 `scrollIntoView` |
| `tab borrow` 失败 | 确认弹窗无法显示 | 用 `session start` + `navigate` |

---

<sub>整理：婉清</sub>
