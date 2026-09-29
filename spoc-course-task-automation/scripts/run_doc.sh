#!/bin/bash
# 逐页阅读一个 SPOC 文档，触发平台的阅读进度上报
# 用法: ./run_doc.sh <itemid> [session_id]
# 依赖: bsk CLI（browser-skill），浏览器已登录 study.nju.edu.cn
# —— 婉清 整理
set -u
export PATH="$HOME/.local/bin:$PATH"
export BSK_AUTO_START=0

ID="${1:?用法: run_doc.sh <itemid> [session_id]}"
S="${2:-}"

if [ -z "$S" ]; then
  S=$(bsk session start --json 2>/dev/null | grep -o '"session_id": "[^"]*"' | cut -d'"' -f4)
  [ -z "$S" ] && { echo "无法创建会话"; exit 1; }
fi

echo "[doc $ID] 打开阅读页"
bsk evaluate "location.href='https://study.nju.edu.cn/study/initplay/${ID}.mooc'; 'go'" --session "$S" >/dev/null 2>&1
sleep 6

TOTAL=$(bsk evaluate "(()=>{const t=document.querySelector('.flexpaper_lblTotalPages');return t?t.textContent.replace(/[^0-9]/g,''):'0'})()" --session "$S" --json 2>/dev/null \
  | grep -o '"value": "[0-9]*"' | grep -o '[0-9]*')

if [ -z "$TOTAL" ] || [ "$TOTAL" = "0" ]; then
  echo "[doc $ID] 未能读取总页数，跳过"
  exit 1
fi
echo "[doc $ID] 共 $TOTAL 页，逐页翻阅"

# 逐页点击「下一页」，让前端按 pn 顺序上报
for ((p=2; p<=TOTAL; p++)); do
  bsk evaluate "(()=>{const c=document.querySelector('.flexpaper_txtPageNumber');const n=c?parseInt(c.value):1;const b=document.querySelector('.flexpaper_bttnPrevNext');if(n<${p}&&b){b.click();return n+1}return n})()" \
    --session "$S" >/dev/null 2>&1
  sleep 0.7
done

# 停留，等待末页 over=2 上报
sleep 3

CUR=$(bsk evaluate "(()=>{const c=document.querySelector('.flexpaper_txtPageNumber');return c?c.value:'?'})()" --session "$S" --json 2>/dev/null \
  | grep -o '"value": "[^"]*"')
echo "[doc $ID] 当前页 $CUR / $TOTAL —— 完成"
