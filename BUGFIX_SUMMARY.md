# Gold_SOP_EA 功能增强与BUG修复总结

**修改日期**: 2026-09-17  
**版本**: v1.03 → v1.04

---

## 一、新增功能：剥头皮"撤止盈"按钮

### 1.1 功能说明
- **位置**：剥头皮策略卡片，市价下单按钮行，"改趋势单"按钮右侧
- **触发条件**：仅在剥头皮持仓**已进入峰值追踪逻辑**时激活（浮盈≥300点）
- **功能**：清除已进入峰值追踪的剥头皮持仓的止盈，保留止损和峰值回撤逻辑
- **使用场景**：当剥头皮单已进入峰值追踪（保本+峰值回撤管理），但用户希望取消固定止盈让利润继续奔跑时使用

### 1.2 实现细节

#### 新增函数 `ClearScalpTP()`
```cpp
void ClearScalpTP()
{
    int found = 0, cleared = 0;

    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong tk = PositionGetTicket(i);
        if(tk == 0) continue;
        if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
        if(PosType() != SOP_SCALP) continue;

        // 必须已进入峰值追踪(在 g_ScalpTrackTicket 名单中)
        int idx = ScalpTrackIndex(tk);
        if(idx < 0) continue;  // 未进入峰值追踪,跳过

        found++;

        double curSL = PositionGetDouble(POSITION_SL);
        double curTP = PositionGetDouble(POSITION_TP);
        if(curTP == 0.0) continue;  // 已无止盈,跳过

        // 清除止盈,保留止损
        if(g_trade.PositionModify(tk, curSL, 0.0))
            cleared++;
    }

    if(found == 0)
        Alert(Lang("无剥头皮持仓已进入峰值追踪", "No scalp in peak trail"));
    else if(cleared > 0)
        Alert(StringFormat(Lang("已清除 %d 单止盈", "Cleared %d TP"), cleared));
}
```

#### 按钮渲染逻辑修改 `RenderStrategyCardButtons()`
- 原来：3个按钮（做空/做多/改趋势单）
- 现在：4个按钮（做空/做多/改趋势/撤止盈）
- 按钮宽度自动均分：`(CardW - LeftPad - RightPad - 3 * 4) / 4`
- 按钮间距缩小：6px → 4px，文字字号微调：8 → 7.5

```cpp
// 撤止盈按钮(仅在有剥头皮持仓进入峰值追踪时激活)
bool hasTracking = false;
for(int i = 0; i < ArraySize(g_ScalpTrackTicket); i++)
{
    if(PositionSelectByTicket(g_ScalpTrackTicket[i]))
    {
        hasTracking = true;
        break;
    }
}
color tpBg = (allowed && hasTracking) ? COLOR_BTN_SYS_BG      : COLOR_BTN_DISABLED_BG;
color tpTx = (allowed && hasTracking) ? COLOR_SIGNAL_PROFIT   : COLOR_BTN_DISABLED_TXT;
color tpBd = (allowed && hasTracking) ? COLOR_SIGNAL_PROFIT   : COLOR_BTN_DISABLED_BG;
CreateButton("Btn_Sc_ClearTP", leftX + 3*(bw+4), contentY, bw, 30, 
             Lang("撤止盈", "RM TP"), tpBg, tpBd, tpTx, 7.5, true);
```

#### 事件处理 `OnChartEvent()`
```cpp
// 剥头皮撤止盈:清除已进入峰值追踪的持仓的止盈
if(sparam == Prefix + "Btn_Sc_ClearTP") 
{ 
    ResetBtn(sparam); 
    if(IsScalpAllowed()) 
        ClearScalpTP(); 
    RenderPerfectUI(); 
    return; 
}
```

---

## 二、BUG修复：挂单价输入框不更新

### 2.1 问题描述
- **现象**：用户在"挂单价"输入框填写新价格后，点击"限价多"或"限价空"按钮，实际执行的挂单仍使用初始默认价格（Bid价），而不是用户填入的新值
- **根本原因**：`RenderPerfectUI()` 每次刷新（OnTimer每秒触发）都调用 `ObjectsDeleteAll(0, Prefix)` 删除所有对象，包括输入框，导致用户正在输入或已输入未提交的内容丢失

### 2.2 修复方案

#### 修改1：`RenderPerfectUI()` 改用 `DeleteUIKeepEdits()`
**文件位置**：Gold_SOP_EA.mq5，行 2657

**修改前**：
```cpp
ObjectsDeleteAll(0, Prefix);
```

**修改后**：
```cpp
DeleteUIKeepEdits();  // 关键修复：保留输入框，避免用户输入丢失
```

**作用**：每次渲染时不删除输入框对象，保持用户输入状态

---

#### 修改2：`RenderStrategyCardButtons()` 输入框内容优先级调整
**文件位置**：Gold_SOP_EA.mq5，行 2337-2354

**修改前**：
```cpp
string editVal = (kind == SOP_SCALP) ? g_ScPriceTxt : g_TrPriceTxt; // 填回已提交内容
if(editVal == "") 
    editVal = DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits); // 首次默认现价
CreateEdit("Edt_" + tag + "_Price", editX, contentY, editW, rowH, editVal);
```

