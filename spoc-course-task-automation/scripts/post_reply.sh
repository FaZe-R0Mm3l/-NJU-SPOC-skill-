#!/bin/bash
# 在 SPOC 讨论题下发布一条回复（真实点击「发布」按钮）
# 用法: ./post_reply.sh <itemid> <内容文件> [session_id]
# 内容文件: 纯文本，空行分段
# —— 婉清 整理
set -u
export PATH="$HOME/.local/bin:$PATH"
export BSK_AUTO_START=0

ID="${1:?用法: post_reply.sh <itemid> <内容文件> [session_id]}"
FILE="${2:?缺少内容文件}"
S="${3:-}"

[ -f "$FILE" ] || { echo "内容文件不存在: $FILE"; exit 1; }

if [ -z "$S" ]; then
  S=$(bsk session start --json 2>/dev/null | grep -o '"session_id": "[^"]*"' | cut -d'"' -f4)
  [ -z "$S" ] && { echo "无法创建会话"; exit 1; }
fi

echo "[post $ID] 打开讨论页"
bsk evaluate "location.href='https://study.nju.edu.cn/study/initplay/${ID}.mooc'; 'go'" --session "$S" >/dev/null 2>&1
sleep 7

# 把文本按空行切段，转成 JS 数组字面量
PARAS=$(python -c "
import json,sys
s=open(r'$FILE',encoding='utf-8').read()
paras=[p.strip() for p in s.split('\n') if p.strip()]
print(json.dumps(paras,ensure_ascii=False))
")
if [ -z "$PARAS" ]; then echo "[post $ID] 内容为空"; exit 1; fi

RES=$(bsk evaluate "(()=>{const raw=$PARAS;const p=document.getElementById('post_area');if(!p)return 'NOBOX';p.innerHTML=raw.map(t=>'<p>'+t+'</p>').join('');p.dispatchEvent(new Event('input',{bubbles:true}));p.dispatchEvent(new Event('keyup',{bubbles:true}));return 'FILLED:'+p.innerText.length})()" \
  --session "$S" --json 2>/dev/null | grep -o '"value": "[^"]*"')
echo "[post $ID] 填入 -> $RES"

# 取「发布」按钮引用后真实点击（不要用 #forumSubmit）
REF=$(bsk snapshot --session "$S" 2>/dev/null | grep -E '"发布"' | head -1 | grep -o '@e[0-9]*')
if [ -z "$REF" ]; then echo "[post $ID] 未找到发布按钮，请用 observe 检查页面"; exit 1; fi
bsk click "$REF" --session "$S" >/dev/null 2>&1
sleep 5

LEFT=$(bsk evaluate "document.getElementById('post_area')?document.getElementById('post_area').innerText.trim().length:-1" \
  --session "$S" --json 2>/dev/null | grep -o '"value": [0-9-]*')
echo "[post $ID] 提交后残留 $LEFT（0 表示发布成功）"
