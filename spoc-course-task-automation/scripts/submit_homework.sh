#!/bin/bash
# 提交 SPOC 作业/练习题答案（真实点击「提交」按钮）
# 用法: ./submit_homework.sh <itemid> <答案目录> [session_id]
# 答案目录内按 q1.txt / q2.txt / ... 命名，与题目顺序一一对应；空行分段
# —— 婉清 整理
set -u
export PATH="$HOME/.local/bin:$PATH"
export BSK_AUTO_START=0

ID="${1:?用法: submit_homework.sh <itemid> <答案目录> [session_id]}"
DIR="${2:?缺少答案目录}"
S="${3:-}"

[ -d "$DIR" ] || { echo "答案目录不存在: $DIR"; exit 1; }

if [ -z "$S" ]; then
  S=$(bsk session start --json 2>/dev/null | grep -o '"session_id": "[^"]*"' | cut -d'"' -f4)
  [ -z "$S" ] && { echo "无法创建会话"; exit 1; }
fi

echo "[hw $ID] 打开作业页"
bsk evaluate "location.href='https://study.nju.edu.cn/study/initplay/${ID}.mooc'; 'go'" --session "$S" >/dev/null 2>&1
sleep 8

# 关掉「考核说明」弹窗，否则题目区域不可见
bsk evaluate "(()=>{const b=[...document.querySelectorAll('a,button')].find(x=>/我知道了/.test(x.innerText));if(b){b.click();return 'closed'}return 'none'})()" \
  --session "$S" >/dev/null 2>&1
sleep 3

# 依次把 q1.txt,q2.txt,... 写入对应的富文本框
for f in $(ls "$DIR"/q*.txt 2>/dev/null | sort -V); do
  n=$(basename "$f" .txt | sed 's/q//')
  idx=$((n-1))
  PARAS=$(python -c "
import json
s=open(r'$f',encoding='utf-8').read()
print(json.dumps([p.strip() for p in s.split('\n') if p.strip()],ensure_ascii=False))
")
  RES=$(bsk evaluate "(()=>{const raw=$PARAS;const f=[...document.querySelectorAll('form')].find(x=>/学术诚信/.test(x.innerText));if(!f)return 'NOFORM';const eds=[...f.querySelectorAll('[contenteditable=true]')];const e=eds[$idx];if(!e)return 'NOEDITOR';e.innerHTML=raw.map(t=>'<p>'+t+'</p>').join('');e.dispatchEvent(new Event('input',{bubbles:true}));e.dispatchEvent(new Event('keyup',{bubbles:true}));return 'q${n}:'+e.innerText.length})()" \
    --session "$S" --json 2>/dev/null | grep -o '"value": "[^"]*"')
  echo "[hw $ID] $RES"
done

# 核对
CHK=$(bsk evaluate "(()=>{const f=[...document.querySelectorAll('form')].find(x=>/学术诚信/.test(x.innerText));if(!f)return 'NOFORM';return JSON.stringify([...f.querySelectorAll('[contenteditable=true]')].map(e=>e.innerText.length))})()" \
  --session "$S" --json 2>/dev/null | grep -o '"value": "[^"]*"')
echo "[hw $ID] 各题字数 -> $CHK"

# 真实点击提交按钮
REF=$(bsk snapshot --session "$S" 2>/dev/null | grep -E '"提交"' | tail -1 | grep -o '@e[0-9]*')
if [ -z "$REF" ]; then echo "[hw $ID] 未找到提交按钮"; exit 1; fi
bsk click "$REF" --session "$S" >/dev/null 2>&1
sleep 5

DONE=$(bsk evaluate "document.body.innerText.includes('您已提交作业')" --session "$S" --json 2>/dev/null | grep -o '"value": [a-z]*')
echo "[hw $ID] 提交状态 -> $DONE (true 表示成功)"