**修改后**：
```cpp
// 关键修复：先读取输入框当前实时内容（含正在输入未提交的），优先级最高
string editName = Prefix + "Edt_" + tag + "_Price";
string liveText = "";
if(ObjectFind(0, editName) >= 0)
    liveText = ObjectGetString(0, editName, OBJPROP_TEXT);

// 决定显示内容：实时输入 > 已提交缓存 > 默认现价
string editVal = "";
if(liveText != "")
    editVal = liveText;  // 用户正在输入或已输入未提交 → 保留
else if((kind == SOP_SCALP && g_ScPriceTxt != "") || (kind == SOP_TREND && g_TrPriceTxt != ""))
    editVal = (kind == SOP_SCALP) ? g_ScPriceTxt : g_TrPriceTxt;  // 已提交缓存
else
    editVal = DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits); // 首次默认现价

CreateEdit("Edt_" + tag + "_Price", editX, contentY, editW, rowH, editVal);
```

**优先级逻辑**：
1. **最高优先级**：输入框当前实时内容（用户正在输入或已输入未失焦）
2. **次优先级**：全局缓存 `g_ScPriceTxt` / `g_TrPriceTxt`（用户已提交的内容，通过ENDEDIT事件保存）
3. **最低优先级**：默认现价（首次打开时的初始值）

**作用**：确保每次渲染时优先使用用户当前输入的内容，而不是被默认价格覆盖

---

### 2.3 修复原理

#### 问题根源分析
1. **OnTimer 每秒触发** → 调用 `RenderPerfectUI()`
2. `RenderPerfectUI()` 删除所有UI对象（含输入框）→ 重新创建
3. 重新创建时使用的默认值优先级错误：
   - 旧逻辑：只看全局缓存 `g_ScPriceTxt`（仅在ENDEDIT时更新）
   - 问题：用户正在输入但未失焦时，缓存为空，直接填默认现价
4. 用户填入新价格后点击按钮 → `ReadEditPrice()` 读到的是重建后的默认值

#### 修复后的流程
1. **OnTimer 每秒触发** → 调用 `RenderPerfectUI()`
2. `RenderPerfectUI()` **不删除输入框**，只删除其他对象
3. 渲染时检测输入框是否存在：
   - **存在** → 读取当前实时内容填回
   - **不存在**（首次或折叠后） → 按优先级填充（缓存 > 默认现价）
4. 用户填入新价格后点击按钮 → `ReadEditPrice()` 正确读到用户输入值

---

## 三、代码变更统计

### 3.1 新增代码
- **新增函数**：`ClearScalpTP()` - 31行
- **总新增**：约 50 行

### 3.2 修改代码
- **修改函数**：
  - `RenderStrategyCardButtons()` - 按钮布局逻辑（+30行修改）
  - `RenderPerfectUI()` - UI删除逻辑（1行修改）
  - `OnChartEvent()` - 事件处理（+3行）
- **总修改**：约 35 行

### 3.3 涉及文件
- `Gold_SOP_EA.mq5` - 主文件

---

## 四、测试建议

### 4.1 "撤止盈"功能测试
1. 下剥头皮市价单（止盈500点）
2. 等待浮盈达到300点（进入峰值追踪）
3. 观察"撤止盈"按钮从灰色变为绿色激活
4. 点击"撤止盈"按钮
5. 验证：持仓止盈被清除，止损保留，峰值回撤逻辑继续工作

### 4.2 挂单价输入BUG修复测试
1. 打开面板，观察"挂单价"输入框显示当前Bid价（如 2350.50）
2. 点击输入框，修改价格为 2352.00
3. **不要失焦**，直接点击"限价多"按钮
4. 验证：实际挂单价格为 2352.00（而不是旧的 2350.50）
5. 等待1秒（OnTimer触发）
6. 验证：输入框内容仍为 2352.00（不被覆盖）

### 4.3 极端场景测试
1. **快速连续修改**：修改价格 → 等0.5秒 → 再修改 → 立即点击按钮
2. **折叠展开**：输入价格 → 折叠面板 → 展开 → 验证价格保留
3. **跨策略切换**：剥头皮输入价格 → 趋势输入不同价格 → 验证各自独立

---

## 五、后续优化建议

### 5.1 功能优化
- 考虑增加"批量撤止盈"：一键清除所有已进入峰值追踪的剥头皮持仓的止盈
- 增加"撤止盈"后的视觉反馈：弹窗显示具体清除了哪些单的止盈

### 5.2 代码重构
- 将输入框状态管理独立成一个类，避免全局变量污染
- 优化按钮布局算法，支持动态增减按钮而不影响排版

---

## 六、风险提示

1. **"撤止盈"操作不可逆**：清除止盈后无法自动恢复，需手动重新设置
2. **峰值追踪仍生效**：撤止盈后，持仓仍受峰值回撤逻辑管理（回撤150点离场）
3. **输入框保留策略**：折叠面板后输入框仍保留在内存中，不占用过多资源

---

**文档生成时间**: 2026-09-17  
**修改者**: Claude Code (Opus 5)
