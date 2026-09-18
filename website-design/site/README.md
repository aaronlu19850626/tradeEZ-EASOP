# TradeEZ 静态官网

基于现有官网文案及产品需求实现的中文响应式官网。采用 Next.js、React、TypeScript、Tailwind CSS 和 shadcn/ui，深蓝灰底色、蓝色操作与少量金色标记，使用 ../logo/avatar-navy-final.png 提供的品牌标志。

## 页面

| 路径 | 内容 |
| --- | --- |
| / | 产品分工、品牌理念、每日流程、未来方向与常见问题 |
| /ea/ | 双策略管理、下单辅助、风险限制、交易数据同步 |
| /platform/ | 账号归档、订单标签、单笔复盘、规则评价、整体分析与每日习惯 |
| /roadmap/ | AI 复盘、课程案例、历史回放、个性化学习与长期研究 |
| /help/ | EA 使用准备、首次复盘流程及 16 条 FAQ |

这是官网展示站，不包含交易执行、平台注册、登录、订阅付费、真实行情或数据同步接口。EA 面板为结构示意，平台界面明确标注设计预览；模拟数据不代表实际业绩。SaaS 首版筹备与未来功能分别标注。

## 本地运行

需要 Node.js 22.13+ 与 npm。

```sh
npm ci
npm run dev
```

开发预览：http://127.0.0.1:5173/。

## 静态构建与预览

```sh
npm run build
npm start
```

out/ 为独立静态发布目录，包含五个页面、404 页面、JS、CSS 与品牌图片。npm start 使用项目内的轻量本地服务器预览这些文件，不依赖 Next.js 服务端。可用环境变量 PORT 更改预览端口。

部署时将 **out 目录的内容** 上传至支持静态网站的托管服务根目录，保持子目录结构及 _next 资源。启用目录首页 index.html，并将错误页设为 404.html。建议通过 HTTP 访问，不要直接双击 HTML（资源使用站点根路径）。不要将所有未知路径重写到首页。

初始脚手架的 Vinext 构建在本机 Windows 环境中遗漏了四个子页面，并在退出阶段报错。现已使用已安装的 Next.js 原生静态导出，开发、构建与静态预览均不依赖 Sites 插件；旧脚手架工具及依赖保留但不参与默认运行。

## 内容维护

- components/tradeez.tsx：首页、导航、页脚、共用操作、复盘演示及 FAQ 文案。
- components/product-pages.tsx：四个详细页面、EA 管理流程、标签、规则与每日计划示意。
- app/site.css：品牌配色、排版及桌面、平板、手机适配。
- app/*/page.tsx：各页面入口与 SEO 标题、描述。
- public/brand/logo.png：当前使用的 logo；public/brand/cover.png 为已有封面备用素材。
- scripts/preview.mjs：本地静态预览服务器。

基础交互使用 shadcn/ui 的 Button、Tabs、Accordion、Sheet。导航、产品切换、FAQ 和移动菜单可操作；示意面板中的下单区域仅用于解释产品，不提供交易操作。

可以优先替换 EA 页 EAPreview 为真实、脱敏的面板截图。保留真实比例和可读性。SaaS 原型尚未实际开放时，应继续保留“首版筹备中／设计预览”标记。

## 验证

```sh
npm run lint
node node_modules/typescript/bin/tsc --noEmit
npm run build
```

页面检查尺寸为 390px、768px、1440px。发布前核对链接、手机菜单、标签页、FAQ、无横向溢出及页面状态说明。项目没有添加后台接口或数据库设计。
